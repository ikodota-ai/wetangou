#!/usr/bin/env bash
# ===========================================================================
# 商品详情页数据源端到端：验证「后台改的东西顾客真能看到」
#
# 改造前会员端 pages/goods/detail 有三处硬编码，导致后台配置形同虚设：
#
#   1. 类型名写死在页面的 typeText() 映射表里（GROUPON → 「团购套餐」），
#      而运营早就在 biz_product_type 把它改成了「到店自取」。
#      商家在建品页选的是一个名字，顾客在详情页看到的是另一个名字。
#   2. 类型说明卡的标题和正文全部写死在 WXML，且只覆盖 4 种 typeCode ——
#      次卡/储值卡/周期卡/惠享卡/预售券/提货券一个 wx:if 都不命中，
#      顾客买这些类型时看不到任何解释。运营改一个字都要发版。
#   3. 「服务」那一行写的是「免预约 / 到店核销」—— 那是预约方式，不是服务设施。
#      真正的服务设施（可堂食 / 独立空间 / 免费停车）存在 biz_store.services，
#      顾客在商品页上从来看不到，而那是他判断能不能去的前提。
#
# 外加一个更严重的：subitemGroups 是响应体里 data 的**兄弟键**，
# 而 api.productDetail 走的是会做 resolve(d.data || d) 解包的 request()，
# 顶层兄弟键连同外层一起被丢掉 —— 「套餐详情」那张卡的 wx:if 永远不成立，
# 团购套餐里到底有哪些菜，顾客从来没看到过。
#
# 本脚本打真实端点断言这些字段真的下发，且商户级开关真的能关掉销量/库存。
# ===========================================================================
set -uo pipefail
BASE=${BASE:-http://localhost:8080}
MYSQL="/usr/local/mysql/bin/mysql -uroot -p133301 -N -B ry-vue --default-character-set=utf8mb4"
APPID=wx9e147c4e2151b123
PASS=0; FAIL=0

MID=991
STORE=991001
PROD=991002
COMBO_PROD=991003
STORE2=991004
MORE_A=991005
MORE_B=991006
MORE_C=991007

ok(){ PASS=$((PASS+1)); echo "  ✅ $1"; }
no(){ FAIL=$((FAIL+1)); echo "  ❌ $1"; }
chk(){ [ "$2" = "$3" ] && ok "$1 ($2)" || no "$1 期望[$3] 实际[$2]"; }
has(){ case "$2" in *"$3"*) ok "$1 (含 $3)";; *) no "$1 期望包含[$3] 实际[$2]";; esac; }
q(){ $MYSQL -e "$1" 2>/dev/null | grep -v Warning; }

cleanup(){
  echo "--- cleanup ---"
  q "delete from biz_product_subitem where group_id in (select group_id from biz_product_subitem_group where product_id=$PROD);
     delete from biz_product_ext where product_id = $COMBO_PROD;
     delete from biz_product where product_id = $COMBO_PROD;
     delete from biz_product_subitem_group where product_id = $PROD;
     delete from biz_product_ext where product_id = $PROD;
     delete from biz_product where product_id = $PROD;
     delete from biz_product where product_id in ($MORE_A,$MORE_B,$MORE_C);
     delete from biz_store where store_id in ($STORE,$STORE2);
     delete from biz_merchant where merchant_id = $MID;
     update biz_merchant set show_sales='1', show_stock='1' where merchant_id = 1;"
  redis-cli -n 0 --scan --pattern 'merchant:*' 2>/dev/null | xargs -r redis-cli -n 0 DEL >/dev/null 2>&1
  echo "PASS=$PASS FAIL=$FAIL"
  [ "$FAIL" = "0" ] || exit 1
}
trap cleanup EXIT

echo "=== A. 造数据：独立商户 + 带服务设施的门店 + 带子品组的团购 ==="
q "delete from biz_product_ext where product_id=$COMBO_PROD;
   delete from biz_product where product_id in ($PROD,$COMBO_PROD,$MORE_A,$MORE_B,$MORE_C);
   delete from biz_store where store_id in ($STORE,$STORE2);
   delete from biz_merchant where merchant_id=$MID;"
# merchant_no NOT NULL 无默认值，必填
q "insert into biz_merchant (merchant_id, merchant_no, merchant_name, appid, status, del_flag, show_sales, show_stock)
   values ($MID, 'SMK991', 'SMOKE商户991', 'wx-smoke-detail-991', '0', '0', '1', '1');"
