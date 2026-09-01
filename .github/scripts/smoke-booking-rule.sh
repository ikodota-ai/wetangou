#!/usr/bin/env bash
# 门店级预约可约范围（第 6 项）
#
# 背景：用户问「后台的预约服务是不是可以不要、预约日期和预约时间是不是用来
# 限制小程序可选的预约日期和时间的」。答案是「不是」—— biz_booking 每一行是
# 已发生的场次，不是规则。但顺着这个问题查下去发现「可约范围」只做了一半：
# 起止小时跟营业时间走，而「能约未来几天」写死 7、「时段粒度」写死整点、
# 「歇业日」根本没有。运营想限制可选日期只能改营业时间，而营业时间还被
# 首页营业状态用着，一改就互相干扰。
#
# 现在规则放门店级（biz_store.booking_ahead_days / booking_slot_minutes /
# booking_closed_days）。本脚本改真实门店配置，断言接口输出跟着变，跑完复原。
set -u
BASE_URL="${BASE_URL:-http://localhost:8080}"
APPID="${MP_APPID:-wx9e147c4e2151b123}"
SID="${BOOKING_STORE_ID:-100}"
MYSQL="${MYSQL_BIN:-/usr/local/mysql/bin/mysql}"
DB="${MYSQL_DB:-ry-vue}"
MYSQL_ARGS="-uroot -p${MYSQL_PASS:-133301} $DB --default-character-set=utf8mb4 -N -B"

PASSN=0; FAILN=0
ok(){ echo "  ✅ $1"; PASSN=$((PASSN+1)); }
ng(){ echo "  ❌ $1"; FAILN=$((FAILN+1)); }
q(){ $MYSQL $MYSQL_ARGS -e "$1" 2>/dev/null | grep -v Warning; }

# 原值备份，trap 保证异常退出也复原（不复原会污染 smoke-home-hardcode 的断言）
ORIG=$(q "select concat_ws('|', ifnull(booking_ahead_days,'NULL'), ifnull(booking_slot_minutes,'NULL'), ifnull(booking_closed_days,''), ifnull(business_hours,'')) from biz_store where store_id=$SID;")
[ -n "$ORIG" ] || { echo "FAIL: 门店 $SID 不存在或库连不上"; exit 1; }
O_AHEAD=$(echo "$ORIG" | cut -d'|' -f1)
O_SLOT=$(echo "$ORIG"  | cut -d'|' -f2)
O_CLOSED=$(echo "$ORIG"| cut -d'|' -f3)
O_HOURS=$(echo "$ORIG" | cut -d'|' -f4)
restore(){
  q "update biz_store set
       booking_ahead_days=$( [ "$O_AHEAD" = NULL ] && echo NULL || echo "$O_AHEAD" ),
       booking_slot_minutes=$( [ "$O_SLOT" = NULL ] && echo NULL || echo "$O_SLOT" ),
       booking_closed_days=$( [ -z "$O_CLOSED" ] && echo NULL || echo "'$O_CLOSED'" ),
       business_hours='$O_HOURS'
     where store_id=$SID;"
}
trap restore EXIT

GET(){ curl -s -m 10 -H "X-App-Id: $APPID" "$BASE_URL$1"; }
PY(){ python3 -c "$1" 2>/dev/null; }

