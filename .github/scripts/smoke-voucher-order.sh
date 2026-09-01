#!/usr/bin/env bash
# 商品下单代金券抵扣 smoke test
#
# 锁住的行为：小程序商品下单（含「到店自取」，两者是同一个
# pages/order/submit 页，pickup 只是页面上的勾选项）必须把选中的
# memberVoucherId 带进 POST /api/order，后端 placeOrder 据此算
# discount_amount / pay_amount 并把 member_voucher_id 落库。
#
# 为什么要这个 smoke：后端抵扣逻辑一直是完整的（校验归属、校验门槛、
# 面值超过订单金额时封顶、支付成功后把券置为已使用），但小程序下单页
# 既没有选券入口、createOrder 也没传这个参数 —— 于是「领了券不能抵扣」。
# 这类缺口在后端单侧完全测不出来，必须从下单请求这一层锁住。
#
# 验证：
#   A) 带券下单 → discountAmount=面值 / payAmount=总价-面值 / 三个字段真落库
#   B) 券面值超过订单金额 → 抵扣封顶到订单金额，payAmount=0 不为负
#   C) 未达门槛 → 拒绝下单（前端置灰，后端兜底）
#   D) 别人的券 → 拒绝（防止前端改 id 盗用）
#   E) 已使用的券 → 拒绝（防止一券多用）
#   F) 不带券 → discount=0 / payAmount=总价 / member_voucher_id 为 NULL
#
# 前置：后端在 8080 运行（druid profile），本地 mysql 可连
# 用法：bash .github/scripts/smoke-voucher-order.sh
set -e

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
APPID="${APPID:-wx9e147c4e2151b123}"
MYSQL="${MYSQL_BIN:-/usr/local/mysql/bin/mysql}"
PRODUCT=1001          # 招牌牛肉面 ¥38.00，门店 100（商户 1）
FAIL=0

ck() { # ck <描述> <实际> <期望>
  if [ "$2" = "$3" ]; then echo "  OK: $1 ($2)"; else echo "  FAIL: $1 期望 $3 实际 $2"; FAIL=1; fi
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

# 金额专用：json.load 会把 "38.00" 读成 float 38.0，直接和 "38.00" 比会假失败。
# parse_float=Decimal 保留原始标度，再统一格式成两位小数。
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
  # 订单和券都是本脚本造的，按 openid / id 段精确删，不碰既有数据
  sql "delete from biz_order where member_id in (select member_id from biz_member where openid in ('mock_smokevo','mock_smokevo2'));"
  sql "delete from biz_member_voucher where member_id in (select member_id from biz_member where openid in ('mock_smokevo','mock_smokevo2'));"
  sql "delete from biz_member where openid in ('mock_smokevo','mock_smokevo2');"
}
trap cleanup EXIT
cleanup   # 上次异常中断可能有残留