# 服务设施故意用两个字典码 + 一个字典里没有的码（验证「翻不出来就原样显示」而不是丢掉）
q "insert into biz_store (store_id, merchant_id, store_name, services, business_hours, rating, status, del_flag)
   values ($STORE, $MID, 'SMOKE门店991', 'dine_in,private_room,not_a_real_code', '每日 10:00-21:00', 4.6, '0', '0');"
q "insert into biz_product (product_id, merchant_id, store_id, store_ids, product_name, subtitle,
     product_type, type_code, price, market_price, stock, sales, validity_days, refund_policy, status, del_flag)
   values ($PROD, $MID, $STORE, '$STORE', 'SMOKE团购991', '含 2 人份锅底',
     '0', 'GROUPON', 99, 199, 50, 0, 30, 'ANYTIME', '0', '0');"
GID=$(q "insert into biz_product_subitem_group (product_id, group_name, pick_rule, sort) values ($PROD,'主菜','ALL',0); select last_insert_id();")
q "insert into biz_product_subitem (group_id, product_id, subitem_name, quantity, price)
   values ($GID, $PROD, '毛胚', 1, 38), ($GID, $PROD, '鸭血', 1, 18);"
ok "测试数据就绪 (groupId=$GID)"

D=$(curl -s "$BASE/api/product/$PROD" -H "X-App-Id: wx-smoke-detail-991")

echo "=== B. 类型名与类型说明来自 biz_product_type（不是页面硬编码） ==="
TN=$(echo "$D" | python3 -c "import sys,json;print(json.load(sys.stdin).get('typeName') or '')")
TT=$(echo "$D" | python3 -c "import sys,json;print(json.load(sys.stdin).get('typeTips') or '')")
# 库里 GROUPON 的 type_name 已被运营改成「到店自取」；若下发的是「团购套餐」说明又走回硬编码了
DBTN=$(q "select type_name from biz_product_type where type_code='GROUPON';")
chk "typeName 与字典一致" "$TN" "$DBTN"
[ -n "$TT" ] && ok "typeTips 有下发 ($TT)" || no "typeTips 为空 —— 详情页说明卡不会显示"

echo "=== C. 门店服务设施：按字典翻成中文，翻不出的码原样保留 ==="
SVC=$(echo "$D" | python3 -c "import sys,json;print(','.join(json.load(sys.stdin).get('storeServices') or []))")
has "服务设施翻译 dine_in" "$SVC" "可堂食"
has "服务设施翻译 private_room" "$SVC" "提供独立空间"
# 字典里没有的码不能被静默丢掉，否则后台加了新码值前端就静默少一个标签
has "未知码原样保留" "$SVC" "not_a_real_code"

echo "=== D. 门店营业时间/评分/店名下发（原先营业时间硬编码兜底成 09:00-22:30） ==="
chk "storeHours" "$(echo "$D" | python3 -c "import sys,json;print(json.load(sys.stdin).get('storeHours') or '')")" "每日 10:00-21:00"
chk "storeRating" "$(echo "$D" | python3 -c "import sys,json;print(json.load(sys.stdin).get('storeRating') or '')")" "4.6"
chk "storeNameMain" "$(echo "$D" | python3 -c "import sys,json;print(json.load(sys.stdin).get('storeNameMain') or '')")" "SMOKE门店991"

