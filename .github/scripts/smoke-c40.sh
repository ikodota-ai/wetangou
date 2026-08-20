#!/usr/bin/env bash
# C40 「客人端出示核销码 Scheme」端到端 smoke
# 链路: 客人下单 → 调 /api/order/{orderId}/scheme 拿 Scheme URL
#       → 解析 Scheme URL → 拿到 code/sid → 店员 verify → 订单 status=2
#       防越权: 别人的订单不能拿 scheme

# fixture 自备（见 .github/scripts/lib/smoke-fixture.sh）
# 背景：62 smoke 串行跑会互相污染（改密码/耗库存/覆盖 openid），造成假 FAIL
source "$(dirname "$0")/lib/smoke-fixture.sh"
fx_ensure_mock_on
fx_reset_staff_pwd staff001

set -e
H=http://127.0.0.1:8080
LOG=/tmp/jrun-c40.log
TS=$(date +%s | tail -c 7)
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

echo "C40 「客人端出示核销码 Scheme」 smoke:"

# A) 商家登录建商品
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"smoke_c40_mer_${TS}\",\"appid\":\"wx9e147c4e2151b123\",\"nickName\":\"c40_mer\"}" $H/api/auth/login)
# MTOK 原先用「会员 token」冒充商家建商品；V5-1 给 /api/product/add 加了
# @RequireRole({OWNER,MANAGER}) 后必须用真实 OWNER token（会员建商品本就该 403）。
MTOK=$(fx_login_owner)
ADD=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK" \
  -d "{\"storeIds\":\"200\",\"typeCode\":\"GROUPON\",\"productName\":\"C40_$TS\",\"price\":1,\"validityDays\":30,\"maxPerOrder\":1,\"stock\":10,\"productType\":\"0\",\"status\":\"0\",\"delFlag\":\"0\",\"sales\":0,\"sort\":0,\"bookingRequired\":0}" $H/api/product/add)
PID=$(echo "$ADD" | python3 -c "import sys,json; print(json.load(sys.stdin).get('productId',0))")
[ -n "$PID" ] && [ "$PID" -gt 0 ] && echo "  ✅ A) 创建商品 id=$PID" && PASS=$((PASS+1)) || { echo "  ❌ A) add: $ADD"; FAIL=$((FAIL+1)); exit 1; }

