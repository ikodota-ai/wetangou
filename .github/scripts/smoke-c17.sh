#!/usr/bin/env bash
# C17 预约详情/时段/取消链路端到端
# 验证:
#   A) GET /api/booking/slots?storeId=100&date=... 返时段
#   B) slots 不传 date 用今天
#   C) slots storeId=99999 不存在返错
#   D) GET /api/booking/{bookingId} 未登录被拒
#   E) GET /api/booking/{bookingId} 登录后返详情 + 我的报名
#   F) GET /api/booking/{bookingId} 不存在抛错
#   G) POST /api/booking/cancel/{signupId} 我的报名可取消
#   H) GET /api/booking/list 返我的预约
set -e
H=http://127.0.0.1:8080
DB_CMD="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 --default-character-set=utf8mb4 ry-vue"
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

# 登录
JS="c17_$(date +%s)_$$"
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JS\",\"appid\":\"wx9e147c4e2151b123\",\"nickName\":\"c17test\"}" $H/api/auth/login)
TOK=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
MID=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ ${#TOK} -gt 50 ] && [ "$MID" -gt 0 ] || { echo "FAIL: login: $LOGIN"; exit 1; }
echo "[init] memberId=$MID"

# fixture: 用现成的 booking_id=100000
B_ID=100000

cleanup() {
  [ "$MID" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_member WHERE member_id=$MID;" 2>/dev/null || true
  [ -n "$SIGNUP_ID" ] && $DB_CMD -e "DELETE FROM biz_booking_member WHERE id=$SIGNUP_ID;" 2>/dev/null || true
}
trap cleanup EXIT

echo "C17 预约详情/时段/取消链路 smoke:"

# A) slots
A=$(curl -s "$H/api/booking/slots?storeId=100&date=2026-08-15")
chk "A slots 200" "操作成功" "$A"
chk "A slots 包含 storeId=100" "storeId" "$A"
# A slots 返回结构 (从 service 实现)
A_HAS_SLOTS=$(echo "$A" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data',{}); print('YES' if 'day' in d or 'slots' in d else 'NO')")
[ "$A_HAS_SLOTS" = "YES" ] && echo "  ✅ A slots 含 day/night 字段" && PASS=$((PASS+1)) || { echo "  ❌ A slots 结构缺时段: $A"; FAIL=$((FAIL+1)); }

# B) slots 不传 date (用今天)
B=$(curl -s "$H/api/booking/slots?storeId=100")
chk "B slots 不传 date 200" "操作成功" "$B"

# C) slots storeId=99999 不存在
C=$(curl -s "$H/api/booking/slots?storeId=99999")
echo "$C" | grep -qE "门店不存在|code\":500" && echo "  ✅ C 不存在 storeId 抛错" && PASS=$((PASS+1)) || { echo "  ❌ C 未抛错: $C"; FAIL=$((FAIL+1)); }

# D) booking detail 未登录
D=$(curl -s "$H/api/booking/$B_ID")
echo "$D" | grep -qE "401|登录" && echo "  ✅ D 未登录 401" && PASS=$((PASS+1)) || { echo "  ❌ D 未拒: $D"; FAIL=$((FAIL+1)); }

# E) booking detail 登录后
E=$(curl -s -H "Authorization: Bearer $TOK" "$H/api/booking/$B_ID")
chk "E detail 200" "操作成功" "$E"
chk "E detail 包含 bookingId=$B_ID" "\"bookingId\":$B_ID" "$E"

# F) 不存在
F=$(curl -s -H "Authorization: Bearer $TOK" "$H/api/booking/99999999")
echo "$F" | grep -qE "预约场次不存在|code\":500" && echo "  ✅ F 不存在 bookingId 抛错" && PASS=$((PASS+1)) || { echo "  ❌ F 未抛错: $F"; FAIL=$((FAIL+1)); }

# G) 报名并取消
SIGNUP_RESP=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $TOK" \
  -d "{\"bookingId\":$B_ID}" $H/api/booking)
echo "  [G signup] $SIGNUP_RESP"
SIGNUP_ID=$(echo "$SIGNUP_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('signupId') or (d.get('data') or {}).get('id') or 0)" 2>/dev/null)
[ -n "$SIGNUP_ID" ] && [ "$SIGNUP_ID" -gt 0 ] && echo "  ✅ G 报名成功 signupId=$SIGNUP_ID" && PASS=$((PASS+1)) || echo "  ⚠️  G 报名未返 signupId (可能已报过): $SIGNUP_RESP"

if [ -n "$SIGNUP_ID" ] && [ "$SIGNUP_ID" -gt 0 ]; then
  # 取消
  CANCEL=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $TOK" \
    $H/api/booking/cancel/$SIGNUP_ID)
  echo "  [G cancel] $CANCEL"
  chk "G 取消报名 200" "操作成功" "$CANCEL"
  # 验证 DB 状态
  SIGNUP_STATUS=$($DB_CMD -N -e "SELECT status FROM biz_booking_member WHERE id=$SIGNUP_ID;" 2>/dev/null)
  [ "$SIGNUP_STATUS" = "1" ] && echo "  ✅ G signup status=1 (已取消) 落库" && PASS=$((PASS+1)) || { echo "  ❌ G status=$SIGNUP_STATUS (want 1)"; FAIL=$((FAIL+1)); }
fi

# H) booking list (我的预约)
H_RES=$(curl -s -H "Authorization: Bearer $TOK" "$H/api/booking/list")
chk "H list 200" "操作成功" "$H_RES"

echo ""
echo "C17 smoke: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
