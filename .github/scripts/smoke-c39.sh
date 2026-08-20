#!/usr/bin/env bash
# C39 「微信扫一扫直达核销」端到端 smoke
# 链路: 商家生成核销码 → 调 /api/store/staff/verify/qrcode-scheme 拿 Scheme URL →
#       模拟微信扫到 Scheme URL → 后端 verify 链路

# fixture 自备（见 .github/scripts/lib/smoke-fixture.sh）
# 背景：62 smoke 串行跑会互相污染（改密码/耗库存/覆盖 openid），造成假 FAIL
source "$(dirname "$0")/lib/smoke-fixture.sh"
fx_ensure_mock_on
fx_reset_staff_pwd staff001

set -e
H=http://127.0.0.1:8080
DB="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"
LOG=/tmp/jrun-c39.log
TS=$(date +%s | tail -c 7)
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:300})"; FAIL=$((FAIL+1)); fi
}

echo "C39 「微信扫一扫直达核销」 smoke:"

# A) 商家创建商品
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"smoke_c39_${TS}\",\"appid\":\"wx9e147c4e2151b123\",\"nickName\":\"smoke_c39_mer\"}" $H/api/auth/login)
# MTOK 原先用「会员 token」冒充商家建商品；V5-1 给 /api/product/add 加了
# @RequireRole({OWNER,MANAGER}) 后必须用真实 OWNER token（会员建商品本就该 403）。
MTOK=$(fx_login_owner)
ADD=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK" \
  -d "{\"storeIds\":\"200\",\"typeCode\":\"GROUPON\",\"productName\":\"C39_$TS\",\"price\":1,\"validityDays\":30,\"maxPerOrder\":1,\"stock\":10,\"productType\":\"0\",\"status\":\"0\",\"delFlag\":\"0\",\"sales\":0,\"sort\":0,\"bookingRequired\":0}" $H/api/product/add)
PID=$(echo "$ADD" | python3 -c "import sys,json; print(json.load(sys.stdin).get('productId',0))")
[ -n "$PID" ] && [ "$PID" -gt 0 ] && echo "  ✅ A) 创建商品 id=$PID" && PASS=$((PASS+1)) || { echo "  ❌ A) add: $ADD"; FAIL=$((FAIL+1)); exit 1; }

