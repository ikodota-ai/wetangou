#!/usr/bin/env bash
# 后台「商品查看态」只读详情页 smoke
#
# 背景：商品列表原先只有「编辑」一个入口 —— 想核对某商品的完整配置
#      （投放渠道 / 消费规则 / 商品搭配这些列表没有的字段）就必须打开编辑表单，
#      误改再保存就是脏数据。本轮补了 views/biz/product/detail.vue 只读页。
#
# 断言分两类：
#   A) 后端：详情页依赖的 5 个接口真能返出页面要展示的字段
#   B) 前端：路由静态注册、列表入口、以及 detail.vue 里几个容易写错的地方
#      （storeNames 分隔符、pickRule 解析、滚动容器探测）
#
# 之所以要断言前端源码：detail 页 100% 是前端渲染，后端接口全 200 也可能
# 因为分隔符/字段名写错而整页显示不出内容 —— 这类 bug 后端 smoke 抓不到。

set -e
H=http://127.0.0.1:8080
DB="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"
UI=ruoyi-ui/src
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:250})"; FAIL=$((FAIL+1)); fi
}
chkf() { local n="$1" f="$2" pat="$3"
  if grep -q -- "$pat" "$f" 2>/dev/null; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (未在 $f 找到: $pat)"; FAIL=$((FAIL+1)); fi
}
# 反向断言：某个模式「不该」出现在文件里（用于确认已被删除的错误实现没被改回来）
chkfn() { local n="$1" f="$2" pat="$3"
  if grep -q -- "$pat" "$f" 2>/dev/null; then echo "  ❌ $n (仍在 $f 命中: $pat)"; FAIL=$((FAIL+1));
  else echo "  ✅ $n"; PASS=$((PASS+1)); fi
}

echo "商品查看态（只读详情页） smoke:"

TOK=$(curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}' $H/login \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token",""))')
[ -n "$TOK" ] && echo "  ✅ 0) admin 登录" && PASS=$((PASS+1)) || { echo "  ❌ 0) 登录失败"; exit 1; }
AUTH="Authorization: Bearer $TOK"

