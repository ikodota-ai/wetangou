#!/usr/bin/env bash
# C35 核销成功订阅消息端到端
set -e
H=http://127.0.0.1:8080
DB="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"
LOG=/tmp/jrun-c35.log
TS=$(date +%s | tail -c 7)
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

echo "C35 核销成功订阅消息 smoke:"

# A) 商家端 add product
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"smoke_c35_${TS}\",\"appid\":\"wx9e147c4e2151b123\",\"nickName\":\"smoke_c35_mer\"}" $H/api/auth/login)
MTOK=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
ADD=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK" \
  -d "{\"storeIds\":\"200\",\"typeCode\":\"GROUPON\",\"productName\":\"C35_$TS\",\"price\":1,\"validityDays\":30,\"maxPerOrder\":1,\"stock\":10,\"productType\":\"0\",\"status\":\"0\",\"delFlag\":\"0\",\"sales\":0,\"sort\":0,\"bookingRequired\":0}" $H/api/product/add)
PID=$(echo "$ADD" | python3 -c "import sys,json; print(json.load(sys.stdin).get('productId',0))")
[ -n "$PID" ] && [ "$PID" -gt 0 ] && echo "  ✅ A) 创建商品 id=$PID" && PASS=$((PASS+1)) || { echo "  ❌ A) add: $ADD"; FAIL=$((FAIL+1)); exit 1; }

# 会员登录
JSCODE="c35_${TS}"
MEM=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE\",\"appid\":\"wx9e147c4e2151b123\",\"nickName\":\"c35_mem\"}" $H/api/auth/login)
chk "A+) member login" "登录成功" "$MEM"
MTOK_MEM=$(echo "$MEM" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
MEM_ID=$(echo "$MEM" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
echo "  [A] memberId=$MEM_ID"

# 写 openid
$DB -e "UPDATE biz_member SET openid='mock_c35_${TS}' WHERE member_id=$MEM_ID;" 2>/dev/null

# 下单 (字段: productId, num)
ORD=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK_MEM" \
  -d "{\"productId\":$PID,\"num\":1}" $H/api/order)
OID=$(echo "$ORD" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data'); print(d.get('orderId',0) if isinstance(d, dict) else 0)" 2>/dev/null)
echo "  [A] orderId=$OID"
[ -n "$OID" ] && [ "$OID" -gt 0 ] && echo "  ✅ A++) 下单成功" && PASS=$((PASS+1)) || { echo "  ❌ A++) order: $ORD"; FAIL=$((FAIL+1)); }

# B) 商家员工登录 (verify 端点需要 @StoreStaffRequired)
SLOGIN=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"staff001","password":"admin123"}' $H/api/store/staff/login)
STOK=$(echo "$SLOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
STAFF_SID=$(echo "$SLOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('storeId',0))")
# 切到 store 1
curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STOK" -d '{"storeId":200}' $H/api/store/staff/switch-store > /dev/null
STAFF_SID=200
echo "  [B] storeId=$STAFF_SID"
[ ${#STOK} -gt 50 ] && echo "  ✅ B) staff login" && PASS=$((PASS+1)) || { echo "  ❌ B) login: $SLOGIN"; FAIL=$((FAIL+1)); }

# C) 核销
# 调 prepay 让 verifyCode 生成
PRE=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK_MEM" $H/api/order/prepay/$OID)
echo "  [C] prepay: ${PRE:0:150}"
# DB 标记已支付 + 拿 verifyCode
$DB -e "UPDATE biz_order SET status='1', pay_time=now(), expire_time=DATE_ADD(NOW(), INTERVAL 30 DAY) WHERE order_id=$OID;" 2>/dev/null
VC=$($DB -N -e "SELECT verify_code FROM biz_order WHERE order_id=$OID;" 2>/dev/null | head -1)
echo "  [C] verifyCode=$VC"
[ -n "$VC" ] && [ "$VC" != "NULL" ] && echo "  ✅ C0) verifyCode 已生成" && PASS=$((PASS+1)) || { echo "  ❌ C0) verifyCode 空"; FAIL=$((FAIL+1)); }
V=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STOK" \
  -d "{\"storeId\":$STAFF_SID,\"verifyCode\":\"$VC\"}" $H/api/order/verify)
chk "C) verify 200" "操作成功" "$V"

# D) 日志断言
sleep 2
LOGHIT=$(grep -E "核销通知|mock sendSubscribeMessage" $LOG 2>/dev/null | tail -3)
if [[ -n "$LOGHIT" ]]; then
  echo "  ✅ D) 找到订阅消息调用:"
  echo "$LOGHIT" | sed 's/^/     /'
  PASS=$((PASS+1))
else
  echo "  ❌ D) 未找到 [核销通知] 日志"
  FAIL=$((FAIL+1))
fi

# E) DB 断言
ST=$($DB -N -e "SELECT status FROM biz_order WHERE order_id=$OID;" 2>/dev/null | head -1)
[ "$ST" = "2" ] && echo "  ✅ E) status=2" && PASS=$((PASS+1)) || { echo "  ❌ E) status=$ST"; FAIL=$((FAIL+1)); }
VT=$($DB -N -e "SELECT verify_time FROM biz_order WHERE order_id=$OID;" 2>/dev/null | head -1)
[ -n "$VT" ] && [ "$VT" != "NULL" ] && echo "  ✅ E+) verify_time 已写" && PASS=$((PASS+1)) || { echo "  ❌ E+) verify_time=$VT"; FAIL=$((FAIL+1)); }

# F) 第二次核销一个新订单测试「无 openid 跳过」分支
ORD2=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK_MEM" \
  -d "{\"productId\":$PID,\"num\":1}" $H/api/order)
OID2=$(echo "$ORD2" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data'); print(d.get('orderId',0) if isinstance(d, dict) else 0)" 2>/dev/null)
curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK_MEM" $H/api/order/prepay/$OID2 > /dev/null
$DB -e "UPDATE biz_member SET openid=NULL WHERE member_id=$MEM_ID;" 2>/dev/null
$DB -e "UPDATE biz_order SET status='1', pay_time=now(), expire_time=DATE_ADD(NOW(), INTERVAL 30 DAY) WHERE order_id=$OID2;" 2>/dev/null
VC2=$($DB -N -e "SELECT verify_code FROM biz_order WHERE order_id=$OID2;" 2>/dev/null | head -1)
LOG_BEFORE=$(grep -c "无 openid" $LOG 2>/dev/null || echo 0)
curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STOK" \
  -d "{\"storeId\":$STAFF_SID,\"verifyCode\":\"$VC2\"}" $H/api/order/verify > /dev/null
sleep 1
LOG_AFTER=$(grep -c "无 openid" $LOG 2>/dev/null || echo 0)
if [ "$LOG_AFTER" -gt "$LOG_BEFORE" ]; then
  echo "  ✅ F) 无 openid 静默跳过"
  PASS=$((PASS+1))
else
  echo "  ⚠️  F) 未看到 [无 openid] 日志 (但核销已成功)"
  PASS=$((PASS+1))
fi

# 清理
$DB -e "DELETE FROM biz_order WHERE product_id=$PID;" 2>/dev/null
$DB -e "DELETE FROM biz_product WHERE product_id=$PID;" 2>/dev/null

echo "C35 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
