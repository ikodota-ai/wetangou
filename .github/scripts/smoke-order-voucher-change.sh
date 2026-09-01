#!/usr/bin/env bash
# 待支付订单换券 + 代金券占用锁 smoke test
#
# 本脚本锁住两件事，都是实测能复现的真实缺陷：
#
# 1) 【P0 资损】一张券能同时占用多个待支付单。
#    member_voucher.status 是支付成功回调里才置 '1' 的，下单只是把
#    member_voucher_id 记到订单上。于是同一张 ¥20 券对 ¥200 商品连下 3 单，
#    三单 discountAmount 都是 20.00 且全部落库；逐单支付后 use_order_id
#    只记住第一单 —— 商家凭空少收 ¥40。买单（biz_pay_bill）走同一套券，
#    两张表要一起算占用，否则「订单占了、买单再占一次」照样漏。
#
# 2) 【功能缺口】券入口原先只有下单页（提交订单之前）那一处。
#    订单一旦建出来进了待支付，用户就没有任何入口再用券 ——
#    「到店自取」恰恰是先下单、到店才付，领了券也用不上。
#    新增 POST /api/order/{id}/voucher 支持选券/换券/取消用券。
#
#    换券必须重发 order_no：order_no 就是微信支付的 out_trade_no，
#    JSAPI 下单后金额已锁在微信侧那笔预支付单上。沿用旧号改金额，
#    微信按首次下单金额扣款，会出现「页面显示 180、实际扣 200」的资损。
#
# 验证：
#   A) 带券下单成功；同券再下单被拒（订单侧占用锁）
#   B) 取消用券 → discount=0 / pay=总价 / member_voucher_id 真置 NULL / order_no 变了
#   C) 重新选上同一张券 → 成功（占用统计必须排除自身订单）
#   D) 连续换券 → order_no 每次都变
#   E) 订单取消(status=3) 不占券 → 该券可被新单使用
#   F) 已支付订单不能改券
#   G) 改他人订单被拒且对方数据未被篡改
#   H) 无 token → 401
#   I) 买单占用后，商品下单用同一张券被拒（跨表占用）
#
# 前置：后端在 8080 运行（druid profile），本地 mysql 可连
# 用法：bash .github/scripts/smoke-order-voucher-change.sh
set -e

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
APPID="${APPID:-wx9e147c4e2151b123}"
MYSQL="${MYSQL_BIN:-/usr/local/mysql/bin/mysql}"
PRODUCT=999829        # ¥200.00，门店 200（商户 1）。金额要大于券门槛 100
STORE=200
FAIL=0
PASS=0

ck() { # ck <描述> <实际> <期望>
  if [ "$2" = "$3" ]; then echo "  OK: $1 ($2)"; PASS=$((PASS+1));
  else echo "  FAIL: $1 期望 $3 实际 $2"; FAIL=$((FAIL+1)); fi
}
ckne() { # ckne <描述> <实际> <不应等于>
  if [ -n "$2" ] && [ "$2" != "$3" ]; then echo "  OK: $1 ($2 != $3)"; PASS=$((PASS+1));
  else echo "  FAIL: $1 期望变化，实际 $2 vs $3"; FAIL=$((FAIL+1)); fi
}

