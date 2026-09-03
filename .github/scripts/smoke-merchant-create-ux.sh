#!/usr/bin/env bash
# smoke-merchant-create-ux.sh
#
# 守商家端「新建商品」这条链的三件事（都是用户实测反馈出来的）：
#
# 1) 【真 bug】账号密码登录返回体里有 storeIds/stores，但 merchant/login 页
#    组装 staffUser 时**只存了单个 storeId**，没存 storeIds。
#    创建页 _initMerchantContext 读的正是 staff.storeIds，取不到就退化成
#    [storeId]。后果：① 多店老板只能勾一家门店；② storeId 若是上个账号残留
#    的旧值，提交时会带上别家商户的门店，被服务端 assertStoresBelongToMerchant
#    拦下报「门店 X 不属于该商家」——商家看着后台明明是自己的店，无从排查。
#    另外三条登录链路（会员授权识别 / identity 静默切换 / 扫码入职）一直都存了
#    storeIds，唯独账号密码这条漏了，而这恰是老板店长最常用的入口。
#
# 2) 表单由 5 个互斥 tab（wx:if activeTab===N）改成连续滚动 + 锚点联动。
#
# 3) 输入框太窄看不清文字。
set -uo pipefail
BASE="${BASE:-http://localhost:8080}"
APP="${APP:-wx9e147c4e2151b123}"
MYSQL="${MYSQL:-/usr/local/mysql/bin/mysql}"
DB="${DB:-ry-vue}"
DBUSER="${DBUSER:-root}"
DBPASS="${DBPASS:-133301}"
PASS=0; FAIL=0
ck() {
  if [ "$2" = "$3" ]; then echo "PASS | $1"; PASS=$((PASS+1));
  else echo "FAIL | $1 | got=[$2] exp=[$3]"; FAIL=$((FAIL+1)); fi
}
q() { "$MYSQL" -u"$DBUSER" -p"$DBPASS" "$DB" -N -B -e "$1" 2>/dev/null; }
CREATE_JS="miniprogram7/pages/merchant/product/create/index.js"
CREATE_WXML="miniprogram7/pages/merchant/product/create/index.wxml"
CREATE_WXSS="miniprogram7/pages/merchant/product/create/index.wxss"
LOGIN_JS="miniprogram7/pages/merchant/login/index.js"

cleanup() {
  q "delete from biz_merchant_staff where user_id=59 and store_id=101"
  q "delete from biz_product where product_name like 'SMOKE_CUX_%'"
}
trap cleanup EXIT

login() {
  curl -s -X POST "$BASE/api/merchant/staff/login" -H 'Content-Type: application/json' \
    -H "X-App-Id: $APP" -d "{\"username\":\"$1\",\"password\":\"admin123\"}"
}

