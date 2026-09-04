#!/usr/bin/env bash
# 订单/买单取消 + 代金券解锁 smoke test
#
# 起因是用户实测报错：「该代金券已用于另一笔买单，请先完成或取消那笔」。
# 提示本身没错 —— VoucherUsageService.assertNotHeld 把 status in ('0','1','2')
# 都算作占用（必须的，否则同一张券能在 N 个待付单里各抵一次）。
# 真正的缺陷是：全端压根没有「取消」这个动作。
#   - ApiOrderController 只有 create/voucher/prepay/pay/list/detail/verify/…
#   - ApiBillController  只有 create/detail/confirm/prepay/pay
#   - 小程序 order/detail、order/list、order-pay 三页都只有「去支付」
# 于是用户用券下了单又不付，那张券就被永久锁死，而系统让他去做一件
# 产品里根本不存在的操作 —— 死锁。
#
# 本脚本锁的不是「有个 cancel 端点」，而是「取消真能把券解锁」：
#   A) 券锁死现场复现：带券下单 → 同券再下单被拒
#   B) 取消订单 → status='3' 且 member_voucher_id 真置 NULL → 同券可再用
#   C) 幂等：重复取消不报错
#   D) 已支付订单不可取消（要走退款，否则钱货两空）
#   E) 不可取消他人订单，且对方数据未被篡改
#   F) 买单侧同型问题：带券建买单 → 取消 → 券解锁，且 bill_id 的券字段置 NULL
#   G) 已支付买单不可取消
#   H) 跨表解锁：买单占的券，取消买单后商品下单可用（用户报错的原始场景）
#   I) 无 token → 401
#
# 前置：后端在 8080 运行（druid profile），本地 mysql 可连
# 用法：bash .github/scripts/smoke-order-bill-cancel.sh
set -uo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
APPID="${APPID:-wx9e147c4e2151b123}"
MYSQL="${MYSQL_BIN:-/usr/local/mysql/bin/mysql}"
PRODUCT=999829        # ¥200.00，门店 200（商户 1）。金额要大于券门槛 100
STORE=200
PASS=0; FAIL=0

ck() {
  if [ "$2" = "$3" ]; then echo "  OK: $1 ($2)"; PASS=$((PASS+1));
  else echo "  FAIL: $1 期望 $3 实际 $2"; FAIL=$((FAIL+1)); fi
}

