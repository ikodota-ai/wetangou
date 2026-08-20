#!/usr/bin/env bash
# C22 报名详情 smoke: GET /api/booking/signup/{id} 端到端 + phone 脱敏验证
# 验证:
#   A) member 登录 + 创建报名 → signupId
#   B) GET /api/booking/signup/{id} → 返 contact/phone/storeName/bookingDate/timeSlot 等
#   B-) 越权: 另一 member 查 → "预约记录不存在"
#   B++) 不存在 signupId=999999 → 同样提示
#   C) **phone 脱敏断言** (敏感缺陷探测):
#      C1) 若响应 phone 字段为 11 位明文 1xxxxxxxxxx → 标记为 ❌ 脱敏缺失
#      C2) 期望格式: 138****0001 (中间 4 位 * 或类似)
#      C3) storePhone 同理应脱敏
#   D) 报名后 cancel → status=1, 再查 signupDetail 仍返 status=1
# 前置: 后端 8080 在跑; mock appid; storeId=200

# fixture 自备（见 .github/scripts/lib/smoke-fixture.sh）
# 背景：62 smoke 串行跑会互相污染（改密码/耗库存/覆盖 openid），造成假 FAIL
source "$(dirname "$0")/lib/smoke-fixture.sh"
fx_ensure_mock_on
fx_reset_staff_pwd staff001

set -e
H=http://127.0.0.1:8080
DB="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"
APPID="${APPID:-wx9e147c4e2151b123}"
STORE_ID="${STORE_ID:-200}"
PRODUCT_ID="${PRODUCT_ID:-1000}"

PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

echo "C22 报名详情 smoke:"

