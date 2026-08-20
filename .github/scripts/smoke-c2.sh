#!/usr/bin/env bash
# C2 业务全链路 smoke: 会员下单→预支付(mock)→门店核销
# 验证:
#   A) member login (mock appid) → token
#   B) POST /api/order {productId, num} → orderId, status=0
#   C) POST /api/order/prepay/{id} (mock) → mock=true + status=1 + verifyCode
#   D) staff 登录 → POST /api/order/verify {storeId, verifyCode} → status=2 + verifyTime
#   E) no auth → 401
#
# 前置: 后端 8080 在跑; productId=1000 mid=1 storeId=200; staff001 已关联 store 200

# fixture 自备（见 .github/scripts/lib/smoke-fixture.sh）
# 背景：62 smoke 串行跑会互相污染（改密码/耗库存/覆盖 openid），造成假 FAIL
source "$(dirname "$0")/lib/smoke-fixture.sh"
fx_ensure_mock_on
fx_ensure_product_stock 1000

set -e
H=http://127.0.0.1:8080
APPID="${APPID:-wx9e147c4e2151b123}"
PRODUCT_ID="${PRODUCT_ID:-1000}"
STORE_ID="${STORE_ID:-200}"
DB="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"

JSCODE="c2smoke_$(date +%s)_$$"
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}
P() { python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('code',''), d.get('msg',''), d.get('data',''))"; }

echo "C2 业务全链路 smoke (member→order→prepay→verify):"

# A) member login
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE\",\"appid\":\"$APPID\",\"nickName\":\"c2smoke\"}" \
  $H/api/auth/login)
MEMBER_TOKEN=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
MEMBER_ID=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ ${#MEMBER_TOKEN} -gt 50 ] || { echo "FAIL: no member token"; exit 1; }
echo "[A] memberId=$MEMBER_ID"

# B) 下单
RESP=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MEMBER_TOKEN" \
  -d "{\"productId\":$PRODUCT_ID,\"num\":1}" \
  $H/api/order)
ORDER_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['orderId'])" 2>/dev/null)
ORDER_STATUS=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['status'])" 2>/dev/null)
chk "B) POST /api/order" "200" "$RESP"
[ "$ORDER_STATUS" = "0" ] && echo "  [B] orderId=$ORDER_ID status=0 (待付款)" && PASS=$((PASS+1)) || { echo "  ❌ order status=$ORDER_STATUS (want 0)"; FAIL=$((FAIL+1)); }

# C) 预支付 (mock 模式)
PREPAY=$(curl -s -X POST -H "Authorization: Bearer $MEMBER_TOKEN" $H/api/order/prepay/$ORDER_ID)
chk "C) POST /api/order/prepay" "mock" "$PREPAY"
DB_STATUS=$($DB -N -e "SELECT status FROM biz_order WHERE order_id=$ORDER_ID;" 2>/dev/null)
DB_VCODE=$($DB -N -e "SELECT verify_code FROM biz_order WHERE order_id=$ORDER_ID;" 2>/dev/null)
[ "$DB_STATUS" = "1" ] && echo "  [C] DB status=1 (已付款) verifyCode=$DB_VCODE" && PASS=$((PASS+1)) || { echo "  ❌ DB status=$DB_STATUS (want 1)"; FAIL=$((FAIL+1)); }
[ -n "$DB_VCODE" ] && [ "$DB_VCODE" != "None" ] || { echo "  ❌ verifyCode empty"; FAIL=$((FAIL+1)); }

# D) 门店核销
STAFF_TOK=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"staff001","password":"admin123"}' $H/api/store/staff/login | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")
[ ${#STAFF_TOK} -gt 50 ] || { echo "FAIL: no staff token"; exit 1; }
VERIFY=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STAFF_TOK" \
  -d "{\"storeId\":$STORE_ID,\"verifyCode\":\"$DB_VCODE\"}" \
  $H/api/order/verify)
chk "D) POST /api/order/verify" "200" "$VERIFY"
DB_STATUS2=$($DB -N -e "SELECT status FROM biz_order WHERE order_id=$ORDER_ID;" 2>/dev/null)
DB_VUSER=$($DB -N -e "SELECT verify_user FROM biz_order WHERE order_id=$ORDER_ID;" 2>/dev/null)
[ "$DB_STATUS2" = "2" ] && echo "  [D] DB status=2 (已核销) verifyUser=$DB_VUSER" && PASS=$((PASS+1)) || { echo "  ❌ DB status=$DB_STATUS2 (want 2)"; FAIL=$((FAIL+1)); }

# E) no auth (RuoYi AjaxResult 全用 HTTP 200 + body.code=401)
NO_AUTH=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"productId\":$PRODUCT_ID,\"num\":1}" $H/api/order)
chk "E) POST /api/order no auth" "401" "$NO_AUTH"

echo "C2 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
