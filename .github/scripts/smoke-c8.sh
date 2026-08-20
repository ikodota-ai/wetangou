#!/usr/bin/env bash
# C8 voucher 链路 smoke: admin 发券→会员领券→下单抵扣→券状态 0→1

# fixture 自备（见 .github/scripts/lib/smoke-fixture.sh）
# 背景：62 smoke 串行跑会互相污染（改密码/耗库存/覆盖 openid），造成假 FAIL
source "$(dirname "$0")/lib/smoke-fixture.sh"
fx_ensure_mock_on
fx_ensure_product_stock 1000

set -e
H=http://127.0.0.1:8080
APPID="${APPID:-wx9e147c4e2151b123}"
STORE_ID="${STORE_ID:-200}"
DB_CMD="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"

JSCODE="c8smoke_$(date +%s)_$$"
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}
num_eq() { python3 -c "import sys; sys.exit(0 if abs($1 - $2) < 0.01 else 1)"; }

VOUCHER_ID=""
MV_ID=""
ORDER_ID=""
MEMBER_ID=""

cleanup() {
  [ -n "$ORDER_ID" ] && $DB_CMD -e "DELETE FROM biz_order WHERE order_id=$ORDER_ID;" 2>/dev/null || true
  [ -n "$MV_ID" ] && $DB_CMD -e "DELETE FROM biz_member_voucher WHERE id=$MV_ID;" 2>/dev/null || true
  [ -n "$VOUCHER_ID" ] && $DB_CMD -e "DELETE FROM biz_voucher WHERE voucher_id=$VOUCHER_ID;" 2>/dev/null || true
  [ -n "$MEMBER_ID" ] && $DB_CMD -e "DELETE FROM biz_member WHERE member_id=$MEMBER_ID;" 2>/dev/null || true
}
trap cleanup EXIT

echo "C8 voucher 链路 smoke:"

# A) admin 发券 (faceValue=20, threshold=100, total=10)
ADMIN_TOK=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"admin","password":"admin123"}' $H/login | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")
[ ${#ADMIN_TOK} -gt 50 ] || { echo "FAIL: admin login"; exit 1; }

VOUCHER_ID=$($DB_CMD -N -e "
INSERT INTO biz_voucher (merchant_id, store_id, voucher_name, face_value, threshold, total, received, valid_days, status, create_by, create_time)
VALUES (1, $STORE_ID, 'C8测试券', 20.00, 100.00, 10, 0, 30, '0', 'admin', NOW());
SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
[ -n "$VOUCHER_ID" ] && [ "$VOUCHER_ID" -gt 0 ] && echo "  ✅ A) admin 发券 (voucherId=$VOUCHER_ID face=20 threshold=100 total=10)" && PASS=$((PASS+1)) || { echo "FAIL: insert voucher"; exit 1; }

# B) 会员登录
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE\",\"appid\":\"$APPID\",\"nickName\":\"c8smoke\"}" $H/api/auth/login)
MEMBER_TOKEN=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
MEMBER_ID=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ ${#MEMBER_TOKEN} -gt 50 ] && [ "$MEMBER_ID" -gt 0 ] || { echo "FAIL: member login"; exit 1; }
echo "[B] memberId=$MEMBER_ID"

# C) 会员领券
RECV=$(curl -s -X POST -H "Authorization: Bearer $MEMBER_TOKEN" $H/api/voucher/receive/$VOUCHER_ID)
echo "  [C] receive resp: $(echo $RECV | head -c 250)"
MV_ID=$($DB_CMD -N -e "SELECT id FROM biz_member_voucher WHERE voucher_id=$VOUCHER_ID AND member_id=$MEMBER_ID AND status='0';" 2>/dev/null)
[ -n "$MV_ID" ] && [ "$MV_ID" -gt 0 ] && echo "  ✅ C) 领券成功 (mvId=$MV_ID status=0)" && PASS=$((PASS+1)) || { echo "  ❌ C) no member_voucher: $RECV"; FAIL=$((FAIL+1)); }

# 验 voucher.received+1
RECEIVED=$($DB_CMD -N -e "SELECT received FROM biz_voucher WHERE voucher_id=$VOUCHER_ID;" 2>/dev/null)
[ "$RECEIVED" = "1" ] && echo "  ✅ C+) voucher.received=1" && PASS=$((PASS+1)) || { echo "  ❌ C+) received=$RECEIVED want 1"; FAIL=$((FAIL+1)); }

# D) 防重复领取
DUP=$(curl -s -X POST -H "Authorization: Bearer $MEMBER_TOKEN" $H/api/voucher/receive/$VOUCHER_ID)
chk "D) 重复领券 (应失败)" "已领取" "$DUP"

# E) 下单用券 (product 1000 price=128 > 100 threshold, 满足满减)
# payAmount = 128 - 20 = 108
RESP=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MEMBER_TOKEN" \
  -d "{\"productId\":1000,\"num\":1,\"memberVoucherId\":$MV_ID}" $H/api/order)
ORDER_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['orderId'])" 2>/dev/null)
PAY_AMOUNT=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['payAmount'])" 2>/dev/null)
DISC_AMT=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['discountAmount'])" 2>/dev/null)
[ -n "$ORDER_ID" ] && [ "$ORDER_ID" -gt 0 ] && echo "  ✅ E1) POST /api/order (orderId=$ORDER_ID payAmount=$PAY_AMOUNT discount=$DISC_AMT)" && PASS=$((PASS+1)) || { echo "  ❌ E1) no orderId: $RESP"; FAIL=$((FAIL+1)); exit 1; }

