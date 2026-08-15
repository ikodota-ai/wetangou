#!/usr/bin/env bash
# C20 员工工作台 smoke: store staff 登录→工作台→今日数据→预约审核→切换门店
# 验证:
#   A) staff001 登录 → storeId/storeIds (多门店)
#   B) GET /me → 个人信息 userType=store + storeId
#   C) GET /home → 工作台聚合 (verifyCount/verifyAmount/orderCount/pendingBillCount/bookingCount)
#   D) GET /today/orders → 今日订单
#   E) GET /today/bills → 今日买单
#   F) GET /today/bookings → 今日预约
#   G) GET /booking/signup/list → 今日报名人列表
#   H) 切换门店 200→101 (范围内) → 成功 + /me 验证持久化
#   H-) 切换门店 200→999 (范围外) → 拒绝
#   I) POST /logout → 200
#   J) member token 访问 staff 端点 → 拒绝
# 前置: staff001 关联 store 200/101/100; 后端 8080 在跑
set -e
H=http://127.0.0.1:8080
DB="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"
APPID="${APPID:-wx9e147c4e2151b123}"

PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

echo "C20 员工工作台 smoke:"

# A) staff 登录
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"staff001","password":"admin123"}' $H/api/store/staff/login)
STAFF_TOK=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
DEF_SID=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('storeId',0))")
[ ${#STAFF_TOK} -gt 50 ] && [ "$DEF_SID" = "200" ] && echo "  ✅ A) staff001 login (storeId=$DEF_SID)" && PASS=$((PASS+1)) || { echo "  ❌ A) login failed: $LOGIN"; FAIL=$((FAIL+1)); exit 1; }

# B) /me
ME=$(curl -s -H "Authorization: Bearer $STAFF_TOK" $H/api/store/staff/me)
chk "B) GET /me" "userType" "$ME"
echo "$ME" | grep -q '"userType":"store"' && echo "  ✅ B+) me.userType=store" && PASS=$((PASS+1)) || { echo "  ❌ B+) me.userType: ${ME:0:150}"; FAIL=$((FAIL+1)); }
echo "$ME" | grep -q '"storeId":200' && echo "  ✅ B++) me.storeId=200" && PASS=$((PASS+1)) || { echo "  ❌ B++) me.storeId: ${ME:0:150}"; FAIL=$((FAIL+1)); }
echo "$ME" | grep -q '"realName"' && echo "  ✅ B+++) me.realName" && PASS=$((PASS+1)) || { echo "  ❌ B+++) me.realName: ${ME:0:150}"; FAIL=$((FAIL+1)); }

# C) /home 工作台聚合 (5 字段)
HOME=$(curl -s -H "Authorization: Bearer $STAFF_TOK" $H/api/store/staff/home)
chk "C) GET /home" "todayVerifyCount" "$HOME"
for f in todayVerifyCount todayVerifyAmount todayOrderCount pendingBillCount todayBookingCount; do
  echo "$HOME" | grep -q "\"$f\"" && echo "  ✅ C+) home.$f" && PASS=$((PASS+1)) || { echo "  ❌ C+) home.$f: ${HOME:0:200}"; FAIL=$((FAIL+1)); }
done

# D) /today/orders
TODAY_O=$(curl -s -H "Authorization: Bearer $STAFF_TOK" $H/api/store/staff/today/orders)
chk "D) GET /today/orders" "code" "$TODAY_O"

# E) /today/bills
TODAY_B=$(curl -s -H "Authorization: Bearer $STAFF_TOK" $H/api/store/staff/today/bills)
chk "E) GET /today/bills" "code" "$TODAY_B"

# F) /today/bookings
TODAY_BK=$(curl -s -H "Authorization: Bearer $STAFF_TOK" $H/api/store/staff/today/bookings)
chk "F) GET /today/bookings" "code" "$TODAY_BK"

# G) /booking/signup/list
SIGNUP_LIST=$(curl -s -H "Authorization: Bearer $STAFF_TOK" $H/api/store/staff/booking/signup/list)
chk "G) GET /booking/signup/list" "code" "$SIGNUP_LIST"

# H) switch-store 范围内 (200→101)
SW=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STAFF_TOK" \
  -d '{"storeId":101}' $H/api/store/staff/switch-store)
chk "H) switch-store 200→101" "已切换" "$SW"
echo "$SW" | grep -q '"storeId":101' && echo "  ✅ H+) resp.storeId=101" && PASS=$((PASS+1)) || { echo "  ❌ H+) resp: $SW"; FAIL=$((FAIL+1)); }

# 校验: 用同一 token GET /me, storeId 应=101
ME2=$(curl -s -H "Authorization: Bearer $STAFF_TOK" $H/api/store/staff/me)
echo "$ME2" | grep -q '"storeId":101' && echo "  ✅ H++) /me storeId=101 (持久化)" && PASS=$((PASS+1)) || { echo "  ❌ H++) /me after switch: ${ME2:0:200}"; FAIL=$((FAIL+1)); }

# 切回 200 (给后续测试基线)
curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STAFF_TOK" \
  -d '{"storeId":200}' $H/api/store/staff/switch-store > /dev/null

# H-) switch-store 范围外 (200→999)
SW_FAIL=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STAFF_TOK" \
  -d '{"storeId":999}' $H/api/store/staff/switch-store)
chk "H-) switch-store 200→999 拒绝" "无权" "$SW_FAIL"

# I) logout
LOGOUT=$(curl -s -X POST -H "Authorization: Bearer $STAFF_TOK" $H/api/store/staff/logout)
chk "I) POST /logout" "200" "$LOGOUT"

# J) 越权: member token 访问 staff 端点 → 拒绝
JSCODE="c20auth_$(date +%s)_$$"
MEM_LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE\",\"appid\":\"$APPID\",\"nickName\":\"c20auth\"}" $H/api/auth/login)
MEM_TOK=$(echo "$MEM_LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
[ -n "$MEM_TOK" ] || { echo "  ❌ J0) member login failed"; FAIL=$((FAIL+1)); }
ME_FORBID=$(curl -s -H "Authorization: Bearer $MEM_TOK" $H/api/store/staff/me)
echo "$ME_FORBID" | grep -qE "无权|不允许|不是|鉴权|仅限" && echo "  ✅ J) member→/me 拒绝" && PASS=$((PASS+1)) || { echo "  ❌ J) member→/me 应拒绝: ${ME_FORBID:0:200}"; FAIL=$((FAIL+1)); }

echo "C20 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