echo "=== E. subitemGroups 顶层兄弟键（团购套餐里有哪些菜） ==="
NG=$(echo "$D" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('subitemGroups') or []))")
chk "分组数" "$NG" "1"
NS=$(echo "$D" | python3 -c "
import sys,json
g=(json.load(sys.stdin).get('subitemGroups') or [])
print(len(g[0].get('subitems') or []) if g else 0)")
chk "子品数" "$NS" "2"

echo "=== F. 副标题下发（原先整个详情页都没渲染它） ==="
chk "subtitle" "$(echo "$D" | python3 -c "import sys,json;print((json.load(sys.stdin).get('data') or {}).get('subtitle') or '')")" "含 2 人份锅底"

echo "=== G. 商户级销量/库存开关 ==="
chk "默认 showSales" "$(echo "$D" | python3 -c "import sys,json;print(json.load(sys.stdin).get('showSales'))")" "1"
chk "默认 showStock" "$(echo "$D" | python3 -c "import sys,json;print(json.load(sys.stdin).get('showStock'))")" "1"
q "update biz_merchant set show_sales='0', show_stock='0' where merchant_id=$MID;"
redis-cli -n 0 --scan --pattern 'merchant:*' 2>/dev/null | xargs -r redis-cli -n 0 DEL >/dev/null 2>&1
D2=$(curl -s "$BASE/api/product/$PROD" -H "X-App-Id: wx-smoke-detail-991")
chk "关闭后 showSales" "$(echo "$D2" | python3 -c "import sys,json;print(json.load(sys.stdin).get('showSales'))")" "0"
chk "关闭后 showStock" "$(echo "$D2" | python3 -c "import sys,json;print(json.load(sys.stdin).get('showStock'))")" "0"
# 商户表这两列为 NULL 时必须兜底成 '1'：商户缓存没 TTL，加列之前写进去的快照里
# 根本没这两个 key，反序列化回来是 null，不兜底就把所有老商户的销量库存整体隐掉
q "update biz_merchant set show_sales=null, show_stock=null where merchant_id=$MID;"
redis-cli -n 0 --scan --pattern 'merchant:*' 2>/dev/null | xargs -r redis-cli -n 0 DEL >/dev/null 2>&1
D3=$(curl -s "$BASE/api/product/$PROD" -H "X-App-Id: wx-smoke-detail-991")
chk "NULL 兜底 showSales" "$(echo "$D3" | python3 -c "import sys,json;print(json.load(sys.stdin).get('showSales'))")" "1"
chk "NULL 兜底 showStock" "$(echo "$D3" | python3 -c "import sys,json;print(json.load(sys.stdin).get('showStock'))")" "1"

echo "=== H. 类型字典端点（建品页与详情页共用同一个源，名字不会再各说各话） ==="
TL=$(curl -s "$BASE/api/product/type/list" -H "X-App-Id: $APPID")
chk "字典条数" "$(echo "$TL" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('data') or []))")" "$(q "select count(*) from biz_product_type;")"
# 11 种类型每一种都要有顾客端说明，否则改成读库之后这些类型的说明卡就是空白
EMPTY=$(echo "$TL" | python3 -c "
import sys,json
rows=json.load(sys.stdin).get('data') or []
print(','.join(r['typeCode'] for r in rows if not (r.get('typeTips') or '').strip()))")
[ -z "$EMPTY" ] && ok "全部类型都有顾客端说明" || no "这些类型缺 typeTips: $EMPTY"
chk "appCanCreate 过滤生效" \
  "$(curl -s "$BASE/api/product/type/list?appCanCreate=1" -H "X-App-Id: $APPID" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('data') or []))")" \
  "$(q "select count(*) from biz_product_type where app_can_create=1;")"

echo "=== I. merchant/info 也返开关（商家端预览要拿它造同构数据） ==="
MI=$(curl -s "$BASE/api/merchant/info" -H "X-App-Id: $APPID")
chk "merchant/info showSales" "$(echo "$MI" | python3 -c "import sys,json;print((json.load(sys.stdin).get('data') or {}).get('showSales'))")" "1"
chk "merchant/info showStock" "$(echo "$MI" | python3 -c "import sys,json;print((json.load(sys.stdin).get('data') or {}).get('showStock'))")" "1"

echo "=== J. 跨租户：别家 appid 拿不到这个商品（新增字段不能成为泄漏口） ==="
chk "别家 appid 访问" \
  "$(curl -s "$BASE/api/product/$PROD" -H "X-App-Id: $APPID" | python3 -c "import sys,json;print(json.load(sys.stdin).get('code'))")" \
  "500"

echo "=== K. 套餐「几选几」与组合券包明细（这张卡之前从未真正显示过，所以它自身的 bug 一直无人发现） ==="
# K1 pickRule 必须原值下发。前端靠它 + 子品数算出「3选2」这种中文；
# 原先 WXML 直接 {{g.pickRule}}，顾客看到的是大写的 PICK_2。
G2=$(q "insert into biz_product_subitem_group (product_id, group_name, pick_rule, sort) values ($PROD,'任选菜','PICK_2',1); select last_insert_id();")
q "insert into biz_product_subitem (group_id, product_id, subitem_name, quantity, price)
   values ($G2, $PROD, '土豆', 1, 8), ($G2, $PROD, '宽粉', 1, 10), ($G2, $PROD, '海带', 2, 6);"