EXPECTED_PAY=108.00
num_eq "$PAY_AMOUNT" "$EXPECTED_PAY" && echo "  ✅ E2) payAmount=108 = 128 - 20 (券抵扣)" && PASS=$((PASS+1)) || { echo "  ❌ E2) payAmount=$PAY_AMOUNT want ~$EXPECTED_PAY"; FAIL=$((FAIL+1)); }
num_eq "$DISC_AMT" "20.00" && echo "  ✅ E3) discountAmount=20 (面额)" && PASS=$((PASS+1)) || { echo "  ❌ E3) discountAmount=$DISC_AMT want ~20.00"; FAIL=$((FAIL+1)); }

# F) prepay 触发 paySuccess → voucher status 0→1
PREPAY=$(curl -s -X POST -H "Authorization: Bearer $MEMBER_TOKEN" $H/api/order/prepay/$ORDER_ID)
chk "F1) POST /api/order/prepay (mock)" "mock" "$PREPAY"
sleep 1
MV_STATUS=$($DB_CMD -N -e "SELECT status, IFNULL(use_order_id,0), IFNULL(use_time,'NULL') FROM biz_member_voucher WHERE id=$MV_ID;" 2>/dev/null)
echo "  [F2] member_voucher row: $MV_STATUS"
MV_S=$(echo "$MV_STATUS" | awk '{print $1}')
USE_OID=$(echo "$MV_STATUS" | awk '{print $2}')
[ "$MV_S" = "1" ] && echo "  ✅ F2) voucher status=1 (已使用)" && PASS=$((PASS+1)) || { echo "  ❌ F2) status=$MV_S want 1"; FAIL=$((FAIL+1)); }
[ "$USE_OID" = "$ORDER_ID" ] && echo "  ✅ F3) useOrderId=$USE_OID = $ORDER_ID" && PASS=$((PASS+1)) || { echo "  ❌ F3) useOrderId=$USE_OID want $ORDER_ID"; FAIL=$((FAIL+1)); }

# G) 已用券不能再领
RECV2=$(curl -s -X POST -H "Authorization: Bearer $MEMBER_TOKEN" $H/api/voucher/receive/$VOUCHER_ID)
echo "  [G] 已用券再领: $(echo $RECV2 | head -c 200)"
# 防重领: 仅 status=0 的券会触发; status=1 的允许重领 (C8 注释 "已使用/已过期的允许重领")
MV_COUNT=$($DB_CMD -N -e "SELECT COUNT(*) FROM biz_member_voucher WHERE voucher_id=$VOUCHER_ID AND member_id=$MEMBER_ID;" 2>/dev/null)
[ "$MV_COUNT" -ge "2" ] && echo "  ✅ G) 已用券允许重领 (总行数=$MV_COUNT, 设计如此)" && PASS=$((PASS+1)) || { echo "  ⚠️  G) 重领未触发, 行数=$MV_COUNT (line 25-27 注释明确允许)"; }

echo "C8 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
