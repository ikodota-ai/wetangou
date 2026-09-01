#!/usr/bin/env bash
# 预约类型字典化 + 会员手机号明文 smoke test
#
# 锁住两件事：
#
# A~D) 预约类型必须来自后台字典（sys_dict_data / biz_booking_type）
#   小程序预约首页原先写死一张「堂食预约」卡，create 页提交时也写死
#   serviceName='堂食预约'。后台在字典里加了「到店消费」「其他预约」，
#   顾客端既看不到、也存不进去 —— 配置项没有出口。
#   新增 GET /api/booking/types 把字典开放给小程序；POST /api/booking
#   收 bookingType 并落 biz_booking.booking_type（这列早就有，一直没人写）。
#
# E~F) /api/member/profile 的 phone 必须是明文
#   这个接口手工拷贝字段的目的就是绕开 @Sensitive，结果代码里又手动调了
#   一次 desensitizer()，等于白绕（注释写的是「需要看到明文」，做的是脱敏）。
#   它会污染下游：app.js bootUser 和下单页 _refreshUserContact 都拿这个
#   返回值 Object.assign 进 globalData.user，把登录接口给的明文覆盖成
#   138****1234；下单/买单/预约提交带过去的就是含星号的号码。
#
# G~H) 预约列表/详情的 phone 与 storePhone 也必须是明文
#   同一个错误在 ApiBookingController 里有三处：注释写「自己看自己 → phone
#   明文」，做的却是 desensitizer()。storePhone 更严重 —— 门店电话脱敏后
#   前端 wx.makePhoneCall 拨的是 134****3069，根本拨不出去
#   （Store.java 里 phone/servicePhone 特意没加 @Sensitive 就是为了能拨）。
#
# 前置：后端在 8080 运行（druid profile），本地 mysql 可连
# 用法：bash .github/scripts/smoke-booking-type-phone.sh
set -e

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
APPID="${APPID:-wx9e147c4e2151b123}"
MYSQL="${MYSQL_BIN:-/usr/local/mysql/bin/mysql}"
STORE=100
FAIL=0

ck() { # ck <描述> <实际> <期望>
  if [ "$2" = "$3" ]; then echo "  OK: $1 ($2)"; else echo "  FAIL: $1 期望 $3 实际 $2"; FAIL=1; fi
}

# 必须显式指定 utf8mb4：不加的话读出来的中文是 ????（本机 mysql client
# 默认字符集不是 utf8mb4），会让「service_name 落库」这类断言假失败
sql()  { "$MYSQL" -h127.0.0.1 -uroot -p133301 --default-character-set=utf8mb4 ry-vue -e "$1" 2>/dev/null || true; }
sql1() { "$MYSQL" -h127.0.0.1 -uroot -p133301 --default-character-set=utf8mb4 -N -B -e "use \`ry-vue\`; $1" 2>/dev/null || true; }

# 用后天，避开「当天只能约当前时刻之后的时段」的限制
DT=$(python3 -c "import datetime;print((datetime.date.today()+datetime.timedelta(days=3)).isoformat())")

cleanup() {
  sql "delete from biz_booking_member where booking_id in (select booking_id from biz_booking where booking_date='$DT' and store_id=$STORE);"
  sql "delete from biz_booking where booking_date='$DT' and store_id=$STORE;"
  sql "delete from biz_member where openid='mock_smokebt';"
  # 停用过的字典项还原
  sql "update sys_dict_data set status='0' where dict_type='biz_booking_type' and dict_value='other';"
}
trap cleanup EXIT
cleanup