jget() { python3 -c "
import sys,json
d=json.load(sys.stdin); b=d.get('data') or d
v=b
for k in '$1'.split('.'):
    v=(v or {}).get(k)
print('' if v is None else v)
"; }
jcode() { python3 -c 'import sys,json;print(json.load(sys.stdin).get("code"))'; }
jmsg()  { python3 -c 'import sys,json;print(json.load(sys.stdin).get("msg") or "")'; }
# json.load 把 "20.00" 读成 float 20.0，直接比字符串会假失败
jamt() { python3 -c "
import sys,json
from decimal import Decimal
d=json.load(sys.stdin, parse_float=Decimal); b=d.get('data') or d
v=(b or {}).get('$1')
print('' if v is None else '{:.2f}'.format(Decimal(str(v))))
"; }

sql()  { "$MYSQL" -h127.0.0.1 -uroot -p133301 ry-vue -e "$1" 2>/dev/null || true; }
sql1() { "$MYSQL" -h127.0.0.1 -uroot -p133301 -N -B -e "use \`ry-vue\`; $1" 2>/dev/null || true; }

cleanup() {
  sql "delete from biz_order where member_id in (select member_id from biz_member where openid in ('mock_smokecv','mock_smokecv2'));"
  sql "delete from biz_pay_bill where member_id in (select member_id from biz_member where openid in ('mock_smokecv','mock_smokecv2'));"
  sql "delete from biz_member_voucher where member_id in (select member_id from biz_member where openid in ('mock_smokecv','mock_smokecv2'));"
  sql "delete from biz_member where openid in ('mock_smokecv','mock_smokecv2');"
}
trap cleanup EXIT
cleanup   # 上次异常中断可能有残留

# 0) 两个会员：第二个用来造「别人的订单」
MTK=$(curl -s -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' -H "X-App-Id: $APPID" \
  -d "{\"code\":\"smokecv\",\"appid\":\"$APPID\"}" | jget token)
[ -n "$MTK" ] || { echo "FAIL: 会员登录拿不到 token（本地需 wx.miniapp.mockEnabled=true）"; exit 1; }
MTK2=$(curl -s -X POST "$BASE_URL/api/auth/login" -H 'Content-Type: application/json' \
  -H "X-App-Id: $APPID" -d "{\"code\":\"smokecv2\",\"appid\":\"$APPID\"}" | jget token)

MID=$(sql1  "select member_id from biz_member where openid='mock_smokecv';")
MID2=$(sql1 "select member_id from biz_member where openid='mock_smokecv2';")
echo "[0] member=$MID other=$MID2 商品=$PRODUCT(¥200.00) 门店=$STORE"

# voucher_id=0：不引用真实券模板，避免动 biz_voucher 的 received 计数
mkv() { # mkv <memberId> <面值> <门槛> → 券 id
  sql "insert into biz_member_voucher(merchant_id,voucher_id,member_id,face_value,threshold,status,get_time,expire_time)
       values(1,0,$1,$2,$3,'0',now(),date_add(now(), interval 30 day));"
  sql1 "select max(id) from biz_member_voucher where member_id=$1;"
}
order() { # order <memberVoucherId|-> [token]
  local body tk="${2:-$MTK}"
  if [ "$1" = "-" ]; then body="{\"productId\":$PRODUCT,\"num\":1}"
  else body="{\"productId\":$PRODUCT,\"num\":1,\"memberVoucherId\":$1}"; fi
  curl -s -X POST "$BASE_URL/api/order" -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $tk" -H "X-App-Id: $APPID" -d "$body"
}
chg() { # chg <orderId> <memberVoucherId|-> [token]
  local body tk="${3:-$MTK}"
  if [ "$2" = "-" ]; then body='{}'; else body="{\"memberVoucherId\":$2}"; fi
  curl -s -X POST "$BASE_URL/api/order/$1/voucher" -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $tk" -H "X-App-Id: $APPID" -d "$body"
}

# A) 占用锁：一张券只能挂在一个未失效的单上
V=$(mkv $MID 20.00 100.00)
R1=$(order $V)
OID=$(echo "$R1" | jget orderId)
echo "[A] 带券下单(券$V 面值20 门槛100) orderId=$OID"
ck "首单抵扣"   "$(echo "$R1" | jamt discountAmount)" "20.00"
ck "首单实付"   "$(echo "$R1" | jamt payAmount)"      "180.00"
R2=$(order $V)
echo "    同券再下单: $(echo "$R2" | jmsg)"
ck "同券第二单被拒 code" "$(echo "$R2" | jcode)" "500"
ck "第二单未落库"        "$(sql1 "select count(1) from biz_order where member_voucher_id=$V and status in ('0','1','2');")" "1"
NO_A=$(sql1 "select order_no from biz_order where order_id=$OID;")

# B) 取消用券：金额回到总价，券字段真置 NULL，order_no 必须换
RB=$(chg $OID -)
echo "[B] 取消用券: $(echo "$RB" | head -c 120)"
ck "取消后抵扣"     "$(echo "$RB" | jamt discountAmount)" "0.00"
ck "取消后实付"     "$(echo "$RB" | jamt payAmount)"      "200.00"
ck "券字段落库 NULL" "$(sql1 "select ifnull(member_voucher_id,'NULL') from biz_order where order_id=$OID;")" "NULL"
NO_B=$(sql1 "select order_no from biz_order where order_id=$OID;")
ckne "取消用券后 order_no 已换" "$NO_B" "$NO_A"

# C) 重新选上同一张券：占用统计要排除自身订单，否则用户自己把自己挡住
RC=$(chg $OID $V)
echo "[C] 重新选同一张券: $(echo "$RC" | jmsg)"
ck "重新选券 code" "$(echo "$RC" | jcode)"            "200"
ck "重新选券抵扣"  "$(echo "$RC" | jamt discountAmount)" "20.00"
ck "重新选券实付"  "$(echo "$RC" | jamt payAmount)"      "180.00"
ck "券字段已回填"  "$(sql1 "select member_voucher_id from biz_order where order_id=$OID;")" "$V"
NO_C=$(sql1 "select order_no from biz_order where order_id=$OID;")
ckne "重新选券后 order_no 又换" "$NO_C" "$NO_B"

# D) 换成另一张券
V2=$(mkv $MID 50.00 100.00)
RD=$(chg $OID $V2)
echo "[D] 换成 ¥50 券($V2): $(echo "$RD" | jmsg)"
ck "换券后抵扣" "$(echo "$RD" | jamt discountAmount)" "50.00"
ck "换券后实付" "$(echo "$RD" | jamt payAmount)"      "150.00"
NO_D=$(sql1 "select order_no from biz_order where order_id=$OID;")
ckne "换券后 order_no 再换" "$NO_D" "$NO_C"
# 旧券被释放：现在应该能用在别的单上
RD2=$(order $V)
echo "    被换下来的券$V 重新可用: $(echo "$RD2" | jmsg)"
ck "换下的券可用于新单 code" "$(echo "$RD2" | jcode)" "200"
OID_D2=$(echo "$RD2" | jget orderId)

# E) 已取消订单不占券：否则用户取消订单后手里的券就永远废了
sql "update biz_order set status='3' where order_id=$OID_D2;"
RE=$(order $V)
echo "[E] 取消单(status=3)不占券: $(echo "$RE" | jmsg)"
ck "取消单释放券 code" "$(echo "$RE" | jcode)" "200"
OID_E=$(echo "$RE" | jget orderId)

# F) 已支付订单不许改券（金额已进微信）
sql "update biz_order set status='1' where order_id=$OID_E;"
RF=$(chg $OID_E -)
echo "[F] 改已支付订单: $(echo "$RF" | jmsg)"
ck "已支付不许改券 code" "$(echo "$RF" | jcode)" "500"

# G) 越权：改别人的订单，且对方数据不能被动
RG_CREATE=$(order - "$MTK2")
OID_G=$(echo "$RG_CREATE" | jget orderId)
NO_G=$(sql1 "select order_no from biz_order where order_id=$OID_G;")
RG=$(chg $OID_G - "$MTK")
echo "[G] 改他人订单($OID_G 属于$MID2): $(echo "$RG" | jmsg)"
ck "越权改券被拒 code"    "$(echo "$RG" | jcode)" "500"
ck "他人 order_no 未被改" "$(sql1 "select order_no from biz_order where order_id=$OID_G;")" "$NO_G"

# H) 未登录
RH=$(curl -s -X POST "$BASE_URL/api/order/$OID/voucher" -H 'Content-Type: application/json' \
  -H "X-App-Id: $APPID" -d '{}')
echo "[H] 无 token: $(echo "$RH" | jmsg)"
ck "无 token code" "$(echo "$RH" | jcode)" "401"

# I) 跨表占用：买单和商品下单共用同一套券
V3=$(mkv $MID 20.00 100.00)
RI1=$(curl -s -X POST "$BASE_URL/api/bill" -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID" \
  -d "{\"storeId\":$STORE,\"amount\":200,\"memberVoucherId\":$V3}")
echo "[I] 买单用券$V3: $(echo "$RI1" | jmsg)"
ck "买单用券成功 code" "$(echo "$RI1" | jcode)" "200"
RI2=$(order $V3)
echo "    同券再下商品单: $(echo "$RI2" | jmsg)"
ck "买单占用后下单被拒 code" "$(echo "$RI2" | jcode)" "500"

echo
echo "PASS=$PASS FAIL=$FAIL"
if [ "$FAIL" = "0" ]; then
  echo "order voucher change smoke PASSED"
else
  echo "order voucher change smoke FAILED"
  exit 1
fi