DK=$(curl -s "$BASE/api/product/$PROD" -H "X-App-Id: wx-smoke-detail-991")
chk "PICK_2 组的 pickRule 原值下发" \
  "$(echo "$DK" | python3 -c "
import sys,json
g=[x for x in (json.load(sys.stdin).get('subitemGroups') or []) if x.get('groupName')=='任选菜']
print(g[0].get('pickRule') if g else '')")" "PICK_2"
# 子品数按品种算（3 行）而不是按 quantity 总和（4）——
# 否则前端会算出「4选2」，而顾客只看得到 3 行菜名。
chk "PICK_2 组子品行数" \
  "$(echo "$DK" | python3 -c "
import sys,json
g=[x for x in (json.load(sys.stdin).get('subitemGroups') or []) if x.get('groupName')=='任选菜']
print(len(g[0].get('subitems') or []) if g else 0)")" "3"

# K2 组合券包（COMBO）的明细存 biz_product_ext.combo_items_json，不走子品表。
# 会员端原先读的是 product.packages —— 全库只有 utils/mock.js 造过这个字段，
# 后端零命中，所以真机上 COMBO 的套餐详情永远是空的。
q "insert into biz_product (product_id, merchant_id, store_id, store_ids, product_name,
     product_type, type_code, price, market_price, stock, sales, total_value, status, del_flag)
   values ($COMBO_PROD, $MID, $STORE, '$STORE', 'SMOKE券包991',
     '0', 'COMBO', 188, 300, 20, 0, 300, '0', '0');"
q "insert into biz_product_ext (product_id, combo_items_json)
   values ($COMBO_PROD, '[{\"name\":\"火锅双人餐\",\"subitemType\":\"GROUPON\",\"pickQuantity\":1,\"price\":99},{\"name\":\"50元代金券\",\"subitemType\":\"VOUCHER\",\"pickQuantity\":2,\"price\":50}]');"