# 0) 两个会员登录（mock 登录：openid=mock_<code>）。第二个只用来造「别人的券」
MTK=$(curl -s -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' -H "X-App-Id: $APPID" \
  -d "{\"code\":\"smokevo\",\"appid\":\"$APPID\"}" | jget token)
[ -n "$MTK" ] || { echo "FAIL: 会员登录拿不到 token（本地需 wx.miniapp.mockEnabled=true）"; exit 1; }
curl -s -X POST "$BASE_URL/api/auth/login" -H 'Content-Type: application/json' \
  -H "X-App-Id: $APPID" -d "{\"code\":\"smokevo2\",\"appid\":\"$APPID\"}" > /dev/null

MID=$(sql1  "select member_id from biz_member where openid='mock_smokevo';")
MID2=$(sql1 "select member_id from biz_member where openid='mock_smokevo2';")
echo "[0] member=$MID other=$MID2 商品=$PRODUCT(¥38.00)"

# 造券：全部挂在 voucher_id=0（不引用真实券模板，避免动 biz_voucher 的 received 计数）
mkv() { # mkv <memberId> <面值> <门槛> <status> → 打印新券 id
  sql "insert into biz_member_voucher(merchant_id,voucher_id,member_id,face_value,threshold,status,get_time,expire_time)
       values(1,0,$1,$2,$3,'$4',now(),date_add(now(), interval 30 day));"
  sql1 "select max(id) from biz_member_voucher where member_id=$1;"
}

order() { # order <memberVoucherId|-> <num>
  local body
  if [ "$1" = "-" ]; then body="{\"productId\":$PRODUCT,\"num\":$2}"
  else body="{\"productId\":$PRODUCT,\"num\":$2,\"memberVoucherId\":$1}"; fi
  curl -s -X POST "$BASE_URL/api/order" -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID" -d "$body"
}

# A) 带券下单：10 元券、门槛 30，订单 ¥38 → 抵 10 实付 28
V_OK=$(mkv $MID 10.00 30.00 0)
RESP=$(order $V_OK 1)
OID=$(echo "$RESP" | jget orderId)
echo "[A] 带券下单(券$V_OK 面值10 门槛30): $(echo "$RESP" | head -c 200)"
ck "总价"       "$(echo "$RESP" | jamt totalAmount)"    "38.00"
ck "抵扣金额"   "$(echo "$RESP" | jamt discountAmount)" "10.00"
ck "实付金额"   "$(echo "$RESP" | jamt payAmount)"      "28.00"
ck "落库三字段" "$(sql1 "select concat(discount_amount,'/',pay_amount,'/',member_voucher_id) from biz_order where order_id=$OID;")" "10.00/28.00/$V_OK"

# B) 面值 50 > 订单 38：抵扣要封顶到 38，实付 0 —— 不能出现负数金额去调起支付
V_BIG=$(mkv $MID 50.00 30.00 0)
RESP=$(order $V_BIG 1)
OID_B=$(echo "$RESP" | jget orderId)
echo "[B] 面值超过订单金额(券$V_BIG 面值50): $(echo "$RESP" | head -c 200)"
ck "抵扣封顶到订单金额" "$(echo "$RESP" | jamt discountAmount)" "38.00"
ck "实付 0 不为负"      "$(echo "$RESP" | jamt payAmount)"      "0.00"

# C) 门槛 100 > 订单 38 → 必须拒。前端会把这张券置灰，后端是兜底
V_HIGH=$(mkv $MID 20.00 100.00 0)
RESP=$(order $V_HIGH 1)
echo "[C] 未达门槛(券$V_HIGH 门槛100): $(echo "$RESP" | head -c 200)"
ck "未达门槛被拒 code" "$(echo "$RESP" | jcode)" "500"

# D) 别人的券：前端只要改个 id 就能试，后端必须按 memberId 校验归属
V_OTHER=$(mkv $MID2 10.00 0.00 0)
RESP=$(order $V_OTHER 1)
echo "[D] 用别人的券(券$V_OTHER 属于$MID2): $(echo "$RESP" | head -c 200)"
ck "盗用他人券被拒 code" "$(echo "$RESP" | jcode)" "500"

# E) 已使用的券 status='1' → 拒，防一券多用
V_USED=$(mkv $MID 10.00 0.00 1)
RESP=$(order $V_USED 1)
echo "[E] 已使用的券(券$V_USED status=1): $(echo "$RESP" | head -c 200)"
ck "已使用券被拒 code" "$(echo "$RESP" | jcode)" "500"

# F) 不带券：抵扣 0、实付=总价、member_voucher_id 为 NULL（不能写成 0）
RESP=$(order - 1)
OID_F=$(echo "$RESP" | jget orderId)
echo "[F] 不带券下单: $(echo "$RESP" | head -c 200)"
ck "抵扣为 0"          "$(echo "$RESP" | jamt discountAmount)" "0.00"
ck "实付等于总价"      "$(echo "$RESP" | jamt payAmount)"      "38.00"
ck "券字段为 NULL"     "$(sql1 "select ifnull(member_voucher_id,'NULL') from biz_order where order_id=$OID_F;")" "NULL"

echo
if [ "$FAIL" = "0" ]; then
  echo "voucher order smoke PASSED"
else
  echo "voucher order smoke FAILED"; exit 1
fi
