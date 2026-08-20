#!/usr/bin/env bash
# C36 储值卡闭环端到端 (STOERD_CARD 商品 → 购卡 → 充值 → 核销扣减 → 退款)

# fixture 自备（见 .github/scripts/lib/smoke-fixture.sh）
# 背景：62 smoke 串行跑会互相污染（改密码/耗库存/覆盖 openid），造成假 FAIL
source "$(dirname "$0")/lib/smoke-fixture.sh"
fx_ensure_mock_on
fx_reset_staff_pwd staff001

set -e
H=http://127.0.0.1:8080
DB="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"
LOG=/tmp/jrun-c36.log
TS=$(date +%s | tail -c 7)
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

echo "C36 储值卡闭环 smoke:"

# A) 商家端创建 STORED_CARD 商品
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"smoke_c36_${TS}\",\"appid\":\"wx9e147c4e2151b123\",\"nickName\":\"smoke_c36_mer\"}" $H/api/auth/login)
# MTOK 原先用「会员 token」冒充商家建商品；V5-1 给 /api/product/add 加了
# @RequireRole({OWNER,MANAGER}) 后必须用真实 OWNER token（会员建商品本就该 403）。
MTOK=$(fx_login_owner)
ADD=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK" \
  -d "{\"storeIds\":\"200\",\"typeCode\":\"STORED_CARD\",\"productName\":\"C36_$TS\",\"price\":200,\"faceValue\":300,\"minConsume\":0,\"validityDays\":365,\"stock\":50,\"productType\":\"0\",\"status\":\"0\",\"delFlag\":\"0\",\"sales\":0,\"sort\":0}" $H/api/product/add)
PID=$(echo "$ADD" | python3 -c "import sys,json; print(json.load(sys.stdin).get('productId',0))")
[ -n "$PID" ] && [ "$PID" -gt 0 ] && echo "  ✅ A) 创建 STORED_CARD 商品 id=$PID" && PASS=$((PASS+1)) || { echo "  ❌ A) add: $ADD"; FAIL=$((FAIL+1)); exit 1; }

