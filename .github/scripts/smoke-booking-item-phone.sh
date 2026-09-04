#!/usr/bin/env bash
# 预约项目落库（= BOOKING 商品）+ 会员手机号明文 smoke test
#
# 锁住两件事：
#
# A~E) 预约项目必须是后台上架的 BOOKING 商品，不能是自由文本
#   原先是这样：小程序底部预约 tab 读字典 biz_booking_type 渲染「堂食预约」
#   这种类型卡，create 页把类型名当项目名塞进 serviceName、类型 code 塞进
#   booking_type；而首页「预约服务」tab 读的是
#   /api/product/list?typeCode=BOOKING（真实商品，带价格、能进商品详情）。
#   同一个「预约」入口两套模型，商家上架的预约商品在 tab 里一个都看不到，
#   预约单的 product_id 永远是 NULL —— 后台只能看到「堂食预约」四个字，
#   不知道顾客约的是哪个上架项目。
#   现在统一到商品：POST /api/booking 收 productId，服务端按 productId
#   查商品名写 service_name（前端传的 serviceName 文本一律不采信），
#   booking_type 列彻底不再使用。
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
# I~J) 直接 return 实体的接口也必须明文（@Sensitive 注解链路）
#   前一轮只 grep 了 desensitizer() 调用，漏掉了另一条更隐蔽的路径：
#   SensitiveJsonSerializer.desensitization() 在拿不到 LoginUser 时 return true
#   （匿名一律脱敏），而小程序 /api/** 全是 @Anonymous。于是任何
#   `return AjaxResult.success(实体)` 只要实体字段挂了 @Sensitive(PHONE)
#   就会被 Jackson 脱敏 —— 无需任何手工 desensitizer() 调用。
#   命中的两个：
#     POST /api/auth/info      返 Member 实体，Member.phone 有 @Sensitive
#     GET  /api/booking/{id}   返 Booking 实体，嵌套 BookingMember.phone/storePhone 有 @Sensitive
#   两处都改成手工 Map 拷贝（不动注解：admin 端 biz/booking 列表用同一实体，
#   改注解会让后台展示也变明文，风险大于逐接口拷贝）。
#
# 前置：后端在 8080 运行（druid profile），本地 mysql 可连
# 用法：bash .github/scripts/smoke-booking-item-phone.sh
set -e

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
APPID="${APPID:-wx9e147c4e2151b123}"
MYSQL="${MYSQL_BIN:-/usr/local/mysql/bin/mysql}"
STORE=100
ITEM=1002          # BOOKING 商品「SPA理疗60分钟」（商户 1，与门店 100 同商户）
ITEM2=999534       # 另一个 BOOKING 商品，用来验「不同项目不复用场次」
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
  # E2 段后台建的场次（用后天+5 天那个日期，与 $DT 区分）
  sql "delete from biz_booking where store_id=$STORE and booking_date=date_add(curdate(), interval 5 day) and remark like 'smoke%';"
  sql "delete from biz_booking where store_id=$STORE and booking_date=date_add(curdate(), interval 5 day) and booking_no like 'B%' and booking_id not in (select distinct booking_id from biz_booking_member);"
}
trap cleanup EXIT
cleanup

