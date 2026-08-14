#!/usr/bin/env bash
# C3 commission 链路 smoke: member→distributor→order(distributorId)→paySuccess→commission
set -e
H=http://127.0.0.1:8080
APPID="${APPID:-wx9e147c4e2151b123}"
PRODUCT_ID="${PRODUCT_ID:-1000}"
DB_CMD="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"

JSCODE="c3smoke_$(date +%s)_$$"
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}
# 数值比较 (容差 0.01)
num_eq() { python3 -c "import sys; sys.exit(0 if abs($1 - $2) < 0.01 else 1)"; }

ORDER_ID=""
DIST_ID=""
COMM_ID=""

cleanup() {
  [ -n "$ORDER_ID" ] && $DB_CMD -e "DELETE FROM biz_order WHERE order_id=$ORDER_ID;" 2>/dev/null || true
  [ -n "$COMM_ID" ] && $DB_CMD -e "DELETE FROM biz_commission WHERE commission_id=$COMM_ID;" 2>/dev/null || true
  [ -n "$DIST_ID" ] && $DB_CMD -e "DELETE FROM biz_distributor WHERE distributor_id=$DIST_ID;" 2>/dev/null || true
}
trap cleanup EXIT

echo "C3 commission 链路 smoke:"

# A) member mock 登录
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE\",\"appid\":\"$APPID\",\"nickName\":\"c3smoke\"}" $H/api/auth/login)
MEMBER_TOKEN=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
MEMBER_ID=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ ${#MEMBER_TOKEN} -gt 50 ] && [ "$MEMBER_ID" -gt 0 ] || { echo "FAIL: member login"; exit 1; }
echo "[A] memberId=$MEMBER_ID"

# B) DB 把这个 member 升级为 distributor
DIST_ID=$($DB_CMD -N -e "
INSERT INTO biz_distributor (member_id, merchant_id, level, status, join_time, create_time)
VALUES ($MEMBER_ID, 1, 1, '0', NOW(), NOW());
SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
[ -n "$DIST_ID" ] && [ "$DIST_ID" -gt 0 ] || { echo "FAIL: insert distributor"; exit 1; }
echo "[B] distributor_id=$DIST_ID (member=$MEMBER_ID mid=1 level=1)"

# C) 下单带 distributorId
RESP=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MEMBER_TOKEN" \
  -d "{\"productId\":$PRODUCT_ID,\"num\":1,\"distributorId\":$DIST_ID}" $H/api/order)
ORDER_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['orderId'])" 2>/dev/null)
PAY_AMOUNT=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['payAmount'])" 2>/dev/null)
[ -n "$ORDER_ID" ] && echo "  ✅ C) POST /api/order (orderId=$ORDER_ID payAmount=$PAY_AMOUNT)" && PASS=$((PASS+1)) || { echo "  ❌ no orderId: $RESP"; FAIL=$((FAIL+1)); exit 1; }

# D) 预支付 mock → 触发 paySuccess → settleForOrder → commission 入账
PREPAY=$(curl -s -X POST -H "Authorization: Bearer $MEMBER_TOKEN" $H/api/order/prepay/$ORDER_ID)
chk "D) POST /api/order/prepay (mock)" "mock" "$PREPAY"

# E) DB 验 commission
sleep 1
COMM_ROW=$($DB_CMD -N -e "SELECT commission_id, amount, rate, status FROM biz_commission WHERE order_id=$ORDER_ID;" 2>/dev/null)
echo "  [E] commission row: '$COMM_ROW'"
COMM_ID=$(echo "$COMM_ROW" | awk '{print $1}')
COMM_AMT=$(echo "$COMM_ROW" | awk '{print $2}')
COMM_RATE=$(echo "$COMM_ROW" | awk '{print $3}')

EXPECTED_AMT=$(python3 -c "print(round($PAY_AMOUNT * 0.10, 2))")

if [ -n "$COMM_ID" ] && [ "$COMM_ID" -gt 0 ]; then
  echo "  ✅ E1) biz_commission 新行 (id=$COMM_ID amount=$COMM_AMT rate=$COMM_RATE expected=$EXPECTED_AMT)"
  PASS=$((PASS+1))
  if num_eq "$COMM_AMT" "$EXPECTED_AMT"; then
    echo "  ✅ E2) amount=$COMM_AMT ≈ payAmount($PAY_AMOUNT) * 10% (= $EXPECTED_AMT)"
    PASS=$((PASS+1))
  else
    echo "  ❌ E2) amount=$COMM_AMT want ~$EXPECTED_AMT"
    FAIL=$((FAIL+1))
  fi
else
  echo "  ❌ E1) no commission row for orderId=$ORDER_ID"
  FAIL=$((FAIL+1))
fi

# distributor.frozenAmount 累加
NEW_FROZEN=$($DB_CMD -N -e "SELECT IFNULL(frozen_amount,0) FROM biz_distributor WHERE distributor_id=$DIST_ID;" 2>/dev/null)
if num_eq "$NEW_FROZEN" "$COMM_AMT" && [ "$NEW_FROZEN" != "0.00" ] && [ -n "$NEW_FROZEN" ]; then
  echo "  ✅ E3) distributor.frozenAmount → $NEW_FROZEN (+$COMM_AMT)"
  PASS=$((PASS+1))
else
  echo "  ❌ E3) frozenAmount=$NEW_FROZEN want ~$COMM_AMT"
  FAIL=$((FAIL+1))
fi

# F) settle_days=7 验证: status=0 还在冻结期
COMM_STATUS=$($DB_CMD -N -e "SELECT status FROM biz_commission WHERE commission_id=$COMM_ID;" 2>/dev/null)
[ "$COMM_STATUS" = "0" ] && echo "  ✅ F) commission status=0 (冷静期冻结, settle_days=7)" && PASS=$((PASS+1)) || { echo "  ❌ F) status=$COMM_STATUS want 0"; FAIL=$((FAIL+1)); }

echo "C3 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
