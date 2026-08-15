#!/usr/bin/env bash
# C28 /api/pay/notify 异常处理端到端
# 验证:
#   A) /api/pay/notify 缺 resource → {code:FAIL, message:缺少resource}
#   B) /api/pay/notify 资源齐全 (mock 模式无 key) → {code:FAIL, message:未配置 APIv3 密钥}
#   C) /api/pay/notify/1 同 B
#   D) /api/pay/notify/1 缺 resource → {code:FAIL, message:缺少resource}
#   E) notify 旧版入口: 缺 out_trade_no + 有 resource → resolve 回退默认商户=1 + 解密失败
#   F) notify 错 HTTP method (GET) → 405/404
# 前置: 后端 8080 在跑; mock 模式 (wx.pay.mockEnabled=true 关闭后 prepay 走真实, 当前 mockEnabled 没明确开关)
#  注: c2/c4 已验 mock 模式 prepay, 但 notify 链路 0 覆盖
set -e
H=http://127.0.0.1:8080

PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

echo "C28 /api/pay/notify 异常处理 smoke:"

# A) 缺 resource
A=$(curl -s -X POST $H/api/pay/notify -H "Content-Type: application/json" -d '{}')
chk "A) 缺 resource" "缺少resource" "$A"

# B) 资源齐全 (mock 模式无 APIv3 key)
B=$(curl -s -X POST $H/api/pay/notify -H "Content-Type: application/json" -d '{"resource":{"associated_data":"x","nonce":"y","ciphertext":"z"}}')
chk "B) 资源齐全 mock 模式" "未配置 APIv3 密钥" "$B"
echo "$B" | grep -q '"code":"FAIL"' && echo "  ✅ B+) code=FAIL" && PASS=$((PASS+1)) || { echo "  ❌ B+) code: ${B:0:200}"; FAIL=$((FAIL+1)); }

# C) /api/pay/notify/1
C=$(curl -s -X POST $H/api/pay/notify/1 -H "Content-Type: application/json" -d '{"resource":{"associated_data":"x","nonce":"y","ciphertext":"z"}}')
chk "C) notify/1 mock 模式" "未配置 APIv3 密钥" "$C"

# D) /api/pay/notify/1 缺 resource
D=$(curl -s -X POST $H/api/pay/notify/1 -H "Content-Type: application/json" -d '{}')
chk "D) notify/1 缺 resource" "缺少resource" "$D"

# E) notify 旧版入口: 有 out_trade_no 但 mock
E=$(curl -s -X POST $H/api/pay/notify -H "Content-Type: application/json" -d '{"out_trade_no":"P2024NOTEXIST","resource":{"associated_data":"a","nonce":"b","ciphertext":"c"}}')
chk "E) notify 旧版 + out_trade_no 不存在" "未配置 APIv3 密钥" "$E"

# F) GET 错方法: 业务上用 code=500 包装 (RuoYi 全局异常)
F=$(curl -s $H/api/pay/notify)
if echo "$F" | grep -qE "GET.*not supported"; then echo "  ✅ F) GET /notify 业务拒绝"; PASS=$((PASS+1)); else echo "  ❌ F) GET /notify: $F"; FAIL=$((FAIL+1)); fi

echo "C28 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