jget() { python3 -c "
import sys,json
try: d=json.loads(sys.stdin.read() or '{}')
except Exception: print(''); sys.exit()
b=d.get('data') if isinstance(d.get('data'),dict) else d
v=b
for k in '$1'.split('.'):
    v=(v or {}).get(k) if isinstance(v,dict) else None
print('' if v is None else v)
"; }
jcode() { python3 -c 'import sys,json
try: print(json.loads(sys.stdin.read() or "{}").get("code"))
except Exception: print("parse_error")'; }
jmsg()  { python3 -c 'import sys,json
try: print(json.loads(sys.stdin.read() or "{}").get("msg") or "")
except Exception: print("")'; }

sql()  { "$MYSQL" -h127.0.0.1 -uroot -p133301 --default-character-set=utf8mb4 ry-vue -e "$1" 2>/dev/null || true; }
sql1() { "$MYSQL" -h127.0.0.1 -uroot -p133301 --default-character-set=utf8mb4 -N -B -e "use \`ry-vue\`; $1" 2>/dev/null || true; }

cleanup() {
  sql "delete from biz_order where member_id in (select member_id from biz_member where openid in ('mock_smokecx','mock_smokecx2'));"
  sql "delete from biz_pay_bill where member_id in (select member_id from biz_member where openid in ('mock_smokecx','mock_smokecx2'));"
  sql "delete from biz_member_voucher where member_id in (select member_id from biz_member where openid in ('mock_smokecx','mock_smokecx2'));"
  sql "delete from biz_member where openid in ('mock_smokecx','mock_smokecx2');"
}
trap cleanup EXIT
cleanup

MTK=$(curl -s -X POST "$BASE_URL/api/auth/login" -H 'Content-Type: application/json' \
  -H "X-App-Id: $APPID" -d "{\"code\":\"smokecx\",\"appid\":\"$APPID\"}" | jget token)
[ -n "$MTK" ] || { echo "FAIL: 会员登录拿不到 token（本地需 wx.miniapp.mockEnabled=true）"; exit 1; }
MTK2=$(curl -s -X POST "$BASE_URL/api/auth/login" -H 'Content-Type: application/json' \
  -H "X-App-Id: $APPID" -d "{\"code\":\"smokecx2\",\"appid\":\"$APPID\"}" | jget token)
MID=$(sql1  "select member_id from biz_member where openid='mock_smokecx';")
MID2=$(sql1 "select member_id from biz_member where openid='mock_smokecx2';")
echo "[0] member=$MID other=$MID2 商品=$PRODUCT(¥200.00) 门店=$STORE"

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
cancel() { # cancel <orderId> [token]
  local tk="${2:-$MTK}"
  curl -s -X POST "$BASE_URL/api/order/$1/cancel" \
    -H "Authorization: Bearer $tk" -H "X-App-Id: $APPID"
}
bill() { # bill <amount> <memberVoucherId|-> [token]
  local body tk="${3:-$MTK}"
  if [ "$2" = "-" ]; then body="{\"storeId\":$STORE,\"amount\":$1}"
  else body="{\"storeId\":$STORE,\"amount\":$1,\"memberVoucherId\":$2}"; fi
  curl -s -X POST "$BASE_URL/api/bill" -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $tk" -H "X-App-Id: $APPID" -d "$body"
}
cancelbill() { # cancelbill <billId> [token]
  local tk="${2:-$MTK}"
  curl -s -X POST "$BASE_URL/api/bill/$1/cancel" \
    -H "Authorization: Bearer $tk" -H "X-App-Id: $APPID"
}

# A) 复现券锁死现场
V=$(mkv "$MID" 20.00 100.00)
R1=$(order "$V"); OID=$(echo "$R1" | jget orderId)
echo "[A] 带券下单(券$V) orderId=$OID"
ck "首单落库占券" "$(sql1 "select count(1) from biz_order where member_voucher_id=$V and status in ('0','1','2');")" "1"
R2=$(order "$V")
echo "    同券再下单: $(echo "$R2" | jmsg)"
ck "同券第二单被拒" "$(echo "$R2" | jcode)" "500"

# B) 取消订单 → 券解锁
RB=$(cancel "$OID")
echo "[B] 取消订单: code=$(echo "$RB" | jcode) $(echo "$RB" | jmsg)"
ck "取消返回 200"        "$(echo "$RB" | jcode)" "200"
ck "订单 status 落库 3"  "$(sql1 "select status from biz_order where order_id=$OID;")" "3"
ck "券字段落库 NULL"     "$(sql1 "select ifnull(member_voucher_id,'NULL') from biz_order where order_id=$OID;")" "NULL"
R3=$(order "$V"); OID3=$(echo "$R3" | jget orderId)
ck "解锁后同券可再下单"   "$(echo "$R3" | jcode)" "200"
ck "新单确实抵扣了"       "$(sql1 "select cast(discount_amount as char) from biz_order where order_id=$OID3;")" "20.00"

# C) 幂等：弱网下用户会连点取消
ck "重复取消不报错" "$(cancel "$OID" | jcode)" "200"

# D) 已支付订单不可取消（否则用户付了钱订单变已取消，钱货两空）
sql "update biz_order set status='1' where order_id=$OID3;"
RD=$(cancel "$OID3")
echo "[D] 已支付单取消: $(echo "$RD" | jmsg)"
ck "已支付不可取消"        "$(echo "$RD" | jcode)" "500"
ck "已支付单 status 未变"  "$(sql1 "select status from biz_order where order_id=$OID3;")" "1"

# E) 越权取消他人订单
RE=$(cancel "$OID3" "$MTK2")
echo "[E] 越权取消: $(echo "$RE" | jmsg)"
ck "越权被拒"             "$(echo "$RE" | jcode)" "500"
ck "他人订单 status 未变"  "$(sql1 "select status from biz_order where order_id=$OID3;")" "1"

# F) 买单侧同型问题
V2=$(mkv "$MID" 20.00 100.00)
RF=$(bill 200.00 "$V2"); BID=$(echo "$RF" | jget billId)
echo "[F] 带券建买单(券$V2) billId=$BID status=$(echo "$RF" | jget status)"
ck "买单落库占券" "$(sql1 "select count(1) from biz_pay_bill where member_voucher_id=$V2 and status in ('0','1','2');")" "1"
RF2=$(bill 200.00 "$V2")
ck "同券第二笔买单被拒" "$(echo "$RF2" | jcode)" "500"
RFC=$(cancelbill "$BID")
echo "    取消买单: code=$(echo "$RFC" | jcode) $(echo "$RFC" | jmsg)"
ck "买单取消返回 200"       "$(echo "$RFC" | jcode)" "200"
ck "买单 status 落库 3"     "$(sql1 "select status from biz_pay_bill where bill_id=$BID;")" "3"
ck "买单券字段落库 NULL"    "$(sql1 "select ifnull(member_voucher_id,'NULL') from biz_pay_bill where bill_id=$BID;")" "NULL"

# G) 已支付买单不可取消
RG1=$(bill 200.00 -); BID2=$(echo "$RG1" | jget billId)
sql "update biz_pay_bill set status='2' where bill_id=$BID2;"
RG=$(cancelbill "$BID2")
echo "[G] 已支付买单取消: $(echo "$RG" | jmsg)"
ck "已支付买单不可取消"       "$(echo "$RG" | jcode)" "500"
ck "已支付买单 status 未变"   "$(sql1 "select status from biz_pay_bill where bill_id=$BID2;")" "2"
ck "越权取消他人买单被拒"      "$(cancelbill "$BID" "$MTK2" | jcode)" "500"

# H) 跨表解锁：用户报错的原始场景 —— 券被买单占着，商品下单用不了
V3=$(mkv "$MID" 20.00 100.00)
RH1=$(bill 200.00 "$V3"); BID3=$(echo "$RH1" | jget billId)
RH2=$(order "$V3")
echo "[H] 券被买单占用时下单: $(echo "$RH2" | jmsg)"
ck "跨表占用被拒"   "$(echo "$RH2" | jcode)" "500"
ck "报错文案指向买单" "$(echo "$RH2" | jmsg | grep -c '买单')" "1"
cancelbill "$BID3" > /dev/null
RH3=$(order "$V3")
ck "取消买单后下单成功" "$(echo "$RH3" | jcode)" "200"

# I) 未登录
ck "订单取消无 token → 401" "$(curl -s -X POST "$BASE_URL/api/order/$OID/cancel" -H "X-App-Id: $APPID" | jcode)" "401"
ck "买单取消无 token → 401" "$(curl -s -X POST "$BASE_URL/api/bill/$BID/cancel" -H "X-App-Id: $APPID" | jcode)" "401"

echo
echo "===== smoke-order-bill-cancel: PASS=$PASS FAIL=$FAIL ====="
[ "$FAIL" -eq 0 ]
