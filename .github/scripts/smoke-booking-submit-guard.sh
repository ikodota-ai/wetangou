#!/usr/bin/env bash
# 预约提交越权护栏 + 三处券入口一致性 smoke
#
# 为什么有这个脚本（两个真实缺陷，都能复现）：
#
# 1) 【后端全放行】门店的可约范围（booking_ahead_days / booking_slot_minutes /
#    booking_closed_days）只在小程序端生效：日期条置灰、时段标 closed。
#    直接 POST /api/booking 绕过界面时，后端一行校验都没有 ——
#    歇业日、超出可提前天数的日期、已过去的日期、营业时间外的 03:00、
#    甚至 timeSlot="随便填" 全部返 200 落库，商家会收到根本没法接待的单。
#    而 BookingServiceImpl.selectBookableDays 的注释里写着
#    「顾客照样能选到周一，提交后才被拒」—— 实际从来没被拒过。
#
# 2) 【券入口漏一处】券入口原先只有下单页；上一轮补了订单详情页。
#    但下单页提交成功后是 wx.redirectTo 到支付中间页 pages/order-pay，
#    用户退不回下单页、本页又没有券入口 —— 到店自取先下单、到店才付，
#    在店里想起有券时这一步依然用不上。三处必须都有入口。
#
# 验证：
#   A) 歇业日被拒          B) 超出可提前天数被拒
#   C) 非营业时间时段被拒  D) 已过去的日期被拒
#   E) 非法时段串被拒      F) 不对齐粒度的时段被拒
#   G) 合法日期+时段仍能成功（不能把正常预约也拦死）
#   H) 无 token → 401
#   I) 三处券入口（submit / detail / order-pay）源码层都在
#   J) order-pay 换券后必须清预支付缓存（否则微信按旧金额扣款）
#
# 前置：后端在 8080 运行（druid profile），本地 mysql 可连
# 用法：bash .github/scripts/smoke-booking-submit-guard.sh
set -u

cd "$(dirname "$0")/../.." || exit 1
BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
APPID="${APPID:-wx9e147c4e2151b123}"
MYSQL="${MYSQL_BIN:-/usr/local/mysql/bin/mysql}"
MP=miniprogram7
STORE=100
PASS=0; FAIL=0

ck()  { if [ "$2" = "$3" ]; then echo "  ✅ $1 ($2)"; PASS=$((PASS+1)); else echo "  ❌ $1 期望 $3 实际 $2"; FAIL=$((FAIL+1)); fi }
ckf() { if grep -q -- "$3" "$2" 2>/dev/null; then echo "  ✅ $1"; PASS=$((PASS+1)); else echo "  ❌ $1 (未在 $2 找到: $3)"; FAIL=$((FAIL+1)); fi }