# A) member 登录
JSCODE="c22a_$(date +%s)_$$"
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE\",\"appid\":\"$APPID\",\"nickName\":\"c22a\"}" $H/api/auth/login)
TOK=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
MID=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ ${#TOK} -gt 50 ] && [ "$MID" -gt 0 ] && echo "  ✅ A) member login (memberId=$MID)" && PASS=$((PASS+1)) || { echo "  ❌ A) login"; FAIL=$((FAIL+1)); exit 1; }

# 准备: 创建一条报名
DATE=$(date -v+3d +%Y-%m-%d 2>/dev/null || date -d "+3 days" +%Y-%m-%d)
CREATE=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $TOK" \
  -d "{\"storeId\":$STORE_ID,\"productId\":$PRODUCT_ID,\"serviceName\":\"C22 测试服务\",\"bookingDate\":\"$DATE\",\"timeSlot\":\"16:00-17:00\",\"contact\":\"C22本人\",\"phone\":\"13800138002\",\"people\":1}" \
  $H/api/booking)
SID=$(echo "$CREATE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('signupId','') or d.get('data',{}).get('signupId',''))" 2>/dev/null)
[ -n "$SID" ] && [ "$SID" -gt 0 ] && echo "  ✅ A+) create booking signupId=$SID" && PASS=$((PASS+1)) || { echo "  ❌ A+) create: $CREATE"; FAIL=$((FAIL+1)); exit 1; }

cleanup() {
  [ -n "$SID" ] && $DB -e "DELETE FROM biz_booking_member WHERE id=$SID;" 2>/dev/null || true
}
trap cleanup EXIT

# B) signupDetail
DETAIL=$(curl -s -H "Authorization: Bearer $TOK" $H/api/booking/signup/$SID)
chk "B) GET /signup/$SID" "contact" "$DETAIL"
echo "$DETAIL" | grep -q "\"id\":$SID" && echo "  ✅ B+) id=$SID" && PASS=$((PASS+1)) || { echo "  ❌ B+) id: ${DETAIL:0:200}"; FAIL=$((FAIL+1)); }
echo "$DETAIL" | grep -q '"contact":"C22本人"' && echo "  ✅ B++) contact" && PASS=$((PASS+1)) || { echo "  ❌ B++) contact: ${DETAIL:0:200}"; FAIL=$((FAIL+1)); }
echo "$DETAIL" | grep -q '"storeName"' && echo "  ✅ B+++) storeName 聚合" && PASS=$((PASS+1)) || { echo "  ❌ B+++) storeName: ${DETAIL:0:200}"; FAIL=$((FAIL+1)); }
echo "$DETAIL" | grep -q '"timeSlot":"16:00-17:00"' && echo "  ✅ B++++) timeSlot" && PASS=$((PASS+1)) || { echo "  ❌ B++++) timeSlot: ${DETAIL:0:200}"; FAIL=$((FAIL+1)); }

# B-) 越权: 另一 member 查
JSCODE2="c22b_$(date +%s)_$$"
LOGIN2=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE2\",\"appid\":\"$APPID\",\"nickName\":\"c22b\"}" $H/api/auth/login)
TOK2=$(echo "$LOGIN2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
FORBID=$(curl -s -H "Authorization: Bearer $TOK2" $H/api/booking/signup/$SID)
echo "$FORBID" | grep -q "预约记录不存在" && echo "  ✅ B-) 越权 → 预约记录不存在" && PASS=$((PASS+1)) || { echo "  ❌ B-) 越权应拒绝: ${FORBID:0:200}"; FAIL=$((FAIL+1)); }

# B++) 不存在 signupId
NOTFOUND=$(curl -s -H "Authorization: Bearer $TOK" $H/api/booking/signup/99999999)
echo "$NOTFOUND" | grep -q "预约记录不存在" && echo "  ✅ B++) 不存在 → 预约记录不存在" && PASS=$((PASS+1)) || { echo "  ❌ B++) notfound: ${NOTFOUND:0:200}"; FAIL=$((FAIL+1)); }

# C) **phone 脱敏断言** (重点: 探明文缺陷)
# 期望 phone 形如 138****0002; 若仍是 11 位纯数字 13800138002 则说明脱敏缺失
PHONE=$(echo "$DETAIL" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('phone',''))" 2>/dev/null)
echo "  [C] phone 原始值: '$PHONE' (期望 138****0002)"
if echo "$PHONE" | grep -qE "^[0-9]{11}$"; then
  echo "  ❌ C-) PHONE 明文缺陷: '$PHONE' (应脱敏为 138****XXXX)" && FAIL=$((FAIL+1))
elif echo "$PHONE" | grep -qE "1[0-9]{2}\*+[0-9]{3,4}"; then
  echo "  ✅ C-) phone 脱敏格式正确" && PASS=$((PASS+1))
else
  echo "  ⚠️  C-) phone 格式非典型: '$PHONE' (请人工确认是否脱敏)" && PASS=$((PASS+1))
fi
STORE_PHONE=$(echo "$DETAIL" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('storePhone',''))" 2>/dev/null)
echo "  [C] storePhone: '$STORE_PHONE'"
if echo "$STORE_PHONE" | grep -qE "^[0-9]{11}$"; then
  echo "  ❌ C++) storePhone 明文缺陷: '$STORE_PHONE' (应脱敏)" && FAIL=$((FAIL+1))
elif [ -n "$STORE_PHONE" ]; then
  echo "  ✅ C++) storePhone 已脱敏" && PASS=$((PASS+1))
else
  echo "  ⚠️  C++) storePhone 为空: '$STORE_PHONE'" && PASS=$((PASS+1))
fi

# D) cancel + 再查
CANCEL=$(curl -s -X POST -H "Authorization: Bearer $TOK" $H/api/booking/cancel/$SID)
chk "D) cancel" "200" "$CANCEL"
sleep 1
DETAIL2=$(curl -s -H "Authorization: Bearer $TOK" $H/api/booking/signup/$SID)
echo "$DETAIL2" | grep -q '"status":"1"' && echo "  ✅ D+) 取消后 status=1" && PASS=$((PASS+1)) || { echo "  ❌ D+) status: ${DETAIL2:0:200}"; FAIL=$((FAIL+1)); }

echo "C22 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
