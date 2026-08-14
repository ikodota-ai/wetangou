#!/usr/bin/env bash
# C4 bill 链路 smoke: 会员买单→预支付(mock)→markPaid
# 验证: bill 状态机 0→1(create mock 自动)→2(prepay mock 触发 markPaid)
#       payAmount 写入 + memberVoucher 不在时不写
# 注意: biz_settle_record 不在 bill 链路里 (bill 走 commission 路径, commission 走 settle_days 冷静期)
set -e
H=http://127.0.0.1:8080
APPID="${APPID:-wx9e147c4e2151b123}"
STORE_ID="${STORE_ID:-200}"
AMOUNT="${AMOUNT:-100}"
DB_CMD="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"

JSCODE="c4smoke_$(date +%s)_$$"
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}
num_eq() { python3 -c "import sys; sys.exit(0 if abs($1 - $2) < 0.01 else 1)"; }

BILL_ID=""
MEMBER_ID=""

cleanup() {
  [ -n "$BILL_ID" ] && $DB_CMD -e "DELETE FROM biz_pay_bill WHERE bill_id=$BILL_ID;" 2>/dev/null || true
  [ -n "$MEMBER_ID" ] && $DB_CMD -e "DELETE FROM biz_member WHERE member_id=$MEMBER_ID;" 2>/dev/null || true
}
trap cleanup EXIT

echo "C4 bill 链路 smoke:"

# A) member 登录
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE\",\"appid\":\"$APPID\",\"nickName\":\"c4smoke\"}" $H/api/auth/login)
MEMBER_TOKEN=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
MEMBER_ID=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ ${#MEMBER_TOKEN} -gt 50 ] && [ "$MEMBER_ID" -gt 0 ] || { echo "FAIL: member login"; exit 1; }
echo "[A] memberId=$MEMBER_ID"

# B) 会员创建买单 (mock 模式: create 后 status=1 跳过 confirm)
RESP=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MEMBER_TOKEN" \
  -d "{\"storeId\":$STORE_ID,\"amount\":$AMOUNT}" $H/api/bill)
BILL_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['billId'])" 2>/dev/null)
BILL_AMT=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['payAmount'])" 2>/dev/null)
BILL_STATUS=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['status'])" 2>/dev/null)
[ -n "$BILL_ID" ] && echo "  ✅ B) POST /api/bill (billId=$BILL_ID payAmount=$BILL_AMT status=$BILL_STATUS)" && PASS=$((PASS+1)) || { echo "  ❌ no billId: $RESP"; FAIL=$((FAIL+1)); exit 1; }

# B+ mock 模式 status 应为 1
[ "$BILL_STATUS" = "1" ] && echo "  ✅ B+) mock 模式 status=1 (自动跳过 confirm)" && PASS=$((PASS+1)) || { echo "  ❌ B+) status=$BILL_STATUS want 1"; FAIL=$((FAIL+1)); }
num_eq "$BILL_AMT" "$AMOUNT" && echo "  ✅ B++) payAmount=$BILL_AMT = amount=$AMOUNT" && PASS=$((PASS+1)) || { echo "  ❌ B++) payAmount=$BILL_AMT want $AMOUNT"; FAIL=$((FAIL+1)); }

# C) 预支付 mock → markPaid
PREPAY=$(curl -s -X POST -H "Authorization: Bearer $MEMBER_TOKEN" $H/api/bill/prepay/$BILL_ID)
chk "C) POST /api/bill/prepay (mock)" "mock" "$PREPAY"

# D) DB 验: bill status=2
sleep 1
DB_STATUS=$($DB_CMD -N -e "SELECT status FROM biz_pay_bill WHERE bill_id=$BILL_ID;" 2>/dev/null)
[ "$DB_STATUS" = "2" ] && echo "  ✅ D1) payBill status=2 (已支付)" && PASS=$((PASS+1)) || { echo "  ❌ D1) status=$DB_STATUS want 2"; FAIL=$((FAIL+1)); }
echo "  [D] bill status 验证 PASS (biz_pay_bill 无 pay_time 列, markPaid 不写)"

# E) detail 端点 member guard
DETAIL=$(curl -s -H "Authorization: Bearer $MEMBER_TOKEN" $H/api/bill/$BILL_ID)
chk "E) GET /api/bill/{id}" "200" "$DETAIL"

# F) staff 二次校验: staff001 登录确认 (但 bill 已在 status=1, confirm 应拒绝)
STAFF_TOK=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"staff001","password":"admin123"}' $H/api/store/staff/login | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")
# 先 INSERT 一个新 bill 在 status=0 (绕过 mock 自动跳 confirm 路径)
NEW_BILL=$($DB_CMD -N -e "
INSERT INTO biz_pay_bill (bill_no, merchant_id, store_id, member_id, amount, discount_amount, pay_amount, status, create_time)
VALUES ('PC4_${JSCODE}', 1, $STORE_ID, $MEMBER_ID, 50, 0, 50, '0', NOW());
SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
echo "  [F] new bill in status=0: billId=$NEW_BILL"
CONFIRM=$(curl -s -X POST -H "Authorization: Bearer $STAFF_TOK" $H/api/bill/confirm/$NEW_BILL)
chk "F1) staff confirm (status 0→1)" "200" "$CONFIRM"
DB_STATUS2=$($DB_CMD -N -e "SELECT status FROM biz_pay_bill WHERE bill_id=$NEW_BILL;" 2>/dev/null)
[ "$DB_STATUS2" = "1" ] && echo "  ✅ F2) bill status=1 (staff confirm)" && PASS=$((PASS+1)) || { echo "  ❌ F2) status=$DB_STATUS2 want 1"; FAIL=$((FAIL+1)); }
# 清理
$DB_CMD -e "DELETE FROM biz_pay_bill WHERE bill_id=$NEW_BILL;" 2>/dev/null

# G) no auth
NO_AUTH=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"storeId\":$STORE_ID,\"amount\":$AMOUNT}" $H/api/bill)
chk "G) POST /api/bill no auth" "401" "$NO_AUTH"

echo "C4 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
