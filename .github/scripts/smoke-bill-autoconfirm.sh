#!/usr/bin/env bash
# 买单自动确认 smoke test
#
# 锁住的行为：买单的场景是顾客在店员面前输入金额后直接支付，
# 门店 bill_auto_confirm 默认 '1' → create() 落 status='1'（待支付），
# 不需要店员再去后台点一次确认。
#
# 为什么要这个 smoke：这一步曾经挂在支付 mock 开关上
#   （if (wxPayService.isMock()) status='1'），而 WxPayConfig 在 prod profile
# 硬编码关 mock，于是本地建单即可付、生产必须等确认 —— 同一份代码两种行为。
# 而生产上那个确认没有任何一端能完成（confirm 要 userType=='store'，
# 商家端签发的是 merchant/owner/manager/staff），买单实际是走不通的。
#
# 验证：
#   A) 默认门店建单 → status=1 + confirmUser=auto
#   B) status=1 可直接 prepay（不必先 confirm）
#   C) 门店关掉开关 → status=0（开关真生效，不是硬编码）
#   D) 关掉开关的单直接 prepay → 被拒
#   E) 门店不存在 → 缺省按自动确认（不能让付款链路断掉）
#
# 前置：后端在 8080 运行（druid profile），本地 mysql 可连
# 用法：bash .github/scripts/smoke-bill-autoconfirm.sh
set -e

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
APPID="${APPID:-wx9e147c4e2151b123}"
MYSQL="${MYSQL_BIN:-/usr/local/mysql/bin/mysql}"
STORE_ON=100
STORE_OFF=101
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

sql() { "$MYSQL" -h127.0.0.1 -uroot -p133301 ry-vue -e "$1" 2>/dev/null || true; }

CREATED=""
cleanup() {
  if [ -n "$CREATED" ]; then
    sql "delete from biz_pay_bill where bill_id in ($CREATED);"
  fi
  sql "update biz_store set bill_auto_confirm='1' where store_id in ($STORE_ON,$STORE_OFF);"
  sql "delete from biz_member where openid='mock_smokebill';"
}
trap cleanup EXIT

# 0) 会员登录（mock 登录：openid=mock_<code>）
MTK=$(curl -s -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' -H "X-App-Id: $APPID" \
  -d "{\"code\":\"smokebill\",\"appid\":\"$APPID\"}" | jget token)
[ -n "$MTK" ] || { echo "FAIL: 会员登录拿不到 token（本地需 wx.miniapp.mockEnabled=true）"; exit 1; }

# 前置：确保两个门店初始都是自动确认
sql "update biz_store set bill_auto_confirm='1' where store_id in ($STORE_ON,$STORE_OFF);"

newbill() { # newbill <storeId> <amount>
  curl -s -X POST "$BASE_URL/api/bill" -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID" \
    -d "{\"storeId\":$1,\"amount\":$2}"
}

# A) 默认门店 → status=1 + confirmUser=auto
RESP=$(newbill $STORE_ON 88.50)
BID_A=$(echo "$RESP" | jget billId)
CREATED="$BID_A"
echo "[A] 默认自动确认门店建单: $(echo "$RESP" | head -c 160)"
ck "建单即待支付 status" "$(echo "$RESP" | jget status)" "1"
ck "确认人标记为 auto"    "$(echo "$RESP" | jget confirmUser)" "auto"

# B) 不经 confirm 直接 prepay
PRE=$(curl -s -X POST "$BASE_URL/api/bill/prepay/$BID_A" \
  -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID")
echo "[B] 直接 prepay: $(echo "$PRE" | head -c 160)"
ck "免确认可直接支付 code" "$(echo "$PRE" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("code"))')" "200"

# C) 关掉开关 → status=0（证明读的是门店配置）
sql "update biz_store set bill_auto_confirm='0' where store_id=$STORE_OFF;"
RESP=$(newbill $STORE_OFF 50.00)
BID_C=$(echo "$RESP" | jget billId)
CREATED="$CREATED,$BID_C"
echo "[C] 关闭自动确认门店建单: $(echo "$RESP" | head -c 160)"
ck "关闭后回到待确认 status" "$(echo "$RESP" | jget status)" "0"

# D) 待确认的单不能直接付
PRE=$(curl -s -X POST "$BASE_URL/api/bill/prepay/$BID_C" \
  -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID")
echo "[D] 待确认单 prepay: $(echo "$PRE" | head -c 160)"
ck "待确认不允许支付 code" "$(echo "$PRE" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("code"))')" "500"

# E) 门店不存在 → 缺省自动确认（宁可少一道核对，也不能让顾客付不了钱）
RESP=$(newbill 999999 10.00)
BID_E=$(echo "$RESP" | jget billId)
[ -n "$BID_E" ] && CREATED="$CREATED,$BID_E"
echo "[E] 门店不存在建单: $(echo "$RESP" | head -c 160)"
ck "缺省按自动确认 status" "$(echo "$RESP" | jget status)" "1"

echo
if [ "$FAIL" = "0" ]; then
  echo "bill autoconfirm smoke PASSED"
else
  echo "bill autoconfirm smoke FAILED"; exit 1
fi