DC=$(curl -s "$BASE/api/product/$COMBO_PROD" -H "X-App-Id: wx-smoke-detail-991")
CJ=$(echo "$DC" | python3 -c "
import sys,json
d=json.load(sys.stdin).get('data') or {}
print(((d.get('ext') or {}).get('comboItemsJson') or ''))")
has "COMBO 明细随详情下发" "$CJ" "火锅双人餐"
has "COMBO 明细包含代金券行" "$CJ" "50元代金券"
# 前端 parseComboItems 要拿 pickQuantity 算小计（与商家端 sumCombo 同口径）
chk "COMBO 明细条数" \
  "$(python3 -c "
import json,sys
print(len(json.loads(sys.argv[1])))" "$CJ")" "2"
chk "COMBO 类型码原值下发（翻译在前端）" \
  "$(python3 -c "
import json,sys
print(json.loads(sys.argv[1])[1]['subitemType'])" "$CJ")" "VOUCHER"

echo "=== L. 图文详情 / 商家补充说明（后台富文本编辑器填的两整块，详情页原先零渲染）==="
# 改造前：detail 从没进过 WXML（只在分享面板用过），notice 则在“结构化购买须知”改造时被甲掉。
# 商家把图文详情当商品卖点主阵地（抖音来客那边它独占 5 屏），零渲染 = 白填。
q "update biz_product set detail='<p>图文详情正文</p><table><tr><td>规格</td></tr></table>',
   notice='<p><strong>使用规则</strong></p><ol><li>到店出示券码</li></ol>' where product_id=$PROD;"
DL=$(curl -s "$BASE/api/product/$PROD" -H "X-App-Id: wx-smoke-detail-991")
DTL=$(echo "$DL" | python3 -c "import sys,json;print(((json.load(sys.stdin).get('data') or {}).get('detail') or ''))")
NTC=$(echo "$DL" | python3 -c "import sys,json;print(((json.load(sys.stdin).get('data') or {}).get('notice') or ''))")
has "detail 随详情下发" "$DTL" "图文详情正文"
has "detail 保留 table（.rich-detail 必须防横向撑破）" "$DTL" "<table"
has "notice 随详情下发" "$NTC" "到店出示券码"
q "update biz_product set detail=null, notice=null where product_id=$PROD;"

echo "=== M. 交易规则 6 字段（后台能填、后端一直在下发、详情页从未读过）==="
# 尤其 mutex_with_store_promotion：顾客以为能叠店内优惠、收银台说不行，而商家其实已经勾选过了。
# exclude_dates 故意存两段：PC 表单只用第一段，但详情页必须把全部段列出来。
q "update biz_product set collect_method='STORE', mutex_with_store_promotion=0 where product_id=$PROD;"
q "delete from biz_product_ext where product_id=$PROD;"
q "insert into biz_product_ext (product_id, daily_time_start, daily_time_end, exclude_dates, voucher_rules, code_type)
   values ($PROD, '09:00:00', '22:30:00', '[[\"2026-01-01\",\"2026-01-03\"],[\"2026-02-14\",\"2026-02-14\"]]', 'ALL_CATEGORY,ALL_BRAND', 'MERCHANT');"
DM=$(curl -s "$BASE/api/product/$PROD" -H "X-App-Id: wx-smoke-detail-991")
gm(){ echo "$DM" | python3 -c "import sys,json;print((json.load(sys.stdin).get('data') or {}).get('$1'))"; }
ge(){ echo "$DM" | python3 -c "import sys,json;print(((json.load(sys.stdin).get('data') or {}).get('ext') or {}).get('$1'))"; }
chk "collectMethod 下发" "$(gm collectMethod)" "STORE"
chk "mutexWithStorePromotion 下发" "$(gm mutexWithStorePromotion)" "0"
chk "ext.codeType 下发" "$(ge codeType)" "MERCHANT"
chk "ext.dailyTimeStart 下发" "$(ge dailyTimeStart)" "09:00:00"
chk "ext.dailyTimeEnd 下发" "$(ge dailyTimeEnd)" "22:30:00"
chk "ext.voucherRules 下发" "$(ge voucherRules)" "ALL_CATEGORY,ALL_BRAND"
has "ext.excludeDates 保留第二段" "$(ge excludeDates)" "2026-02-14"
# ext.voucher_scope_type 同一列双语义：代金券=适用范围（ALL/CATEGORY/STORE）、
# 组合券包=券类型（GENERAL/CATEGORY）。后端必须原值下发，分流翻译在前端做；
# 不分流会把 CATEGORY 这个两边都有的值误写成另一边的文案。
q "update biz_product_ext set voucher_scope_type='STORE' where product_id=$PROD;"
chk "ext.voucherScopeType 下发" \
  "$(curl -s "$BASE/api/product/$PROD" -H "X-App-Id: wx-smoke-detail-991" | python3 -c "import sys,json;print(((json.load(sys.stdin).get('data') or {}).get('ext') or {}).get('voucherScopeType'))")" "STORE"

# refund_policy 必须把 PC 下拉那三个值都原值下发。
# 为什么单独验：会员端原先自己存了一张 ANYTIME/EXPIRED/NEVER 的翻译表，
# 而 PC 真正落库的是 ANYTIME/BEFORE_EXPIRE/NONE —— 后两个键全库没人写入，
# 被 || v 兜底成原值，顾客在「退改政策」一行看到的是大写的 BEFORE_EXPIRE。
# 生产库当下就有 2 条商品是 BEFORE_EXPIRE。翻译口径由 vitest 锁（tradeRules.test.js），
# 这里只保证后端不会把它吞掉或改写成另一个值。
for RP in ANYTIME BEFORE_EXPIRE NONE; do
  q "update biz_product set refund_policy='$RP' where product_id=$PROD;"
  chk "refundPolicy 原值下发 $RP" \
    "$(curl -s "$BASE/api/product/$PROD" -H "X-App-Id: wx-smoke-detail-991" | python3 -c "import sys,json;print((json.load(sys.stdin).get('data') or {}).get('refundPolicy'))")" "$RP"
done
q "update biz_product set refund_policy='ANYTIME' where product_id=$PROD;"

echo "=== N. 适用门店完整列表（多店商品原先只画主门店一家）==="
# 原先旁边只有一行不可点的「N店通用 >」：顾客看到“3 店”却不知道到底是哪 3 家，
# 也就无法判断离自己最近那家能不能用。地址/电话是选店的第一依据。
q "insert into biz_store (store_id, merchant_id, store_name, address, phone, services, business_hours, rating, status, del_flag)
   values ($STORE2, $MID, 'SMOKE二店991', '福田区中心四路 1 号', '0755-12345678', 'free_parking', '11:00-23:00', 4.2, '0', '0');"
q "update biz_product set store_ids='$STORE,$STORE2' where product_id=$PROD;"
DN=$(curl -s "$BASE/api/product/$PROD" -H "X-App-Id: wx-smoke-detail-991")
chk "applicableStores 两家全出"   "$(echo "$DN" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('applicableStores') or []))")" "2"
has "第二家店名" "$(echo "$DN" | python3 -c "import sys,json;print(json.dumps(json.load(sys.stdin).get('applicableStores'),ensure_ascii=False))")" "SMOKE二店991"
has "门店地址下发（详情页原先一个字都没有）"   "$(echo "$DN" | python3 -c "import sys,json;print(json.dumps(json.load(sys.stdin).get('applicableStores'),ensure_ascii=False))")" "中心四路"
has "门店电话下发（逐家拨号靠它）"   "$(echo "$DN" | python3 -c "import sys,json;print(json.dumps(json.load(sys.stdin).get('applicableStores'),ensure_ascii=False))")" "0755-12345678"
has "逐家服务设施已翻译"   "$(echo "$DN" | python3 -c "import sys,json;print(json.dumps(json.load(sys.stdin).get('applicableStores'),ensure_ascii=False))")" "免费停车"
# store_ids 里掘一个已删 / 不存在的门店 id：后端会跳过它，
# 于是「id 个数」和「真能列出的行数」会不一致。表头那个 N 必须数后者：
# 写着「3家」却只列 2 行，顾客会以为页面没加载完、还有一家没显出来而一直等。
q "update biz_product set store_ids='$STORE,$STORE2,99999999' where product_id=$PROD;"
chk "幽灵门店 id 不计入列表" \
  "$(curl -s "$BASE/api/product/$PROD" -H "X-App-Id: wx-smoke-detail-991" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('applicableStores') or []))")" "2"
