#!/usr/bin/env bash
# V2.6.1 orderQrcode/orderQrcodeData 太阳码端点 smoke
# 期望：
#   - /qrcode-data 端点返 JSON {dataUrl, verifyCode, scene, orderId}
#   - scene 格式 verify:{orderId}:{verifyCode}
#   - dataUrl 是 data:image/png;base64, 开头
#   - 仅本人订单可访问（他人 → 错误）
#   - 原始 /qrcode 端点返 image/png 字节
set -u
H=http://127.0.0.1:8080
PASS=0; FAIL=0

# 用 member 1000197（订单 999178 归属人）
login() {
  curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"code\":\"$1\",\"nickName\":\"c52\",\"appid\":\"wx9e147c4e2151b123\"}" \
    $H/api/auth/login | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))"
}

check() {
  local label="$1" expected="$2" got="$3"
  if [ "$expected" = "$got" ]; then echo "  ✅ $label (=$got)"; PASS=$((PASS+1))
  else echo "  ❌ $label  expect=$expected got=$got"; FAIL=$((FAIL+1)); fi
}

# 1) login → member 1000197
TOKEN=$(login c52_1000197)
echo "member 1000197 token len: ${#TOKEN}"
[ ${#TOKEN} -gt 100 ] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))

# 2) /qrcode-data → 200 + dataUrl
RES=$(curl -s -H "X-App-Id: wx9e147c4e2151b123" -H "Authorization: Bearer $TOKEN" \
  $H/api/order/999178/qrcode-data)
SCENE=$(echo "$RES" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['scene'])")
DATAURL=$(echo "$RES" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['dataUrl'][:22])")
VERIFY=$(echo "$RES" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['verifyCode'])")
ORDERID=$(echo "$RES" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['orderId'])")
SIZE=$(echo "$RES" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['size'])")
check "scene 格式 verify:orderId:code" "verify:999178:$VERIFY" "$SCENE"
check "dataUrl 前缀 data:image/png;base64," "data:image/png;base64," "$DATAURL"
check "orderId 999178" "999178" "$ORDERID"
check "size > 0" "true" "$([ "$SIZE" -gt 0 ] && echo true || echo false)"

# 3) /qrcode → 200 + image/png
HTTP=$(curl -s -o /tmp/qr.png -w "%{http_code}" -H "X-App-Id: wx9e147c4e2151b123" -H "Authorization: Bearer $TOKEN" \
  $H/api/order/999178/qrcode)
check "原始 /qrcode 端点 HTTP 200" "200" "$HTTP"
SZ=$(stat -f%z /tmp/qr.png 2>/dev/null || echo 0)
check "原始 /qrcode PNG 字节>0" "true" "$([ "$SZ" -gt 0 ] && echo true || echo false)"

# 4) 别人订单 → 错误
TOKEN2=$(login c52_other)
RES4=$(curl -s -H "X-App-Id: wx9e147c4e2151b123" -H "Authorization: Bearer $TOKEN2" \
  $H/api/order/999178/qrcode-data)
CODE4=$(echo "$RES4" | python3 -c "import sys,json; print(json.load(sys.stdin)['code'])")
check "他人订单 → 业务层 500" "500" "$CODE4"

# 5) 未登录 → 错误
RES5=$(curl -s -H "X-App-Id: wx9e147c4e2151b123" \
  $H/api/order/999178/qrcode-data)
CODE5=$(echo "$RES5" | python3 -c "import sys,json; print(json.load(sys.stdin)['code'])")
check "未登录 → 业务层 500" "500" "$CODE5"

echo "============================="
echo "V2.6.1 qrcode smoke: $PASS pass / $FAIL fail"
[ "$FAIL" = "0" ]