# B) 会员 A 登录下单
JSCODE="c40_${TS}"
MEM_A=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE\",\"appid\":\"wx9e147c4e2151b123\",\"nickName\":\"c40_A\"}" $H/api/auth/login)
MTOK_A=$(echo "$MEM_A" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
ORD=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK_A" \
  -d "{\"productId\":$PID,\"num\":1}" $H/api/order)
OID=$(echo "$ORD" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data'); print(d.get('orderId',0) if isinstance(d, dict) else 0)" 2>/dev/null)
[ -n "$OID" ] && [ "$OID" -gt 0 ] && echo "  ✅ B) 会员A下单 orderId=$OID" && PASS=$((PASS+1)) || { echo "  ❌ B) order: $ORD"; FAIL=$((FAIL+1)); exit 1; }

# C) 标已支付
curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK_A" $H/api/order/prepay/$OID > /dev/null
python3 -c "
import pymysql
c = pymysql.connect(host='127.0.0.1',port=3306,user='root',password='133301',database='ry-vue')
cur = c.cursor()
cur.execute(\"UPDATE biz_order SET status='1', pay_time=NOW(), expire_time=DATE_ADD(NOW(), INTERVAL 30 DAY), verify_code=UPPER(SUBSTRING(MD5(RAND()),1,12)) WHERE order_id=$OID\")
c.commit()
cur.execute(\"SELECT verify_code FROM biz_order WHERE order_id=$OID\")
print(cur.fetchone()[0])
" > /tmp/c40_vc.txt
VC=$(cat /tmp/c40_vc.txt | tr -d ' \n')
echo "  [C] verifyCode=$VC"

# D) 会员A 调 /api/order/{oid}/scheme
SCHEME_RESP=$(curl -s -H "Authorization: Bearer $MTOK_A" $H/api/order/$OID/scheme)
echo "  [D] scheme resp: ${SCHEME_RESP:0:300}"
SCHEME=$(echo "$SCHEME_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('scheme',''))")
PAGE=$(echo "$SCHEME_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('page',''))")
RET_VC=$(echo "$SCHEME_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('verifyCode',''))")
ST_NAME=$(echo "$SCHEME_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('statusName',''))")
chk "D) 客人拿 Scheme URL" "weixin://dl/business" "$SCHEME"
chk "D+) 路径正确 (pages/merchant/verify/index)" "pages/merchant/verify/index" "$PAGE"
chk "D++) 返回的 verifyCode 与订单一致" "$VC" "$RET_VC"
chk "D+++) 状态名=待使用" "待使用" "$ST_NAME"

# E) 解析 Scheme URL → code/sid
QUERY=$(echo "$SCHEME" | python3 -c "
import sys, re
from urllib.parse import unquote, parse_qs
s = sys.stdin.read().strip()
i = s.find('?')
qs = s[i+1:]
m = re.search(r'query=([^&]+)', qs)
inner = unquote(m.group(1))
print(parse_qs(inner).get('code',[''])[0] + '|' + parse_qs(inner).get('sid',[''])[0])
")
EXTRACTED_CODE=$(echo $QUERY | cut -d'|' -f1)
EXTRACTED_SID=$(echo $QUERY | cut -d'|' -f2)
echo "  [E] 解析: code=$EXTRACTED_CODE sid=$EXTRACTED_SID"
[ "$EXTRACTED_CODE" = "$VC" ] && echo "  ✅ E) Scheme → verifyCode 解析正确" && PASS=$((PASS+1)) || { echo "  ❌ E) verifyCode 失配"; FAIL=$((FAIL+1)); }
[ "$EXTRACTED_SID" = "200" ] && echo "  ✅ E+) Scheme → storeId 解析正确" && PASS=$((PASS+1)) || { echo "  ❌ E+) storeId 失配"; FAIL=$((FAIL+1)); }

# F) 店员登录 + 切 store 200
SLOGIN=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"staff001","password":"admin123"}' $H/api/store/staff/login)
STOK=$(echo "$SLOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
[ -n "$STOK" ] && echo "  ✅ F) 店员登录" && PASS=$((PASS+1)) || { echo "  ❌ F) login: $SLOGIN"; FAIL=$((FAIL+1)); exit 1; }
curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STOK" -d '{"storeId":200}' $H/api/store/staff/switch-store > /dev/null

# G) 店员用解析出的 code/sid 调 /api/order/verify
V=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STOK" \
  -d "{\"storeId\":$EXTRACTED_SID,\"verifyCode\":\"$EXTRACTED_CODE\"}" $H/api/order/verify)
chk "G) 通过 Scheme 触发的 verify 成功" "操作成功" "$V"
ST=$(python3 -c "
import pymysql
c = pymysql.connect(host='127.0.0.1',port=3306,user='root',password='133301',database='ry-vue')
cur = c.cursor()
cur.execute(\"SELECT status FROM biz_order WHERE order_id=$OID\")
print(cur.fetchone()[0])
")
[ "$ST" = "2" ] && echo "  ✅ G+) 订单 status=2 (已核销)" && PASS=$((PASS+1)) || { echo "  ❌ G+) status=$ST"; FAIL=$((FAIL+1)); }

# H) 防越权：会员B 用自己 token 拿 会员A 的订单 scheme → 应被拒
MEM_B=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"c40_B_${TS}\",\"appid\":\"wx9e147c4e2151b123\",\"nickName\":\"c40_B\"}" $H/api/auth/login)
MTOK_B=$(echo "$MEM_B" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
# 重建一个已支付订单给 A，让 B 拿
ADD2=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK" \
  -d "{\"storeIds\":\"200\",\"typeCode\":\"GROUPON\",\"productName\":\"C40B_$TS\",\"price\":1,\"validityDays\":30,\"maxPerOrder\":1,\"stock\":10,\"productType\":\"0\",\"status\":\"0\",\"delFlag\":\"0\",\"sales\":0,\"sort\":0,\"bookingRequired\":0}" $H/api/product/add)
PID2=$(echo "$ADD2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('productId',0))")
ORD2=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK_A" \
  -d "{\"productId\":$PID2,\"num\":1}" $H/api/order)
OID2=$(echo "$ORD2" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data'); print(d.get('orderId',0) if isinstance(d, dict) else 0)" 2>/dev/null)
python3 -c "
import pymysql
c = pymysql.connect(host='127.0.0.1',port=3306,user='root',password='133301',database='ry-vue')
cur = c.cursor()
cur.execute(\"UPDATE biz_order SET status='1' WHERE order_id=$OID2\")
c.commit()
"
AUTH_RESP=$(curl -s -H "Authorization: Bearer $MTOK_B" $H/api/order/$OID2/scheme)
chk "H) 越权:B 拿 A 的订单 scheme 被拒" "无权查看" "$AUTH_RESP"

# I) 未登录调 scheme → 应 401
NO_AUTH=$(curl -s $H/api/order/$OID2/scheme)
chk "I) 未登录调 scheme 被拒" "401" "$NO_AUTH"

echo ""
echo "C40 结果: $PASS PASS / $FAIL FAIL"
[ $FAIL -eq 0 ] && echo "🎉 ALL PASS" || echo "❌ 有失败用例"
exit $FAIL