# B) 会员登录
JSCODE="c36_${TS}"
MEM=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE\",\"appid\":\"wx9e147c4e2151b123\",\"nickName\":\"c36_mem\"}" $H/api/auth/login)
chk "B) member login" "登录成功" "$MEM"
MTOK_MEM=$(echo "$MEM" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
MEM_ID=$(echo "$MEM" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
MER_ID=$(echo "$MEM" | python3 -c "import sys,json; print(json.load(sys.stdin).get('merchantId',0))")
echo "  [B] memberId=$MEM_ID merchantId=$MER_ID"

# C) 会员下单购卡（创建订单）
ORD=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK_MEM" \
  -d "{\"productId\":$PID,\"num\":1}" $H/api/order)
OID=$(echo "$ORD" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data'); print(d.get('orderId',0) if isinstance(d, dict) else 0)" 2>/dev/null)
[ -n "$OID" ] && [ "$OID" -gt 0 ] && echo "  ✅ C) 下单成功 orderId=$OID" && PASS=$((PASS+1)) || { echo "  ❌ C) order: $ORD"; FAIL=$((FAIL+1)); exit 1; }

# D) 模拟支付 + 创建储值卡（购卡成功后创建卡实例，余额=面额300）
$DB -e "UPDATE biz_order SET status='1', pay_time=now(), pay_amount=200, expire_time=DATE_ADD(NOW(), INTERVAL 365 DAY) WHERE order_id=$OID;" 2>/dev/null
# 注入卡：会员一卡一商品
$DB -e "INSERT INTO biz_member_stored_card (merchant_id, member_id, product_id, order_id, face_value, balance, status, del_flag) VALUES ($MER_ID, $MEM_ID, $PID, $OID, 300, 300, '0', '0');" 2>/dev/null
CARD_ID=$($DB -N -e "SELECT card_id FROM biz_member_stored_card WHERE member_id=$MEM_ID AND product_id=$PID AND del_flag='0';" 2>/dev/null | head -1)
[ -n "$CARD_ID" ] && echo "  ✅ D) 卡实例已创建 cardId=$CARD_ID 余额=300" && PASS=$((PASS+1)) || { echo "  ❌ D) 卡创建失败"; FAIL=$((FAIL+1)); exit 1; }

# E) 查询我的卡列表
LIST=$(curl -s -H "Authorization: Bearer $MTOK_MEM" "$H/api/member/stored-card/list")
chk "E) listMyCards 返 1 张" "C36_$TS" "$LIST"

# F) 会员自助充值 100 元（幂等 bizNo）
BIZNO="recharge_${TS}"
RE=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK_MEM" \
  -d "{\"cardId\":$CARD_ID,\"amount\":100,\"bizNo\":\"$BIZNO\"}" $H/api/member/stored-card/recharge)
chk "F) 充值 100" "操作成功" "$RE"
BAL=$($DB -N -e "SELECT balance FROM biz_member_stored_card WHERE card_id=$CARD_ID;" 2>/dev/null | head -1)
[ "$BAL" = "400.00" ] && echo "  ✅ F+) 余额=300+100=400" && PASS=$((PASS+1)) || { echo "  ❌ F+) balance=$BAL (want 400.00)"; FAIL=$((FAIL+1)); }

# G) 充值幂等：同 bizNo 再调一次，余额不应变
RE2=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK_MEM" \
  -d "{\"cardId\":$CARD_ID,\"amount\":100,\"bizNo\":\"$BIZNO\"}" $H/api/member/stored-card/recharge)
BAL2=$($DB -N -e "SELECT balance FROM biz_member_stored_card WHERE card_id=$CARD_ID;" 2>/dev/null | head -1)
[ "$BAL2" = "400.00" ] && echo "  ✅ G) 幂等命中（余额未变 400.00）" && PASS=$((PASS+1)) || { echo "  ❌ G) 幂等失败 balance=$BAL2"; FAIL=$((FAIL+1)); }

# H) 店员登录 + 核销（消费 200）
SLOGIN=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"staff001","password":"admin123"}' $H/api/store/staff/login)
STOK=$(echo "$SLOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STOK" -d '{"storeId":200}' $H/api/store/staff/switch-store > /dev/null
STAFF_SID=200
# 取 verifyCode
VC=$($DB -N -e "SELECT verify_code FROM biz_order WHERE order_id=$OID;" 2>/dev/null | head -1)
[ -z "$VC" ] || [ "$VC" = "NULL" ] && $DB -e "UPDATE biz_order SET verify_code=UPPER(SUBSTRING(MD5(RAND()),1,12)) WHERE order_id=$OID;" 2>/dev/null && VC=$($DB -N -e "SELECT verify_code FROM biz_order WHERE order_id=$OID;" 2>/dev/null | head -1)
echo "  [H] verifyCode=$VC"
V=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STOK" \
  -d "{\"storeId\":$STAFF_SID,\"verifyCode\":\"$VC\"}" $H/api/order/verify)
chk "H) verify 200" "操作成功" "$V"
sleep 1
BAL3=$($DB -N -e "SELECT balance FROM biz_member_stored_card WHERE card_id=$CARD_ID;" 2>/dev/null | head -1)
USED=$($DB -N -e "SELECT used_amount FROM biz_member_stored_card WHERE card_id=$CARD_ID;" 2>/dev/null | head -1)
[ "$BAL3" = "200.00" ] && [ "$USED" = "200.00" ] && echo "  ✅ H+) 核销扣减: balance=200 used=200" && PASS=$((PASS+1)) || { echo "  ❌ H+) balance=$BAL3 used=$USED (want 200/200)"; FAIL=$((FAIL+1)); }

# I) 核销幂等：同 orderNo 再 verify 一次，余额不应再扣
ORD3=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK_MEM" \
  -d "{\"productId\":$PID,\"num\":1}" $H/api/order)
OID3=$(echo "$ORD3" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data'); print(d.get('orderId',0) if isinstance(d, dict) else 0)" 2>/dev/null)
$DB -e "UPDATE biz_order SET status='1', pay_time=now(), pay_amount=200, expire_time=DATE_ADD(NOW(), INTERVAL 365 DAY) WHERE order_id=$OID3;" 2>/dev/null
# 二次 verify OID 已 status=2，应校验失败"订单状态不可核销"
V2=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STOK" \
  -d "{\"storeId\":$STAFF_SID,\"verifyCode\":\"$VC\"}" $H/api/order/verify)
chk "I) 同码二次 verify 拒绝" "订单状态" "$V2"
BAL4=$($DB -N -e "SELECT balance FROM biz_member_stored_card WHERE card_id=$CARD_ID;" 2>/dev/null | head -1)
USED4=$($DB -N -e "SELECT used_amount FROM biz_member_stored_card WHERE card_id=$CARD_ID;" 2>/dev/null | head -1)
[ "$BAL4" = "200.00" ] && [ "$USED4" = "200.00" ] && echo "  ✅ I+) 余额未重复扣" && PASS=$((PASS+1)) || { echo "  ❌ I+) balance=$BAL4 used=$USED4"; FAIL=$((FAIL+1)); }

# J) 退款 50
BIZNO_F="refund_${TS}"
RF=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK_MEM" \
  -d "{\"cardId\":$CARD_ID,\"amount\":50,\"bizNo\":\"$BIZNO_F\",\"orderId\":$OID}" $H/api/member/stored-card/refund)
chk "J) 退款 50" "操作成功" "$RF"
BAL5=$($DB -N -e "SELECT balance FROM biz_member_stored_card WHERE card_id=$CARD_ID;" 2>/dev/null | head -1)
RF_AMT=$($DB -N -e "SELECT refund_amount FROM biz_member_stored_card WHERE card_id=$CARD_ID;" 2>/dev/null | head -1)
[ "$BAL5" = "250.00" ] && [ "$RF_AMT" = "50.00" ] && echo "  ✅ J+) 退款后 balance=250 refund=50" && PASS=$((PASS+1)) || { echo "  ❌ J+) balance=$BAL5 refund=$RF_AMT"; FAIL=$((FAIL+1)); }

# K) 流水数量
TXN=$($DB -N -e "SELECT COUNT(*) FROM biz_stored_card_transaction WHERE card_id=$CARD_ID;" 2>/dev/null | head -1)
[ "$TXN" -ge 3 ] && echo "  ✅ K) 流水 >= 3 (充值+扣减+退款) txCount=$TXN" && PASS=$((PASS+1)) || { echo "  ❌ K) txCount=$TXN"; FAIL=$((FAIL+1)); }

# L) 流水列表 API
TXNAPI=$(curl -s -H "Authorization: Bearer $MTOK_MEM" "$H/api/member/stored-card/transactions?cardId=$CARD_ID")
chk "L) 流水 API 返 OK" "操作成功" "$TXNAPI"

# M) 跨会员越权防护：另开一个会员查此卡 → 应 401
LOGIN2=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"c36b_${TS}\",\"appid\":\"wx9e147c4e2151b123\",\"nickName\":\"c36_evil\"}" $H/api/auth/login)
MTOK2=$(echo "$LOGIN2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
AUTH=$(curl -s -H "Authorization: Bearer $MTOK2" "$H/api/member/stored-card/balance?cardId=$CARD_ID")
chk "M) 跨会员越权被拒" "无权" "$AUTH"

# N) 余额不足：尝试核销一个新订单（消费 500 > 250）
ORD4=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK_MEM" \
  -d "{\"productId\":$PID,\"num\":1}" $H/api/order)
OID4=$(echo "$ORD4" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data'); print(d.get('orderId',0) if isinstance(d, dict) else 0)" 2>/dev/null)
$DB -e "UPDATE biz_order SET status='1', pay_time=now(), pay_amount=500, expire_time=DATE_ADD(NOW(), INTERVAL 365 DAY) WHERE order_id=$OID4;" 2>/dev/null
$DB -e "UPDATE biz_order SET verify_code=UPPER(SUBSTRING(MD5(RAND()),1,12)) WHERE order_id=$OID4;" 2>/dev/null
VC4=$($DB -N -e "SELECT verify_code FROM biz_order WHERE order_id=$OID4;" 2>/dev/null | head -1)
V3=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STOK" \
  -d "{\"storeId\":$STAFF_SID,\"verifyCode\":\"$VC4\"}" $H/api/order/verify)
chk "N) 余额不足 500>250 verify 失败" "余额不足" "$V3"
ST_ORD4=$($DB -N -e "SELECT status FROM biz_order WHERE order_id=$OID4;" 2>/dev/null | head -1)
[ "$ST_ORD4" = "1" ] && echo "  ✅ N+) 事务回滚：订单未核销 status=1" && PASS=$((PASS+1)) || { echo "  ❌ N+) status=$ST_ORD4 (want 1=未核销)"; FAIL=$((FAIL+1)); }
BAL_F=$($DB -N -e "SELECT balance FROM biz_member_stored_card WHERE card_id=$CARD_ID;" 2>/dev/null | head -1)
[ "$BAL_F" = "250.00" ] && echo "  ✅ N++) 余额未变 250" && PASS=$((PASS+1)) || { echo "  ❌ N++) balance=$BAL_F"; FAIL=$((FAIL+1)); }

echo ""
echo "C36 结果: $PASS PASS / $FAIL FAIL"
[ $FAIL -eq 0 ] && echo "🎉 ALL PASS" || echo "❌ 有失败用例"