echo "== A) 可提前预约天数生效（原先小程序写死 7 天）=="
q "update biz_store set booking_ahead_days=3, booking_closed_days=null, business_hours='10:00-22:00' where store_id=$SID;"
N=$(GET "/api/booking/days?storeId=$SID" | PY "
import sys,json;d=json.load(sys.stdin).get('data') or {}
print(len(d.get('days') or []), d.get('aheadDays'))")
if [ "$N" = "3 3" ]; then ok "填 3 天 → 返 3 天 (aheadDays=3)"; else ng "填 3 天 → 实得 '$N'"; fi

q "update biz_store set booking_ahead_days=14 where store_id=$SID;"
N=$(GET "/api/booking/days?storeId=$SID" | PY "
import sys,json;print(len((json.load(sys.stdin).get('data') or {}).get('days') or []))")
if [ "$N" = "14" ]; then ok "改 14 天 → 返 14 天（证明不是写死 7）"; else ng "改 14 天 → 实得 $N"; fi

echo "== B) 非法值兜底为 7，不能让预约页崩 =="
q "update biz_store set booking_ahead_days=0 where store_id=$SID;"
N=$(GET "/api/booking/days?storeId=$SID" | PY "
import sys,json;print(len((json.load(sys.stdin).get('data') or {}).get('days') or []))")
if [ "$N" = "7" ]; then ok "填 0 → 兜底 7 天"; else ng "填 0 → 实得 $N"; fi
q "update biz_store set booking_ahead_days=999 where store_id=$SID;"
N=$(GET "/api/booking/days?storeId=$SID" | PY "
import sys,json;print(len((json.load(sys.stdin).get('data') or {}).get('days') or []))")
if [ "$N" = "60" ]; then ok "填 999 → 夹到上限 60"; else ng "填 999 → 实得 $N"; fi

echo "== C) 歇业日标 closed 且不可约 =="
# 取今天+1 的 ISO 星期设为歇业，保证一定命中日期条里的某一天
ISO=$(q "select case dayofweek(date_add(curdate(), interval 1 day)) when 1 then 7 else dayofweek(date_add(curdate(), interval 1 day))-1 end;")
q "update biz_store set booking_ahead_days=7, booking_closed_days='$ISO' where store_id=$SID;"
R=$(GET "/api/booking/days?storeId=$SID" | PY "
import sys,json;d=json.load(sys.stdin).get('data') or {}
rows=d.get('days') or []
cl=[x for x in rows if x.get('closed')]
print(len(cl), (cl[0].get('closedReason') if cl else ''), d.get('openCount'), len(rows))")
CN=$(echo "$R" | awk '{print $1}')
if [ "${CN:-0}" -ge 1 ]; then ok "歇业日被标 closed（$R）"; else ng "歇业日未标 closed（$R）"; fi

# 该歇业日拉时段，必须 closedDay=true 且没有一个 available
CDATE=$(GET "/api/booking/days?storeId=$SID" | PY "
import sys,json
rows=(json.load(sys.stdin).get('data') or {}).get('days') or []
print(next((x['date'] for x in rows if x.get('closed')),''))")
if [ -n "$CDATE" ]; then
  R2=$(GET "/api/booking/slots?storeId=$SID&date=$CDATE" | PY "
import sys,json;d=json.load(sys.stdin).get('data') or {}
sl=(d.get('day') or [])+(d.get('night') or [])
print(d.get('closedDay'), len([x for x in sl if x.get('available')]), len(sl), repr(d.get('closedReason')))")
  CD=$(echo "$R2" | awk '{print $1}'); AV=$(echo "$R2" | awk '{print $2}'); TOT=$(echo "$R2" | awk '{print $3}')
  if [ "$CD" = "True" ] && [ "$AV" = "0" ]; then ok "歇业日 slots: closedDay=true 且 0 个可约（$R2）"; else ng "歇业日 slots 异常（$R2）"; fi
  # 时段仍要列出来（空数组前端只能显示「暂无时段」，用户不知道是歇业）
  if [ "${TOT:-0}" -gt 0 ]; then ok "歇业日仍列出 $TOT 个时段并标 closed"; else ng "歇业日返回空时段列表"; fi
else
  ng "没找到被标 closed 的日期，无法验 slots"
fi

echo "== D) 时段粒度生效（原先固定整点）=="
q "update biz_store set booking_closed_days=null, booking_slot_minutes=30, business_hours='10:00-12:00' where store_id=$SID;"
TOMO=$(q "select date_format(date_add(curdate(), interval 1 day), '%Y-%m-%d');")
R3=$(GET "/api/booking/slots?storeId=$SID&date=$TOMO" | PY "
import sys,json;d=json.load(sys.stdin).get('data') or {}
sl=(d.get('day') or [])+(d.get('night') or [])
print(d.get('slotMinutes'), len(sl), ','.join(x['time'] for x in sl))")
if echo "$R3" | grep -q "10:00,10:30,11:00,11:30"; then ok "粒度 30 → $R3"; else ng "粒度 30 未生效（$R3）"; fi

q "update biz_store set booking_slot_minutes=60 where store_id=$SID;"
R4=$(GET "/api/booking/slots?storeId=$SID&date=$TOMO" | PY "
import sys,json;d=json.load(sys.stdin).get('data') or {}
sl=(d.get('day') or [])+(d.get('night') or [])
print(d.get('slotMinutes'), ','.join(x['time'] for x in sl))")
if echo "$R4" | grep -q "^60 10:00,11:00$"; then ok "粒度 60 → 整点（$R4）"; else ng "粒度 60 异常（$R4）"; fi

echo "== E) 非法粒度兜底 60，不能死循环 =="
q "update biz_store set booking_slot_minutes=0 where store_id=$SID;"
R5=$(GET "/api/booking/slots?storeId=$SID&date=$TOMO" | PY "
import sys,json;d=json.load(sys.stdin).get('data') or {}
print(d.get('slotMinutes'), len((d.get('day') or [])+(d.get('night') or [])))")
if [ "$R5" = "60 2" ]; then ok "粒度 0 → 兜底 60（若死循环这里会超时）"; else ng "粒度 0 兜底异常（$R5）"; fi

echo "== F) 超出可约范围的日期不可约（防改参数约到范围外）=="
q "update biz_store set booking_ahead_days=2, booking_slot_minutes=60, business_hours='10:00-22:00' where store_id=$SID;"
FAR=$(q "select date_format(date_add(curdate(), interval 30 day), '%Y-%m-%d');")
R6=$(GET "/api/booking/slots?storeId=$SID&date=$FAR" | PY "
import sys,json;d=json.load(sys.stdin).get('data') or {}
sl=(d.get('day') or [])+(d.get('night') or [])
print(d.get('outOfRange'), len([x for x in sl if x.get('available')]), repr(d.get('closedReason')))")
if echo "$R6" | grep -q "^True 0 "; then ok "30 天后（超出 2 天范围）→ outOfRange 且 0 可约（$R6）"; else ng "越界日期未拦（$R6）"; fi
PAST=$(q "select date_format(date_sub(curdate(), interval 1 day), '%Y-%m-%d');")
R7=$(GET "/api/booking/slots?storeId=$SID&date=$PAST" | PY "
import sys,json;d=json.load(sys.stdin).get('data') or {}
sl=(d.get('day') or [])+(d.get('night') or [])
print(d.get('outOfRange'), len([x for x in sl if x.get('available')]))")
if echo "$R7" | grep -q "^True 0$"; then ok "昨天 → outOfRange 且 0 可约（$R7）"; else ng "过去日期未拦（$R7）"; fi

echo "== G) 小程序不再写死 7 天 =="
if grep -q "bookingDays" miniprogram7/utils/request.js && grep -q "loadDays" miniprogram7/pages/booking/create/index.js; then
  ok "小程序改为调 /api/booking/days"
else
  ng "小程序仍未接可约日期接口"
fi
# 只看真实渲染出去的文本，排除 wxml 注释 —— 注释里会提到旧文案（说明为什么改），
# 直接 grep 会把自己的注释当成未修复
if grep -v "<!--" miniprogram7/pages/booking/create/index.wxml \
   | grep -q "本店全周午晚市开放预约"; then
  ng "预约说明仍写死「全周开放」，与歇业日矛盾"
else
  ok "预约说明不再写死「全周开放」"
fi
# 正面断言：说明文案要真的用上后端返回的可约天数
if grep -q "本店可提前 {{aheadDays}} 天预约" miniprogram7/pages/booking/create/index.wxml; then
  ok "预约说明按 aheadDays 动态渲染"
else
  ng "预约说明没用上 aheadDays"
fi

echo "结果: PASS=$PASSN FAIL=$FAILN"
[ "$FAILN" -eq 0 ] || exit 1