# 单店商品（store_ids 空）也得进这个列表，否则前端要维护两套渲染分支
q "update biz_product set store_ids=null where product_id=$PROD;"
chk "单店回落到 store_id"   "$(curl -s "$BASE/api/product/$PROD" -H "X-App-Id: wx-smoke-detail-991" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('applicableStores') or []))")" "1"

echo "=== O. 本店更多商品（那张卡的 WXML 分支一直在，但后端从未下发过这个字段）==="
# 原先读 product.moreGoods，全库无人下发 → 真机上永远不可能出现；
# 连标题里的「（3）」都是写死的，就算真有 6 个也写着 3。
q "insert into biz_product (product_id, merchant_id, store_id, store_ids, product_name,
     product_type, type_code, price, market_price, stock, sales, status, del_flag)
   values ($MORE_A, $MID, $STORE, '$STORE', 'SMOKE推荐A', '0', 'GROUPON', 66, 128, 10, 0, '0', '0'),
          ($MORE_B, $MID, $STORE2, '$STORE2', 'SMOKE推荐B', '0', 'GROUPON', 88, 158, 10, 0, '0', '0'),
          ($MORE_C, $MID, $STORE, '$STORE', 'SMOKE下架C', '0', 'GROUPON', 77, 148, 10, 0, '1', '0');"
MR=$(curl -s "$BASE/api/product/$PROD/more" -H "X-App-Id: wx-smoke-detail-991")
ids(){ echo "$MR" | python3 -c "import sys,json;print(','.join(str(x.get('productId')) for x in (json.load(sys.stdin).get('data') or [])))"; }
has "同门店商品进推荐位" "$(ids)" "$MORE_A"
# 推荐位里摆一张跟当前页一模一样的卡，点进去还是自己，看着就像坏了
case "$(ids)" in *"$PROD"*) no "推荐位排除自身 —— 竟然包含自己";; *) ok "推荐位排除自身";; esac
# 下架品不能进：点进去 detail 会直接报“商品不存在或已下架”
case "$(ids)" in *"$MORE_C"*) no "下架商品不得进推荐位 —— 竟然包含";; *) ok "下架商品已排除";; esac
has "同商户其他门店补齐" "$(ids)" "$MORE_B"
chk "limit 生效"   "$(curl -s "$BASE/api/product/$PROD/more?limit=1" -H "X-App-Id: wx-smoke-detail-991" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('data') or []))")" "1"
chk "limit 超上限封顶 20"   "$(curl -s "$BASE/api/product/$PROD/more?limit=999" -H "X-App-Id: wx-smoke-detail-991" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('data') or []) <= 20)")" "True"
# 跟详情同一套租户边界：推荐位的点击会 redirectTo 到对方详情页，
# 把别家商户的货推到本商户小程序里就是数据泄露。
chk "别家 appid 拿不到 more"   "$(curl -s "$BASE/api/product/$PROD/more" -H "X-App-Id: $APPID" | python3 -c "import sys,json;print(json.load(sys.stdin).get('code'))")" "500"
chk "不存在的商品 more"   "$(curl -s "$BASE/api/product/99999999/more" -H "X-App-Id: wx-smoke-detail-991" | python3 -c "import sys,json;print(json.load(sys.stdin).get('code'))")" "500"