MTK=$(curl -s -X POST "$BASE_URL/api/auth/login" -H 'Content-Type: application/json' \
  -H "X-App-Id: $APPID" -d "{\"code\":\"smokebt\",\"appid\":\"$APPID\"}" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token") or "")')
[ -n "$MTK" ] || { echo "FAIL: 会员登录拿不到 token（本地需 wx.miniapp.mockEnabled=true）"; exit 1; }
# 登录接口是明文的（对照组），profile 也必须明文
sql "update biz_member set phone='13800009999' where openid='mock_smokebt';"

# A) 类型列表来自字典，不是写死的
TYPES=$(curl -s "$BASE_URL/api/booking/types" -H "X-App-Id: $APPID")
echo "[A] GET /api/booking/types: $(echo "$TYPES" | head -c 220)"
DICT_N=$(sql1 "select count(*) from sys_dict_data where dict_type='biz_booking_type' and status='0';")
API_N=$(echo "$TYPES" | python3 -c 'import sys,json;print(len(json.load(sys.stdin).get("data") or []))')
ck "接口条数与字典启用条数一致" "$API_N" "$DICT_N"
ck "返回的 code 是字典 value" "$(echo "$TYPES" | python3 -c 'import sys,json;print((json.load(sys.stdin).get("data") or [{}])[0].get("code"))')" "$(sql1 "select dict_value from sys_dict_data where dict_type='biz_booking_type' and status='0' order by dict_sort limit 1;")"

# B) 停用的字典项不能出现在顾客端
sql "update sys_dict_data set status='1' where dict_type='biz_booking_type' and dict_value='other';"
HIDDEN=$(curl -s "$BASE_URL/api/booking/types" -H "X-App-Id: $APPID" \
  | python3 -c 'import sys,json;print(",".join([t["code"] for t in (json.load(sys.stdin).get("data") or [])]))')
echo "[B] 停用 other 后: $HIDDEN"
ck "停用的类型不返回" "$(echo "$HIDDEN" | grep -c other || true)" "0"
sql "update sys_dict_data set status='0' where dict_type='biz_booking_type' and dict_value='other';"

# C) 带 bookingType 报名 → 真落 booking_type 列
RESP=$(curl -s -X POST "$BASE_URL/api/booking" -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID" \
  -d "{\"storeId\":$STORE,\"bookingType\":\"in_store\",\"serviceName\":\"到店消费\",\"bookingDate\":\"$DT\",\"timeSlot\":\"14:00\",\"contact\":\"smoke\",\"phone\":\"13800009999\",\"people\":2}")
BID=$(echo "$RESP" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("bookingId") or "")')
echo "[C] 带类型报名: $(echo "$RESP" | head -c 160)"
ck "booking_type 落库"  "$(sql1 "select booking_type from biz_booking where booking_id=$BID;")" "in_store"
ck "service_name 落库"  "$(sql1 "select service_name from biz_booking where booking_id=$BID;")" "到店消费"

# D) 字典里没有的类型必须拒（防前端乱传，否则后台按类型筛选会对不上）
BAD=$(curl -s -X POST "$BASE_URL/api/booking" -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID" \
  -d "{\"storeId\":$STORE,\"bookingType\":\"NOT_EXIST\",\"bookingDate\":\"$DT\",\"timeSlot\":\"15:00\",\"contact\":\"x\",\"phone\":\"13800009999\"}")
echo "[D] 非法类型: $(echo "$BAD" | head -c 160)"
ck "非法类型被拒 code" "$(echo "$BAD" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("code"))')" "500"

# E) 同门店同时段、不同类型 → 必须是两个场次，不能被并进先建的那个类型
R2=$(curl -s -X POST "$BASE_URL/api/booking" -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID" \
  -d "{\"storeId\":$STORE,\"bookingType\":\"dine_in\",\"serviceName\":\"堂食预约\",\"bookingDate\":\"$DT\",\"timeSlot\":\"14:00\",\"contact\":\"smoke\",\"phone\":\"13800009999\",\"people\":1}")
BID2=$(echo "$R2" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("bookingId") or "")')
echo "[E] 同时段换类型: bookingId=$BID2（前一个 $BID）"
ck "不同类型不复用场次" "$([ -n "$BID2" ] && [ "$BID2" != "$BID" ] && echo yes || echo no)" "yes"
ck "第二个场次类型正确" "$(sql1 "select booking_type from biz_booking where booking_id=$BID2;")" "dine_in"

# F) profile 手机号明文（会员看自己的号码，不该脱敏）
PH=$(curl -s "$BASE_URL/api/member/profile" -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID" \
  | python3 -c 'import sys,json;print((json.load(sys.stdin).get("data") or {}).get("phone") or "")')
echo "[F] /api/member/profile phone = $PH"
ck "phone 与库里一致"   "$PH" "13800009999"
ck "phone 不含星号"     "$(echo "$PH" | grep -c '\*' || true)" "0"

# G) 预约详情：本人报名的联系电话 + 门店电话都要明文
SID=$(echo "$R2" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("signupId") or "")')
DETAIL=$(curl -s "$BASE_URL/api/booking/signup/$SID" -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID")
D_PH=$(echo "$DETAIL"  | python3 -c 'import sys,json;print((json.load(sys.stdin).get("data") or {}).get("phone") or "")')
D_SPH=$(echo "$DETAIL" | python3 -c 'import sys,json;print((json.load(sys.stdin).get("data") or {}).get("storePhone") or "")')
echo "[G] 预约详情 phone=$D_PH storePhone=$D_SPH"
ck "详情 phone 明文"      "$(echo "$D_PH"  | grep -c '\*' || true)" "0"
ck "详情 storePhone 明文" "$(echo "$D_SPH" | grep -c '\*' || true)" "0"
ck "详情 storePhone 与门店表一致" "$D_SPH" "$(sql1 "select phone from biz_store where store_id=$STORE;")"

# H) 预约列表：同上（列表和详情两处都脱过敏）
LIST=$(curl -s "$BASE_URL/api/booking/list" -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID")
L_SPH=$(echo "$LIST" | python3 -c '
import sys,json
rows=json.load(sys.stdin).get("data") or []
print((rows[0] if rows else {}).get("storePhone") or "")
')
echo "[H] 预约列表 storePhone=$L_SPH"
ck "列表 storePhone 明文" "$(echo "$L_SPH" | grep -c '\*' || true)" "0"

echo
if [ "$FAIL" = "0" ]; then
  echo "booking type + member phone smoke PASSED"
else
  echo "booking type + member phone smoke FAILED"; exit 1
fi
