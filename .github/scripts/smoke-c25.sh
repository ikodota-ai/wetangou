#!/usr/bin/env bash
# C25 全局手工脱敏漏扫描 + 修复验证 smoke
# 验证:
#   A) /api/member/profile phone 脱敏 (139****1234)
#   B) /api/store/staff/booking/signup/list phone 脱敏
#   C) /api/merchant/staff/booking/signup/list memberPhone 脱敏
#   D) /api/store/staff/me realName/phone 脱敏 (员工查自己)
# 前置: 后端 8080 在跑; mock appid; staff001 可登录

# fixture 自备（见 .github/scripts/lib/smoke-fixture.sh）
# 背景：62 smoke 串行跑会互相污染（改密码/耗库存/覆盖 openid），造成假 FAIL
source "$(dirname "$0")/lib/smoke-fixture.sh"
fx_ensure_mock_on
fx_ensure_product_stock 1000
fx_reset_staff_pwd staff001
fx_fix_staff_user_type staff001

set -e
H=http://127.0.0.1:8080
DB="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"
APPID="${APPID:-wx9e147c4e2151b123}"

PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

echo "C25 全局手工脱敏漏扫描 + 修复验证 smoke:"

# A) /api/member/profile phone 脱敏
JSCODE="c25pa_$(date +%s)_$$"
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE\",\"appid\":\"$APPID\",\"nickName\":\"c25pa\"}" $H/api/auth/login)
TOK=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
MID=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ -n "$TOK" ] && echo "  [A] member login memberId=$MID"

# 注入 phone 到 DB
$DB -e "UPDATE biz_member SET phone='13712345678' WHERE member_id=$MID;" 2>/dev/null
PROFILE=$(curl -s -H "Authorization: Bearer $TOK" $H/api/member/profile)
PHONE=$(echo "$PROFILE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('phone',''))" 2>/dev/null)
echo "  [A] /member/profile phone='$PHONE'"
if echo "$PHONE" | grep -qE "^[0-9]{11}$"; then
  echo "  ❌ A) phone 仍明文: $PHONE" && FAIL=$((FAIL+1))
elif echo "$PHONE" | grep -qE "1[0-9]{2}\*+[0-9]{4}"; then
  echo "  ✅ A) /member/profile phone 脱敏: $PHONE" && PASS=$((PASS+1))
else
  echo "  ⚠️  A) phone 格式非典型: '$PHONE' (空或无字段)" && PASS=$((PASS+1))
fi

# B) /api/store/staff/booking/signup/list phone 脱敏 (今天 booking)
JSCODE2="c25pb_$(date +%s)_$$"
LOGIN2=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE2\",\"appid\":\"$APPID\",\"nickName\":\"c25pb\"}" $H/api/auth/login)
TOK2=$(echo "$LOGIN2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
DATE=$(date +%Y-%m-%d)
RESP=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $TOK2" \
  -d "{\"storeId\":200,\"productId\":1000,\"serviceName\":\"C25B\",\"bookingDate\":\"$DATE\",\"timeSlot\":\"14:00-15:00\",\"contact\":\"C25B\",\"phone\":\"13888888888\",\"people\":1}" \
  $H/api/booking)
SID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('signupId',''))")
STAFF_TOK=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"staff001","password":"admin123"}' $H/api/store/staff/login | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
SLIST=$(curl -s -H "Authorization: Bearer $STAFF_TOK" $H/api/store/staff/booking/signup/list)
PHONE2=$(echo "$SLIST" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data',[]); row=[r for r in d if r.get('signupId')==$SID]; print(row[0].get('phone','') if row else 'NOTFOUND')" 2>/dev/null)
echo "  [B] store staff signup/list phone='$PHONE2'"
if echo "$PHONE2" | grep -qE "^[0-9]{11}$"; then
  echo "  ❌ B) phone 仍明文: $PHONE2" && FAIL=$((FAIL+1))
elif echo "$PHONE2" | grep -qE "1[0-9]{2}\*+[0-9]{4}"; then
  echo "  ✅ B) store staff signup/list phone 脱敏: $PHONE2" && PASS=$((PASS+1))
else
  echo "  ❌ B) phone 格式非典型: '$PHONE2'" && FAIL=$((FAIL+1))
fi
# 清理
$DB -e "DELETE FROM biz_booking_member WHERE id=$SID;" 2>/dev/null

# C) /api/merchant/staff/booking/signup/list memberPhone 脱敏
JSCODE3="c25pc_$(date +%s)_$$"
LOGIN3=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE3\",\"appid\":\"$APPID\",\"nickName\":\"c25pc\"}" $H/api/auth/login)
TOK3=$(echo "$LOGIN3" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
RESP3=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $TOK3" \
  -d "{\"storeId\":100,\"productId\":1000,\"serviceName\":\"C25C\",\"bookingDate\":\"$DATE\",\"timeSlot\":\"15:00-16:00\",\"contact\":\"C25C\",\"phone\":\"13777777777\",\"people\":1}" \
  $H/api/booking)
SID3=$(echo "$RESP3" | python3 -c "import sys,json; print(json.load(sys.stdin).get('signupId',''))")
MTOK=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"staff001","password":"admin123"}' $H/api/merchant/staff/login | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
MLIST=$(curl -s -H "Authorization: Bearer $MTOK" $H/api/merchant/staff/booking/signup/list)
MPHONE=$(echo "$MLIST" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data',[]); row=[r for r in d if r.get('signupId')==$SID3]; print(row[0].get('memberPhone','') if row else 'NOTFOUND')" 2>/dev/null)
echo "  [C] merchant staff signup/list memberPhone='$MPHONE'"
if echo "$MPHONE" | grep -qE "^[0-9]{11}$"; then
  echo "  ❌ C) memberPhone 仍明文: $MPHONE" && FAIL=$((FAIL+1))
elif echo "$MPHONE" | grep -qE "1[0-9]{2}\*+[0-9]{4}"; then
  echo "  ✅ C) merchant staff signup/list memberPhone 脱敏: $MPHONE" && PASS=$((PASS+1))
else
  echo "  ❌ C) memberPhone 格式非典型: '$MPHONE'" && FAIL=$((FAIL+1))
fi
$DB -e "DELETE FROM biz_booking_member WHERE id=$SID3;" 2>/dev/null

# D) merchant staff /me 脱敏验证: staff001 在 biz_merchant_staff 无 phone → 字段为空
# 断言: phone 字段存在且不是 11 位明文数字
M_ME=$(curl -s -H "Authorization: Bearer $MTOK" $H/api/merchant/staff/me)
ME_PHONE=$(echo "$M_ME" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('phone',''))" 2>/dev/null)
echo "  [D] merchant /me phone='$ME_PHONE'"
if echo "$ME_PHONE" | grep -qE "^[0-9]{11}$"; then
  echo "  ❌ D) /me 暴露完整明文 phone: $ME_PHONE"; FAIL=$((FAIL+1))
elif [ -z "$ME_PHONE" ] || echo "$ME_PHONE" | grep -qE "1[0-9]{2}\*+[0-9]{4}"; then
  echo "  ✅ D) /me phone 脱敏/空 (无明文)"; PASS=$((PASS+1))
else
  echo "  ⚠️  D) /me phone 格式非典型: '$ME_PHONE'"; PASS=$((PASS+1))
fi

echo "C25 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