MTK=$(curl -s -X POST "$BASE_URL/api/auth/login" -H 'Content-Type: application/json' \
  -H "X-App-Id: $APPID" -d "{\"code\":\"smokebt\",\"appid\":\"$APPID\"}" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token") or "")')
[ -n "$MTK" ] || { echo "FAIL: 会员登录拿不到 token（本地需 wx.miniapp.mockEnabled=true）"; exit 1; }
# 登录接口是明文的（对照组），profile 也必须明文
sql "update biz_member set phone='13800009999' where openid='mock_smokebt';"

# A) /api/booking/types 必须已下线：它是「类型即项目」那套旧模型的入口，
#    留着的话前端可能又照它渲染，两套模型再次分叉。
#
#    注意判据不能用 HTTP 404 —— 同类里有 GET /api/booking/{bookingId}，
#    /types 会被它当成 path variable 兜住，于是返的是「参数类型不匹配，
#    参数[bookingId]…输入值为:'types'」。这条报错本身就是「types 端点不存在」
#    的证据：只要 /types 还是个真端点，就不会落到 {bookingId} 上。
TYPES=$(curl -s "$BASE_URL/api/booking/types" -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID")
echo "[A] GET /api/booking/types: $(echo "$TYPES" | head -c 160)"
ck "旧类型端点已下线(落到 {bookingId} 上)" "$(echo "$TYPES" | grep -c "bookingId" || true)" "1"
ck "不再返回类型字典 data"                  "$(echo "$TYPES" | python3 -c 'import sys,json
try: print(1 if isinstance(json.loads(sys.stdin.read() or "{}").get("data"), list) else 0)
except Exception: print(0)')" "0"

# B) 带 productId 报名 → service_name 取商品名，product_id 真落库
ITEM_NAME=$(sql1 "select product_name from biz_product where product_id=$ITEM;")
RESP=$(curl -s -X POST "$BASE_URL/api/booking" -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID" \
  -d "{\"storeId\":$STORE,\"productId\":$ITEM,\"bookingDate\":\"$DT\",\"timeSlot\":\"14:00\",\"contact\":\"smoke\",\"phone\":\"13800009999\",\"people\":2}")
BID=$(echo "$RESP" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("bookingId") or "")')
echo "[B] 带项目报名: $(echo "$RESP" | head -c 160)"
ck "product_id 落库"        "$(sql1 "select product_id from biz_booking where booking_id=$BID;")" "$ITEM"
ck "service_name = 商品名"   "$(sql1 "select service_name from biz_booking where booking_id=$BID;")" "$ITEM_NAME"

# C) 前端传的 serviceName 文本不采信 —— 否则「项目名以商品为准」这条就是空话，
#    随便传个「免费体验」就能覆盖掉真实商品名，后台照样看不出约的是哪个项目
FAKE=$(curl -s -X POST "$BASE_URL/api/booking" -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID" \
  -d "{\"storeId\":$STORE,\"productId\":$ITEM2,\"serviceName\":\"我瞎填的项目名\",\"bookingDate\":\"$DT\",\"timeSlot\":\"16:00\",\"contact\":\"smoke\",\"phone\":\"13800009999\"}")
FBID=$(echo "$FAKE" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("bookingId") or "")')
echo "[C] 伪造 serviceName: bookingId=$FBID"
ck "伪造文本被忽略，仍取商品名" "$(sql1 "select service_name from biz_booking where booking_id=$FBID;")" "$(sql1 "select product_name from biz_product where product_id=$ITEM2;")"

# D) 不存在的商品必须拒（防前端乱传 productId，落个查不到的项目进库）
BAD=$(curl -s -X POST "$BASE_URL/api/booking" -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID" \
  -d "{\"storeId\":$STORE,\"productId\":99999999,\"bookingDate\":\"$DT\",\"timeSlot\":\"15:00\",\"contact\":\"x\",\"phone\":\"13800009999\"}")
echo "[D] 不存在的项目: $(echo "$BAD" | head -c 160)"
ck "非法项目被拒 code" "$(echo "$BAD" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("code"))')" "500"

# E) 同门店同时段、不同项目 → 必须是两个场次。
#    原先复用判断用的是 bookingType（类型），粒度比项目粗 ——
#    同类型的两个不同商品会被并成一个场次，商家分不清谁约的哪个
R2=$(curl -s -X POST "$BASE_URL/api/booking" -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID" \
  -d "{\"storeId\":$STORE,\"productId\":$ITEM2,\"bookingDate\":\"$DT\",\"timeSlot\":\"14:00\",\"contact\":\"smoke\",\"phone\":\"13800009999\",\"people\":1}")
BID2=$(echo "$R2" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("bookingId") or "")')
echo "[E] 同时段换项目: bookingId=$BID2（前一个 $BID）"
ck "不同项目不复用场次"   "$([ -n "$BID2" ] && [ "$BID2" != "$BID" ] && echo yes || echo no)" "yes"
ck "第二个场次项目正确"   "$(sql1 "select product_id from biz_booking where booking_id=$BID2;")" "$ITEM2"

# E2) 后台 admin 端新增场次也必须派生项目名。
#     项目名派生一开始只做在小程序侧（ApiBookingController），后台
#     BookingController.add 走的是另一条路 —— 实测后台建出来的场次
#     service_name 是空字符串，列表「预约项目」那一列什么都不显示。
#     所以派生逻辑下沉到了 BookingServiceImpl.insertBooking/updateBooking。
ATK=$(curl -s -X POST "$BASE_URL/login" -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token") or "")')
if [ -n "$ATK" ]; then
  DT2=$(python3 -c "import datetime;print((datetime.date.today()+datetime.timedelta(days=5)).isoformat())")
  curl -s -o /dev/null -X POST "$BASE_URL/biz/booking" -H "Authorization: Bearer $ATK" \
    -H 'Content-Type: application/json' \
    -d "{\"merchantId\":1,\"storeId\":$STORE,\"productId\":$ITEM,\"bookingDate\":\"$DT2\",\"timeSlot\":\"14:00\",\"status\":\"0\"}"
  ABID=$(sql1 "select booking_id from biz_booking where store_id=$STORE and booking_date='$DT2' and product_id=$ITEM order by booking_id desc limit 1;")
  echo "[E2] 后台新增场次 bookingId=$ABID（只传 productId，没传 serviceName）"
  ck "后台建的场次也有项目名" "$(sql1 "select service_name from biz_booking where booking_id=$ABID;")" "$ITEM_NAME"

  # 编辑换项目 → 项目名必须跟着换，否则库里留下 product_id 指 A、service_name 写 B 的错位数据
  curl -s -o /dev/null -X PUT "$BASE_URL/biz/booking" -H "Authorization: Bearer $ATK" \
    -H 'Content-Type: application/json' \
    -d "{\"bookingId\":$ABID,\"productId\":$ITEM2}"
  ck "编辑换项目后项目名同步" "$(sql1 "select service_name from biz_booking where booking_id=$ABID;")" "$(sql1 "select product_name from biz_product where product_id=$ITEM2;")"

  # 局部更新（只改备注，不传 productId）不该把项目名冲掉
  curl -s -o /dev/null -X PUT "$BASE_URL/biz/booking" -H "Authorization: Bearer $ATK" \
    -H 'Content-Type: application/json' \
    -d "{\"bookingId\":$ABID,\"remark\":\"smoke 局部更新\"}"
  ck "局部更新不冲掉项目名" "$(sql1 "select service_name from biz_booking where booking_id=$ABID;")" "$(sql1 "select product_name from biz_product where product_id=$ITEM2;")"
  sql "delete from biz_booking where booking_id=$ABID;"
else
  echo "[E2] SKIP: admin 登录失败，跳过后台端断言"
fi

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

# I) POST /api/auth/info 直接返 Member 实体 —— @Sensitive 注解会脱敏
INFO=$(curl -s -X POST "$BASE_URL/api/auth/info" -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID")
I_PH=$(echo "$INFO" | python3 -c 'import sys,json;print((json.load(sys.stdin).get("data") or {}).get("phone") or "")')
echo "[I] /api/auth/info phone = $I_PH"
ck "auth/info phone 明文"     "$(echo "$I_PH" | grep -c '\*' || true)" "0"
ck "auth/info phone 与库一致" "$I_PH" "13800009999"

# J) GET /api/booking/{bookingId} 返 Booking 实体，嵌套 bookingMembers 会被脱敏
BDET=$(curl -s "$BASE_URL/api/booking/$BID2" -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID")
J_PH=$(echo "$BDET" | python3 -c '
import sys,json
d=json.load(sys.stdin).get("data") or {}
ms=d.get("bookingMembers") or []
print((ms[0] if ms else {}).get("phone") or "")
')
J_SPH=$(echo "$BDET" | python3 -c '
import sys,json
d=json.load(sys.stdin).get("data") or {}
ms=d.get("bookingMembers") or []
print((ms[0] if ms else {}).get("storePhone") or "")
')
J_ITEM=$(echo "$BDET" | python3 -c 'import sys,json;print((json.load(sys.stdin).get("data") or {}).get("serviceName") or "")')
J_PID=$(echo "$BDET" | python3 -c 'import sys,json;print((json.load(sys.stdin).get("data") or {}).get("productId") or "")')
echo "[J] /api/booking/$BID2 嵌套 phone=$J_PH storePhone=$J_SPH 项目=$J_ITEM($J_PID)"
ck "场次详情嵌套 phone 明文"      "$(echo "$J_PH"  | grep -c '\*' || true)" "0"
ck "场次详情嵌套 phone 与库一致"  "$J_PH" "13800009999"
ck "场次详情嵌套 storePhone 明文" "$(echo "$J_SPH" | grep -c '\*' || true)" "0"
# 手工转 Map 后字段不能漏：前端要靠 serviceName / productId 显示约的是哪个项目。
# bookingType 已从 VO 和实体一并移除，这里顺带证明它不再出现在响应里
ck "场次详情返项目名"         "$J_ITEM" "$(sql1 "select product_name from biz_product where product_id=$ITEM2;")"
ck "场次详情返 productId"     "$J_PID" "$ITEM2"
ck "响应不再含 bookingType"   "$(echo "$BDET" | grep -c bookingType || true)" "0"

echo
if [ "$FAIL" = "0" ]; then
  echo "booking item + member phone smoke PASSED"
else
  echo "booking item + member phone smoke FAILED"; exit 1
fi
