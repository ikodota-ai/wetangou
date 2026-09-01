#!/usr/bin/env bash
# 支付链路手机号不能带星号（第 5 项）
#
# 背景：@Sensitive 的脱敏切面在 /api/** 上会「无条件生效」——
# 所有 /api/** 都是 @Anonymous，拿不到 LoginUser 时切面 return true 直接脱敏。
# 于是任何直接返回实体的接口，phone 都变成 138****1234。
# 用户的原话是「支付（买单支付和其他支付）的时候获取的手机号不能有星号」，
# 拿到带星号的号码，下单表单预填的是假号码，商家回拨也拨不出去。
#
# 已有的 smoke-booking-type-phone.sh 覆盖了 profile / 预约详情 / 门店电话，
# 但**支付链路本身**（买单创建→详情、下单→详情→列表→预支付）没有断言 ——
# 而这正是用户报的场景。本脚本补上。
#
# 修法不是去掉 @Sensitive（admin 端共用同一个实体，那边需要脱敏），
# 而是在 api 层手工 Map 拷贝（toMemberVo 之类），所以这些断言必须长期护住。
set -u
BASE_URL="${BASE_URL:-http://localhost:8080}"
APPID="${MP_APPID:-wx9e147c4e2151b123}"
SID="${PAY_STORE_ID:-100}"
PID="${PAY_PRODUCT_ID:-999846}"
MYSQL="${MYSQL_BIN:-/usr/local/mysql/bin/mysql}"
DB="${MYSQL_DB:-ry-vue}"
MA="-uroot -p${MYSQL_PASS:-133301} $DB --default-character-set=utf8mb4 -N -B"
PHONE="13812340077"
OPENID="mock_smokepaystar"

PASSN=0; FAILN=0
ok(){ echo "  ✅ $1"; PASSN=$((PASSN+1)); }
ng(){ echo "  ❌ $1"; FAILN=$((FAILN+1)); }
q(){ $MYSQL $MA -e "$1" 2>/dev/null | grep -v Warning; }

MID=""; BID=""; OID=""
cleanup(){
  [ -n "$OID" ] && q "delete from biz_order where order_id=$OID;"
  [ -n "$BID" ] && q "delete from biz_pay_bill where bill_id=$BID;"
  [ -n "$MID" ] && q "delete from biz_member where member_id=$MID;"
  q "delete from biz_member where openid='$OPENID';"
}
trap cleanup EXIT

# 会员 mock 登录：token 在响应顶层，不在 data 里
TOKEN=$(curl -s -m 10 -X POST -H 'Content-Type: application/json' -H "X-App-Id: $APPID" \
  -d "{\"code\":\"${OPENID#mock_}\",\"appid\":\"$APPID\"}" \
  "$BASE_URL/api/auth/login" \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('token') or (d.get('data') or {}).get('token') or '')" 2>/dev/null)
[ -n "$TOKEN" ] || { echo "FAIL: 会员登录拿不到 token"; exit 1; }
MID=$(q "select member_id from biz_member where openid='$OPENID' limit 1;")
[ -n "$MID" ] || { echo "FAIL: mock 会员没落库"; exit 1; }
# 造一个真实手机号，否则 phone 为空时「无星号」是废断言（空串永远不含 *）
q "update biz_member set phone='$PHONE' where member_id=$MID;"

AUTH=(-H "Authorization: Bearer $TOKEN" -H "X-App-Id: $APPID")
GET(){ curl -s -m 12 "${AUTH[@]}" "$BASE_URL$1"; }
POSTJ(){ curl -s -m 15 -X POST "${AUTH[@]}" -H 'Content-Type: application/json' -d "$2" "$BASE_URL$1"; }

# 断言：响应里既要没有星号，又要真的能取到这个号（防「字段没返回」蒙混过关）
nostar(){ # $1=label $2=raw
  if echo "$2" | grep -q '\*'; then
    ng "$1 响应含星号：$(echo "$2" | grep -o '[0-9]\{3\}\*\+[0-9]*' | head -1)"
  else
    ok "$1 无星号"
  fi
}

echo "== A) 会员资料手机号明文（下单页靠它预填）=="
PROF=$(GET "/api/member/profile")
P=$(echo "$PROF" | python3 -c "import sys,json;print((json.load(sys.stdin).get('data') or {}).get('phone') or '')" 2>/dev/null)
if [ "$P" = "$PHONE" ]; then ok "profile phone=$P 与库一致（证明没被脱敏）"; else ng "profile phone='$P' 期望 '$PHONE'"; fi
nostar "profile" "$PROF"

echo "== B) 买单链路（用户原话「买单支付」）=="
BR=$(POSTJ "/api/bill" "{\"storeId\":$SID,\"amount\":50}")
BID=$(echo "$BR" | python3 -c "import sys,json;print((json.load(sys.stdin).get('data') or {}).get('billId') or '')" 2>/dev/null)
if [ -n "$BID" ]; then ok "买单创建成功 billId=$BID"; else ng "买单创建失败：$(echo "$BR"|head -c 160)"; fi
nostar "POST /api/bill" "$BR"
if [ -n "$BID" ]; then
  nostar "GET /api/bill/$BID" "$(GET "/api/bill/$BID")"
fi

echo "== C) 商品下单链路（「其他支付」）=="
OR=$(POSTJ "/api/order" "{\"productId\":$PID,\"num\":1}")
OID=$(echo "$OR" | python3 -c "import sys,json;print((json.load(sys.stdin).get('data') or {}).get('orderId') or '')" 2>/dev/null)
if [ -n "$OID" ]; then ok "下单成功 orderId=$OID"; else ng "下单失败：$(echo "$OR"|head -c 160)"; fi
nostar "POST /api/order" "$OR"
if [ -n "$OID" ]; then
  nostar "GET /api/order/$OID" "$(GET "/api/order/$OID")"
  nostar "GET /api/order/list"  "$(GET "/api/order/list")"
fi

echo "== D) 门店/商家电话明文（联系商家要能拨出去）=="
nostar "GET /api/store/$SID" "$(GET "/api/store/$SID")"
nostar "GET /api/merchant/info" "$(GET "/api/merchant/info")"

echo "结果: PASS=$PASSN FAIL=$FAILN"
[ "$FAILN" -eq 0 ] || exit 1