echo "=== P. 详情页顶部「门店」行的数据源（店名 + 距离 + 星级）==="
# 这一行读的不是商品接口，而是首页存到 globalData.store 的那家店（最近门店）。
# 三条拿店的链路都得能支持距离+星级，否则详情页那行会时有时无：
#   storeNearest  → 直接给 distance（单位米）
#   storeList / storeDetail → 不给 distance，前端靠 latitude/longitude 自己 haversine
# 距离文本的换算口径由 vitest 锁（tests/storeView.test.js），
# 这里只保证后端真的把这几个字段下发了 —— 少任何一个，
# 那一行就只剩店名，永久显「查看距离」或不出星星。
q "update biz_store set rating=4.6, longitude=114.05, latitude=22.50 where store_id=$STORE;"
SL=$(curl -s "$BASE/api/store/list?page=1&pageSize=20" -H "X-App-Id: wx-smoke-detail-991")
pick(){ echo "$SL" | python3 -c "
import sys,json
d=json.load(sys.stdin)
rows=d.get('rows') or d.get('data') or []
t=[r for r in rows if str(r.get('storeId'))=='$STORE']
print('' if not t else (t[0].get('$1') if t[0].get('$1') is not None else ''))
"; }
chk "storeList 下发 rating（星级靠它）"      "$(pick rating)"    "4.6"
chk "storeList 下发 latitude（无 distance 时靠它算）" "$(pick latitude)"  "22.5"
chk "storeList 下发 longitude"                    "$(pick longitude)" "114.05"
SD=$(curl -s "$BASE/api/store/$STORE" -H "X-App-Id: wx-smoke-detail-991")
sd(){ echo "$SD" | python3 -c "import sys,json;d=json.load(sys.stdin);r=d.get('data') or d;v=r.get('$1');print('' if v is None else v)"; }
chk "storeDetail 下发 rating"    "$(sd rating)"    "4.6"
chk "storeDetail 下发 latitude"  "$(sd latitude)"  "22.5"
chk "storeDetail 下发 storeName" "$(sd storeName)" "SMOKE门店991"
# nearest 的 distance 单位必须是米：前端 toStoreView 会 /1000。
# 假如后端哪天改成返公里，详情页会把 8.8km 显成 9m（看上去“就在隔壁”）。
# 已知店坐标 (22.50,114.05)，从 (22.60,114.05) 查 → 约 11.1km = 11100 米量级。
NR=$(curl -s "$BASE/api/store/nearest?latitude=22.60&longitude=114.05&limit=20" -H "X-App-Id: wx-smoke-detail-991")
chk "nearest 的 distance 单位是米（万米量级而非个位公里）" "$(echo "$NR" | python3 -c "
import sys,json
d=json.load(sys.stdin)
rows=d.get('rows') or d.get('data') or []
t=[r for r in rows if str(r.get('storeId'))=='$STORE']
if not t: print('NO_ROW')
else:
    v=t[0].get('distance')
    print('NULL' if v is None else ('METER' if 9000 < float(v) < 14000 else 'BAD:'+str(v)))
")" "METER"
chk "nearest 同时带 rating（否则升级成最近店后星星会消失）" "$(echo "$NR" | python3 -c "
import sys,json
d=json.load(sys.stdin)
rows=d.get('rows') or d.get('data') or []
t=[r for r in rows if str(r.get('storeId'))=='$STORE']
print('' if not t else str(t[0].get('rating')))
")" "4.6"