# 找一个有多门店 + 有子品分组的团购商品来测（详情页最复杂的分支）
PID=$($DB -N -e "SELECT p.product_id FROM biz_product p
  JOIN biz_product_subitem_group g ON g.product_id = p.product_id
 WHERE p.type_code='GROUPON' AND p.del_flag='0'
 GROUP BY p.product_id ORDER BY p.product_id DESC LIMIT 1;" 2>/dev/null | head -1)
[ -n "$PID" ] && echo "  ✅ 1) 取到带搭配的团购商品 id=$PID" && PASS=$((PASS+1)) \
  || { echo "  ❌ 1) 库里没有带子品分组的团购商品"; exit 1; }

# ---------- A) 后端：详情页依赖的接口 ----------
DET=$(curl -s -H "$AUTH" "$H/biz/product/$PID")
chk "A1) 详情接口 200" '"code":200' "$DET"
chk "A2) 返 typeCode（页面按它决定显示哪些区块）" '"typeCode"' "$DET"
chk "A3) 返 categoryName（品类名，页面不再显示裸 id）" '"categoryName"' "$DET"
chk "A4) 返 storeNames（适用门店聚合名）" '"storeNames"' "$DET"
chk "A5) 返 ext 子对象（12 个字段大半落在 ext）" '"ext"' "$DET"

# ext 里详情页要展示的 6 个字段必须都在（少一个页面就是空白）
for k in saleChannels staffPromote codeType excludeDates dailyTimeStart voucherScopeType; do
  chk "A6) ext.$k 存在" "\"$k\"" "$DET"
done

# 主表侧的 3 个字段（不在 ext）
chk "A7) 主表 mutexWithStorePromotion（店内优惠，语义反转要展示对）" '"mutexWithStorePromotion"' "$DET"
chk "A8) 主表 extraFeeDesc（额外费用）" '"extraFeeDesc"' "$DET"

# storeNames 的分隔符必须是「、」—— ProductMapper 用的就是它。
# 前端若按逗号切，整串门店名会塞进一个 tag 里。
SEP=$(echo "$DET" | python3 -c "
import sys,json
d=(json.load(sys.stdin).get('data') or {})
s=d.get('storeNames') or ''
print('IDEOGRAPHIC' if '\u3001' in s else ('COMMA' if ',' in s else 'SINGLE'))")
chk "A9) storeNames 分隔符是「、」而非逗号" "IDEOGRAPHIC" "$SEP"

GRP=$(curl -s -H "$AUTH" "$H/biz/productSubitem/groups?productId=$PID")
chk "A10) 子品分组接口 200" '"code":200' "$GRP"
chk "A11) 分组带 subitems 数组（详情页表格数据源）" '"subitems"' "$GRP"
# pickRule 是 'ALL' / 'PICK_N' 字符串，不是数字字段 —— 详情页要解析它算「几选几」
chk "A12) 分组返 pickRule" '"pickRule"' "$GRP"

CH=$(curl -s -H "$AUTH" "$H/biz/saleChannel/enabled")
chk "A13) 渠道字典接口 200（详情页把 code 翻成中文名靠它）" '"channelCode"' "$CH"

TY=$(curl -s -H "$AUTH" "$H/biz/productType/list?pageNum=1&pageSize=100&status=0")
chk "A14) 类型字典走 rows 而非 data" '"rows"' "$TY"

MER=$(curl -s -H "$AUTH" "$H/biz/merchant/list?pageNum=1&pageSize=200")
chk "A15) 商户列表接口（详情接口不返 merchantName，靠它兜底）" '"merchantName"' "$MER"

# 不存在的商品不能 500（详情页会被人手改 URL）
BAD=$(curl -s -H "$AUTH" "$H/biz/product/99999999")
chk "A16) 不存在的商品 id 不 500" '"code":200' "$BAD"

# 无 token 必须 401
NOAUTH=$(curl -s "$H/biz/product/$PID")
chk "A17) 无 token 返 401" '401' "$NOAUTH"

# ---------- B) 前端：路由 + 入口 + 易错点 ----------
R=$UI/router/index.js
chkf "B1) 静态注册 /product/detail/:productId" "$R" "path: '/product/detail/:productId'"
chkf "B2) 指向 biz/product/detail 组件" "$R" "views/biz/product/detail"
# activeMenu 必须是真实列表路由 /goods/product（商品管理挂在「门店商品」目录下）
chkf "B3) detail 的 activeMenu 指向 /goods/product" "$R" "activeMenu: '/goods/product'"

D=$UI/views/biz/product/detail.vue
chkf "B4) storeNames 按「、」切分" "$D" "split(/\[、,，\]/)"
chkf "B5) pickRule 解析 PICK_N" "$D" "PICK_(\\\\d+)"
chkf "B6) 兼容存量中文 pickRule 'N选M'" "$D" "选\\\\s\*(\\\\d+)"
# RuoYi 布局里滚动发生在 .app-main 内部，监听 window 吸顶高亮完全不工作
chkf "B7) 探测真实滚动容器而非直接用 window" "$D" "scrollParent()"
chkf "B8) el-card 开 overflow: visible（否则 sticky 失效）" "$D" "overflow: visible"
chkf "B9) listGroups 传位置参数而非查询对象" "$D" "listGroups(pid)"
chkf "B10) 编辑跳 /product/create（不带 /biz 前缀）" "$D" "path: '/product/create'"
chkf "B11) 返回回列表而非 history.back" "$D" "path: '/goods/product'"
chkf "B12) 收单方式用 HEAD/STORE 而非 MERCHANT/PLATFORM" "$D" "HEAD: '总部统一收款'"

# collect_method 语义已由 sql/biz_collect_method_semantic_v6.sql 归一（实测 357 行全 HEAD），
# 原先的 PLATFORM/MERCHANT/自有 三套取值来自 comment 写错，兼容映射已删。
# 这里反过来断言：不该再出现「平台统一收款」这种把收款方式和 pay_mode 混淆的文案。
chkfn "B17) collectMethod 不再保留 PLATFORM 等错义映射" "$D" "PLATFORM: '平台统一收款'"
# 售后政策存量有直接存中文长句的，必须占整行 + 允许换行
chkf "B18) 售后政策整行展示（存量有中文长句）" "$D" "label=\"售后政策\" :span=\"2\""
# 查看态不做类型裁剪：STORED_CARD(13)/BOOKING(1) 也要看到门店和消费规则
chkf "B19) 商家信息区块不按类型裁剪" "$D" "class=\"dyl-sec\" :ref=\"'sec_merchant'\""
chkf "B20) 消费规则区块不按类型裁剪" "$D" "class=\"dyl-sec\" :ref=\"'sec_consume'\""

# Vue 模板作用域只有实例属性，模板里写 Number()/JSON. 会运行时报错
BADTPL=$(python3 -c "
import re,io
s=io.open('$D',encoding='utf-8').read().split('</template>')[0]
print(len(re.findall(r'[\"\'{}\s>](?:Number|parseInt|parseFloat|JSON|Math)\s*[.(]', s)))")
chk "B21) 模板里无全局函数调用（Vue 作用域限制）" "0" "$BADTPL"

I=$UI/views/biz/product/index.vue
chkf "B13) 列表操作列有查看按钮" "$I" "handleView(scope.row)"
chkf "B14) 查看按钮挂 biz:product:query 权限" "$I" "biz:product:query"
chkf "B15) 商品名可点进查看态" "$I" "el-link"
chkf "B16) handleView 跳 /product/detail/" "$I" "/product/detail/"

# ---------- C) 死菜单已清理 ----------
# 2292/2293 挂在 C 型菜单「商品管理」下，buildMenus 只对 M 递归 children，
# 这两条从来没被下发过；且 2293 的 path 正则反斜杠在 SQL 里丢了。
DEAD=$($DB -N -e "SELECT COUNT(*) FROM sys_menu WHERE menu_type='C'
  AND component IN ('biz/product/create','biz/product/detail');" 2>/dev/null | head -1)
chk "C1) sys_menu 里已无死菜单记录" "0" "$DEAD"

ROUTERS=$(curl -s -H "$AUTH" "$H/getRouters")
GOT=$(echo "$ROUTERS" | python3 -c "
import sys,json
d=json.load(sys.stdin)
hit=[]
def walk(it):
    for x in it:
        if 'product/detail' in str(x.get('component') or ''): hit.append(1)
        walk(x.get('children') or [])
walk(d.get('data') or [])
print('CLEAN' if not hit else 'STILL_THERE')")
chk "C2) /getRouters 不再下发 product/detail" "CLEAN" "$GOT"

# ---------- D) 构建产物 ----------
if [ -d ruoyi-ui/dist ]; then
  if grep -rq "product/detail" ruoyi-ui/dist/*.js ruoyi-ui/dist/static/js/*.js 2>/dev/null; then
    echo "  ✅ D1) dist 里含 detail 路由（前端已重新打包）"; PASS=$((PASS+1))
  else
    echo "  ❌ D1) dist 里找不到 detail 路由 —— 忘了 npm run build:prod"; FAIL=$((FAIL+1))
  fi
else
  echo "  ⏭  D1) 跳过（无 dist 目录）"
fi

echo ""
echo "结果: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
