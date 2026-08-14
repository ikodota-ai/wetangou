#!/usr/bin/env bash
# C5 booking 链路 smoke: 会员预约→staff 审核（confirm/reject）→会员查
set -e
H=http://127.0.0.1:8080
APPID="${APPID:-wx9e147c4e2151b123}"
STORE_ID="${STORE_ID:-200}"
PRODUCT_ID="${PRODUCT_ID:-1000}"
DB_CMD="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"

JSCODE="c5smoke_$(date +%s)_$$"
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

SIGNUP_ID=""
SIGNUP2_ID=""
BOOKING_ID=""
MEMBER_ID=""

cleanup() {
  [ -n "$SIGNUP_ID" ] && $DB_CMD -e "DELETE FROM biz_booking_member WHERE id=$SIGNUP_ID;" 2>/dev/null || true
  [ -n "$SIGNUP2_ID" ] && $DB_CMD -e "DELETE FROM biz_booking_member WHERE id=$SIGNUP2_ID;" 2>/dev/null || true
  [ -n "$BOOKING_ID" ] && $DB_CMD -e "DELETE FROM biz_booking WHERE booking_id=$BOOKING_ID;" 2>/dev/null || true
  [ -n "$MEMBER_ID" ] && $DB_CMD -e "DELETE FROM biz_member WHERE member_id=$MEMBER_ID;" 2>/dev/null || true
}
trap cleanup EXIT

echo "C5 booking 链路 smoke:"

# A) member 登录
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE\",\"appid\":\"$APPID\",\"nickName\":\"c5smoke\"}" $H/api/auth/login)
MEMBER_TOKEN=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
MEMBER_ID=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ ${#MEMBER_TOKEN} -gt 50 ] && [ "$MEMBER_ID" -gt 0 ] || { echo "FAIL: member login"; exit 1; }
echo "[A] memberId=$MEMBER_ID"

# B) 会员创建预约 (booking + booking_member 同步创建/复用)
DATE=$(date -v+1d +%Y-%m-%d 2>/dev/null || date -d "tomorrow" +%Y-%m-%d)
RESP=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MEMBER_TOKEN" \
  -d "{\"storeId\":$STORE_ID,\"productId\":$PRODUCT_ID,\"serviceName\":\"C5 测试服务\",\"bookingDate\":\"$DATE\",\"timeSlot\":\"14:00-15:00\",\"contact\":\"张三\",\"phone\":\"13800138000\",\"people\":2}" \
  $H/api/booking)
echo "  [B] create resp: $(echo $RESP | head -c 200)"
SIGNUP_ID=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('signupId','') or d.get('data',{}).get('signupId','') or d.get('data',{}).get('id',''))" 2>/dev/null)
BOOKING_ID=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('bookingId','') or d.get('data',{}).get('bookingId',''))" 2>/dev/null)
[ -n "$SIGNUP_ID" ] && [ "$SIGNUP_ID" -gt 0 ] && echo "  ✅ B) POST /api/booking (signupId=$SIGNUP_ID bookingId=$BOOKING_ID)" && PASS=$((PASS+1)) || { echo "  ❌ no signupId: $RESP"; FAIL=$((FAIL+1)); exit 1; }

# C) DB 验 signup status=0
DB_STATUS=$($DB_CMD -N -e "SELECT status FROM biz_booking_member WHERE id=$SIGNUP_ID;" 2>/dev/null)
[ "$DB_STATUS" = "0" ] && echo "  ✅ C) signup status=0 (待审核)" && PASS=$((PASS+1)) || { echo "  ❌ C) status=$DB_STATUS want 0"; FAIL=$((FAIL+1)); }