# B) 会员下单
JSCODE="c39_${TS}"
MEM=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE\",\"appid\":\"wx9e147c4e2151b123\",\"nickName\":\"c39_mem\"}" $H/api/auth/login)
MTOK_MEM=$(echo "$MEM" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
ORD=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK_MEM" \
  -d "{\"productId\":$PID,\"num\":1}" $H/api/order)
OID=$(echo "$ORD" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data'); print(d.get('orderId',0) if isinstance(d, dict) else 0)" 2>/dev/null)
[ -n "$OID" ] && [ "$OID" -gt 0 ] && echo "  ✅ B) 下单成功 orderId=$OID" && PASS=$((PASS+1)) || { echo "  ❌ B) order: $ORD"; FAIL=$((FAIL+1)); exit 1; }

# C) prepay + 标已支付
curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK_MEM" $H/api/order/prepay/$OID > /dev/null
$DB -e "UPDATE biz_order SET status='1', pay_time=now(), expire_time=DATE_ADD(NOW(), INTERVAL 30 DAY) WHERE order_id=$OID;" 2>/dev/null
VC=$($DB -N -e "SELECT verify_code FROM biz_order WHERE order_id=$OID;" 2>/dev/null | head -1)
[ -z "$VC" ] || [ "$VC" = "NULL" ] && $DB -e "UPDATE biz_order SET verify_code=UPPER(SUBSTRING(MD5(RAND()),1,12)) WHERE order_id=$OID;" 2>/dev/null && VC=$($DB -N -e "SELECT verify_code FROM biz_order WHERE order_id=$OID;" 2>/dev/null | head -1)
echo "  [C] verifyCode=$VC"

# D) 店员登录 + 切到 store 200
SLOGIN=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"staff001","password":"admin123"}' $H/api/store/staff/login)
STOK=$(echo "$SLOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
[ -n "$STOK" ] && echo "  ✅ D) 店员登录" && PASS=$((PASS+1)) || { echo "  ❌ D) login: $SLOGIN"; FAIL=$((FAIL+1)); exit 1; }
curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STOK" -d '{"storeId":200}' $H/api/store/staff/switch-store > /dev/null

# E) 调 /api/store/staff/verify/qrcode-scheme 生成 Scheme URL
SCHEME_RESP=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STOK" \
  -d "{\"storeId\":200,\"verifyCode\":\"$VC\",\"shorten\":true}" $H/api/store/staff/verify/qrcode-scheme)
echo "  [E] scheme resp: ${SCHEME_RESP:0:300}"
SCHEME=$(echo "$SCHEME_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('scheme',''))")
SHORT=$(echo "$SCHEME_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('shortUrl',''))")
chk "E) 生成 Scheme URL" "weixin://dl/business" "$SCHEME"
chk "E+) 短链已生成" "Y" "$([ -n "$SHORT" ] && echo Y || echo N)"
echo "  [E] scheme=$SCHEME"
echo "  [E] short=$SHORT"

# F) Scheme URL 解码后看 page 和 query 拼对了
PAGE=$(echo "$SCHEME" | python3 -c "import sys,urllib.parse; s=sys.stdin.read().strip(); 
from urllib.parse import unquote, parse_qs
# 去掉 weixin://dl/business/? 前缀
i = s.find('?')
if i<0: print(''); exit()
qs = s[i+1:]
params = parse_qs(qs)
print(params.get('path', [''])[0])")
chk "F) Scheme 路径正确 (pages/merchant/verify/index)" "pages/merchant/verify/index" "$PAGE"

QUERY=$(echo "$SCHEME" | python3 -c "import sys; s=sys.stdin.read().strip()
from urllib.parse import unquote, parse_qs
i = s.find('?')
qs = s[i+1:]
params = parse_qs(qs)
print(params.get('query', [''])[0])")
chk "F+) Scheme query 含 verifyCode" "$VC" "$QUERY"
chk "F++) Scheme query 含 sid=200" "sid=200" "$QUERY"

# G) mock 微信行为：从 Scheme 拿到 query 串 → 解出 code/sid → 调 /api/order/verify（与 verify 页 onLoad 走同一链路）
EXTRACTED_CODE=$(echo "$QUERY" | python3 -c "import sys; from urllib.parse import parse_qs; print(parse_qs(sys.stdin.read()).get('code',[''])[0])")
EXTRACTED_SID=$(echo "$QUERY" | python3 -c "import sys; from urllib.parse import parse_qs; print(parse_qs(sys.stdin.read()).get('sid',[''])[0])")
echo "  [G] 模拟微信解析: code=$EXTRACTED_CODE sid=$EXTRACTED_SID"
[ "$EXTRACTED_CODE" = "$VC" ] && echo "  ✅ G) Scheme → verifyCode 解析正确" && PASS=$((PASS+1)) || { echo "  ❌ G) verifyCode 失配"; FAIL=$((FAIL+1)); }
[ "$EXTRACTED_SID" = "200" ] && echo "  ✅ G+) Scheme → storeId 解析正确" && PASS=$((PASS+1)) || { echo "  ❌ G+) storeId 失配"; FAIL=$((FAIL+1)); }

# H) 用解析出的 code/sid 调 /api/order/verify（与小程序 onLoad → onSubmit 链路一致）
V=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STOK" \
  -d "{\"storeId\":$EXTRACTED_SID,\"verifyCode\":\"$EXTRACTED_CODE\"}" $H/api/order/verify)
chk "H) 通过 Scheme 触发的 verify 成功" "操作成功" "$V"
ST=$($DB -N -e "SELECT status FROM biz_order WHERE order_id=$OID;" 2>/dev/null | head -1)
[ "$ST" = "2" ] && echo "  ✅ H+) 订单 status=2 (已核销)" && PASS=$((PASS+1)) || { echo "  ❌ H+) status=$ST"; FAIL=$((FAIL+1)); }

# I) 防越权：店员 A 在 store 1 调 store 200 的 scheme → 应 401
SLOGIN2=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"staff001","password":"admin123"}' $H/api/store/staff/login)
STOK2=$(echo "$SLOGIN2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
# 不切 store，默认可能在 store 1；试 sid=999 越权
AUTH=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STOK2" \
  -d "{\"storeId\":999,\"verifyCode\":\"$VC\"}" $H/api/store/staff/verify/qrcode-scheme)
chk "I) 越权 storeId=999 被拒" "无权操作" "$AUTH"

# J) 关键日志断言：WxMaService mock generateScheme 调用
sleep 1
LOG_HIT=$(grep "mock generateScheme" $LOG 2>/dev/null | tail -1)
[ -n "$LOG_HIT" ] && echo "  ✅ J) WxMaService.generateScheme 调用记录:" && PASS=$((PASS+1)) && echo "     $LOG_HIT" | head -c 200 || { echo "  ❌ J) 未找到 generateScheme 日志"; FAIL=$((FAIL+1)); }

echo ""
echo "C39 结果: $PASS PASS / $FAIL FAIL"
[ $FAIL -eq 0 ] && echo "🎉 ALL PASS" || echo "❌ 有失败用例"