sql()  { "$MYSQL" -h127.0.0.1 -uroot -p133301 ry-vue -e "$1" 2>/dev/null || true; }
sql1() { "$MYSQL" -h127.0.0.1 -uroot -p133301 -N -B -e "use \`ry-vue\`; $1" 2>/dev/null || true; }
jcode(){ python3 -c 'import sys,json;print(json.load(sys.stdin).get("code"))'; }
jget() { python3 -c "
import sys,json
d=json.load(sys.stdin); b=d.get('data') or d
v=b
for k in '$1'.split('.'):
    v=(v or {}).get(k)
print('' if v is None else v)
"; }

# 门店原配置要还原，否则会污染 smoke-booking-rule 等脚本
ORIG=$(sql1 "select concat_ws('|', ifnull(booking_ahead_days,'NULL'), ifnull(booking_slot_minutes,'NULL'), ifnull(booking_closed_days,'NULL')) from biz_store where store_id=$STORE;")
cleanup() {
  sql "delete from biz_booking_member where member_id in (select member_id from biz_member where openid='mock_smokebg');"
  sql "delete from biz_booking where booking_no like 'B%' and store_id=$STORE and booking_date >= curdate() and booking_id not in (select booking_id from biz_booking_member);"
  sql "delete from biz_member where openid='mock_smokebg';"
  local a="${ORIG%%|*}" r="${ORIG#*|}"; local s="${r%%|*}" c="${r##*|}"
  [ "$a" = "NULL" ] && a="NULL"; [ "$s" = "NULL" ] && s="NULL"
  if [ "$c" = "NULL" ]; then c="NULL"; else c="'$c'"; fi
  sql "update biz_store set booking_ahead_days=$a, booking_slot_minutes=$s, booking_closed_days=$c where store_id=$STORE;"
}
trap cleanup EXIT
cleanup

echo "== 预约提交越权护栏 + 券入口一致性 =="
echo "[0] 门店 $STORE 原配置 ahead|slot|closed = $ORIG"

# 造一组明确的规则：可提前 14 天 / 30 分钟一档 / 周二周四歇业
sql "update biz_store set booking_ahead_days=14, booking_slot_minutes=30, booking_closed_days='2,4', business_hours='10:00-22:00' where store_id=$STORE;"

TK=$(curl -s -X POST "$BASE_URL/api/auth/login" -H 'Content-Type: application/json' \
  -H "X-App-Id: $APPID" -d "{\"code\":\"smokebg\",\"appid\":\"$APPID\"}" | jget token)
[ -n "$TK" ] || { echo "  ❌ 会员登录拿不到 token（本地需 wx.miniapp.mockEnabled=true）"; exit 1; }

book() { # book <date> <timeSlot> [token]
  local tk="${3:-$TK}"
  curl -s -X POST "$BASE_URL/api/booking" -H 'Content-Type: application/json' \
    -H "X-App-Id: $APPID" -H "Authorization: Bearer $tk" \
    -d "{\"storeId\":$STORE,\"bookingDate\":\"$1\",\"timeSlot\":\"$2\",\"bookingType\":\"dine_in\",\"contact\":\"smoke\",\"phone\":\"13800000000\",\"people\":1}"
}

# 取「今天之后第一个周四」= 歇业日；以及一个营业日
CLOSED=$(python3 -c "
import datetime
d=datetime.date.today()+datetime.timedelta(days=1)
while d.isoweekday()!=4: d+=datetime.timedelta(days=1)
print(d.isoformat())")
OPEN=$(python3 -c "
import datetime
d=datetime.date.today()+datetime.timedelta(days=1)
while d.isoweekday() in (2,4): d+=datetime.timedelta(days=1)
print(d.isoformat())")
OVER=$(python3 -c "
import datetime
print((datetime.date.today()+datetime.timedelta(days=30)).isoformat())")
PAST=$(python3 -c "
import datetime
print((datetime.date.today()-datetime.timedelta(days=30)).isoformat())")
echo "[1] 歇业日=$CLOSED 营业日=$OPEN 超范围=$OVER 已过去=$PAST"

ck "A) 歇业日(周四)被拒"        "$(book "$CLOSED" 10:00 | jcode)" "500"
ck "B) 超出可提前 14 天被拒"    "$(book "$OVER"  10:00 | jcode)" "500"
ck "C) 营业时间外 03:00 被拒"   "$(book "$OPEN"  03:00 | jcode)" "500"
ck "D) 已过去的日期被拒"        "$(book "$PAST"  10:00 | jcode)" "500"
ck "E) 非法时段串被拒"          "$(book "$OPEN"  "随便填" | jcode)" "500"
ck "F) 不对齐 30 分钟粒度被拒"  "$(book "$OPEN"  10:15 | jcode)" "500"

# G) 正常预约必须仍能成功 —— 校验不能收得太紧把业务拦死
ROK=$(book "$OPEN" 10:30)
ck "G) 合法日期+对齐时段成功"   "$(echo "$ROK" | jcode)" "200"
BID=$(echo "$ROK" | jget bookingId)
ck "G2) 场次真落库"             "$(sql1 "select count(1) from biz_booking where booking_id='${BID:-0}';")" "1"

# 越权提交一条都不许落库
ck "G3) 被拒的 6 次都没落库"    "$(sql1 "select count(1) from biz_booking where store_id=$STORE and booking_date in ('$CLOSED','$OVER','$PAST');")" "0"

ck "H) 无 token → 401" "$(curl -s -X POST "$BASE_URL/api/booking" -H 'Content-Type: application/json' \
  -H "X-App-Id: $APPID" -d "{\"storeId\":$STORE,\"bookingDate\":\"$OPEN\",\"timeSlot\":\"10:30\"}" | jcode)" "401"

echo "[2] 券入口三处一致性（源码层）"
ckf "I1) 下单页有选券入口"        "$MP/pages/order/submit/index.wxml"  "openVoucher"
ckf "I2) 订单详情页有选券入口"    "$MP/pages/order/detail/index.wxml"  "openVoucher"
ckf "I3) 支付中间页有选券入口"    "$MP/pages/order-pay/index.wxml"     "openVoucher"
ckf "I4) 支付中间页接了换券接口"  "$MP/pages/order-pay/index.js"       "orderChangeVoucher"
# 券可用性必须按商品总价判：用实付金额判会把「满100减20」在减完后判成不可用
ckf "I5) 支付中间页按订单总价判门槛" "$MP/pages/order-pay/index.js"    "totalAmount"
# 换券后端会重发 order_no，前端必须丢掉旧 paySign 重新 prepay
ckf "J1) 换券后清空预支付缓存"    "$MP/pages/order-pay/index.js"       "_prepayRes: null"
ckf "J2) 换券后重新 prepay"       "$MP/pages/order-pay/index.js"       "this.loadPayInfo()"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