# ---- 1) 登录接口必须同时返 storeIds 与 stores（含门店名）
R=$(login owner_c43)
TK=$(echo "$R" | python3 -c "import sys,json;print(json.load(sys.stdin).get('token',''))")
[ -n "$TK" ] || { echo "FAIL | owner_c43 登录失败"; exit 1; }
N=$(echo "$R" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('storeIds') or []))")
ck "登录返回 storeIds 非空" "$([ "${N:-0}" -ge 1 ] && echo yes || echo no)" "yes"
SN=$(echo "$R" | python3 -c "
import sys,json
st=json.load(sys.stdin).get('stores') or []
print('yes' if st and st[0].get('storeName') else 'no')")
ck "登录返回 stores 且带门店名（不能只给编号）" "$SN" "yes"

# ---- 2) 多店老板必须拿到全部门店（修复前只会拿到 1 家）
q "insert into biz_merchant_staff (user_id, merchant_id, store_id, role, status, create_time)
   select 59, 1, 101, 'OWNER', '0', now() from dual
   where not exists (select 1 from (select id from biz_merchant_staff where user_id=59 and store_id=101) t)"
R2=$(login owner_c43)
N2=$(echo "$R2" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('storeIds') or []))")
ck "多店老板 storeIds 返回 2 家" "$N2" "2"
NAMES=$(echo "$R2" | python3 -c "
import sys,json
st=json.load(sys.stdin).get('stores') or []
print('yes' if len(st)==2 and all(s.get('storeName') for s in st) else 'no')")
ck "多店 stores 每家都有门店名" "$NAMES" "yes"
q "delete from biz_merchant_staff where user_id=59 and store_id=101"

# ---- 3) 服务端归属校验仍然拦得住越权门店（修的是前端取值，不是放松校验）
TK=$(login owner_c43 | python3 -c "import sys,json;print(json.load(sys.stdin).get('token',''))")
add() {
  curl -s -X POST "$BASE/api/product/add" -H "Authorization: Bearer $TK" -H "X-App-Id: $APP" \
    -H 'Content-Type: application/json' \
    -d "{\"storeIds\":\"$1\",\"typeCode\":\"GROUPON\",\"productName\":\"$2\",\"price\":9.9,\"stock\":10,\"maxPerOrder\":1}"
}
OK=$(add 100 SMOKE_CUX_OK | python3 -c "import sys,json;print(json.load(sys.stdin).get('code',''))")
ck "本商家门店 100 可创建" "$OK" "200"
BAD=$(add 201 SMOKE_CUX_BAD | python3 -c "import sys,json;print(json.load(sys.stdin).get('msg',''))")
ck "别家门店 201 仍被拒" "$(echo "$BAD" | grep -q '不属于该商家' && echo yes || echo no)" "yes"

# ---- 4) 前端：登录页必须把 storeIds/stores 存进 staffUser（本轮真 bug 的守卫）
ck "登录页存 storeIds" "$(grep -q 'storeIds: d.storeIds' "$LOGIN_JS" && echo yes || echo no)" "yes"
ck "登录页存 stores" "$(grep -q 'stores: d.stores' "$LOGIN_JS" && echo yes || echo no)" "yes"
# 四条登录链路都得存，缺一条就会在那条链路上复现同样的问题
for f in miniprogram7/pages/login/login.js miniprogram7/utils/identity.js miniprogram7/pages/merchant/scan/index.js; do
  ck "$(basename $(dirname $f))/$(basename $f) 存 storeIds" \
     "$(grep -q 'storeIds:' "$f" && echo yes || echo no)" "yes"
done

# ---- 5) 前端：连续滚动 + 锚点联动（不再是 5 个互斥 tab）
# 只禁「区块级互斥」(wx:if activeTab === 0/1/2...)；tab 栏下划线的 activeTab === index 属正常保留
ck "表单不再用 activeTab 互斥渲染" \
   "$(grep -qE 'wx:if="\{\{activeTab === [0-9]' "$CREATE_WXML" && echo no || echo yes)" "yes"
ck "用 scroll-view 承载连续表单" "$(grep -q '<scroll-view' "$CREATE_WXML" && echo yes || echo no)" "yes"
ck "绑定 scroll-into-view 做锚点定位" "$(grep -q 'scroll-into-view="{{scrollIntoView}}"' "$CREATE_WXML" && echo yes || echo no)" "yes"
ck "5 个区块都有锚点 id" \
   "$(grep -c 'id="sec-' "$CREATE_WXML")" "5"
ck "滚动回调同步高亮" "$(grep -q 'bindscroll="onFormScroll"' "$CREATE_WXML" && echo yes || echo no)" "yes"
ck "js 有 onFormScroll 实现" "$(grep -q 'onFormScroll()' "$CREATE_JS" && echo yes || echo no)" "yes"
ck "点标题只做定位（设置 scrollIntoView）" "$(grep -q "scrollIntoView: 'sec-'" "$CREATE_JS" && echo yes || echo no)" "yes"
ck "滚动同步有节流（避免掉帧）" "$(grep -q '_scrollTimer' "$CREATE_JS" && echo yes || echo no)" "yes"
ck "锚点动画期间不被滚动回传打断" "$(grep -q '_anchorLock' "$CREATE_JS" && echo yes || echo no)" "yes"

# ---- 6) 前端：输入框宽度/高度（商家反馈看不清文字）
ck "整行输入框有最小高度" "$(grep -q '.row-input {.*min-height' "$CREATE_WXSS" && echo yes || echo no)" "yes"
ck "行内输入框放宽到 440rpx" "$(grep -q 'max-width: 440rpx' "$CREATE_WXSS" && echo yes || echo no)" "yes"
ck "行内输入框有最小宽度兜底" "$(grep -q 'min-width: 300rpx' "$CREATE_WXSS" && echo yes || echo no)" "yes"
ck "滚动容器有高度（否则锚点定位不动）" "$(grep -q '.form-scroll' "$CREATE_WXSS" && echo yes || echo no)" "yes"

# ---- 7) 创建页优先用带名字的 stores 渲染门店选择
ck "创建页读 staff.stores 取门店名" "$(grep -q 'staff.stores' "$CREATE_JS" && echo yes || echo no)" "yes"

echo "=== PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ] || exit 1