# D) staff 登录 + confirm
STAFF_TOK=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"staff001","password":"admin123"}' $H/api/store/staff/login | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")
[ ${#STAFF_TOK} -gt 50 ] || { echo "FAIL: staff login"; exit 1; }
CONFIRM=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STAFF_TOK" \
  -d '{"remark":"欢迎光临"}' $H/api/store/staff/booking/confirm/$SIGNUP_ID)
chk "D1) staff confirmSignup" "200" "$CONFIRM"
DB_STATUS2=$($DB_CMD -N -e "SELECT status, confirm_user FROM biz_booking_member WHERE id=$SIGNUP_ID;" 2>/dev/null)
DB_STATUS=$(echo "$DB_STATUS2" | awk '{print $1}')
DB_USER=$(echo "$DB_STATUS2" | awk '{print $2}')
[ "$DB_STATUS" = "2" ] && echo "  ✅ D2) signup status=2 (已确认) confirmUser=$DB_USER" && PASS=$((PASS+1)) || { echo "  ❌ D2) status=$DB_STATUS want 2"; FAIL=$((FAIL+1)); }
[ "$DB_USER" = "staff-7" ] && echo "  ✅ D3) confirmUser=staff-7 (staff001 user_id=7)" && PASS=$((PASS+1)) || echo "  ⚠️  D3) confirmUser=$DB_USER (expect staff-7)"

# E) 第二个 signup 走 reject 路径
DATE2=$(date -v+2d +%Y-%m-%d 2>/dev/null || date -d "+2 days" +%Y-%m-%d)
RESP2=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MEMBER_TOKEN" \
  -d "{\"storeId\":$STORE_ID,\"productId\":$PRODUCT_ID,\"serviceName\":\"C5 reject 测试\",\"bookingDate\":\"$DATE2\",\"timeSlot\":\"15:00-16:00\",\"contact\":\"李四\",\"phone\":\"13900139000\",\"people\":1}" \
  $H/api/booking)
SIGNUP2_ID=$(echo "$RESP2" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('signupId','') or d.get('data',{}).get('signupId','') or d.get('data',{}).get('id',''))" 2>/dev/null)
[ -n "$SIGNUP2_ID" ] && [ "$SIGNUP2_ID" -gt 0 ] && echo "  ✅ E1) 第二个 signup (id=$SIGNUP2_ID) for reject" && PASS=$((PASS+1)) || { echo "  ❌ E1) no signup2: $RESP2"; FAIL=$((FAIL+1)); }

REJECT=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STAFF_TOK" \
  -d '{"reason":"时段已满"}' $H/api/store/staff/booking/reject/$SIGNUP2_ID)
chk "E2) staff rejectSignup" "200" "$REJECT"
DB_S3=$($DB_CMD -N -e "SELECT status, review_remark FROM biz_booking_member WHERE id=$SIGNUP2_ID;" 2>/dev/null)
[ "$(echo "$DB_S3" | awk '{print $1}')" = "3" ] && echo "  ✅ E3) signup2 status=3 (已拒绝) reason=$(echo $DB_S3 | cut -d' ' -f2-)" && PASS=$((PASS+1)) || { echo "  ❌ E3) status=$(echo $DB_S3 | awk '{print $1}') want 3"; FAIL=$((FAIL+1)); }

# F) 重复 confirm 应被拒
RE_CONFIRM=$(curl -s -X POST -H "Authorization: Bearer $STAFF_TOK" $H/api/store/staff/booking/confirm/$SIGNUP_ID)
chk "F) 重复 confirm (应失败)" "已确认" "$RE_CONFIRM"

# G) member list 看 status 过滤
LIST_OK=$(curl -s -H "Authorization: Bearer $MEMBER_TOKEN" "$H/api/booking/list?status=2")
chk "G) member GET /api/booking/list?status=2" "200" "$LIST_OK"

# H) no auth
NO_AUTH=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"storeId\":$STORE_ID,\"productId\":$PRODUCT_ID,\"serviceName\":\"x\",\"bookingDate\":\"$DATE\",\"timeSlot\":\"09:00-10:00\"}" \
  $H/api/booking)
chk "H) POST /api/booking no auth" "401" "$NO_AUTH"

echo "C5 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
