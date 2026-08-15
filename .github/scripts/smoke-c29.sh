#!/usr/bin/env bash
# C29 GlobalExceptionHandler 修 405 smoke: 错 HTTP method 应返 405 而非 200
# 验证 (C28 摸出的 known limitation 修复):
#   A) GET /api/pay/notify → HTTP 405 (PostMapping only)
#   B) GET /api/auth/login → HTTP 405
#   C) GET /api/auth/logout → HTTP 405
#   D) GET /api/booking → HTTP 405 (PostMapping)
#   E) GET /api/store/staff/login → HTTP 405
#   F) GET /api/member/profile → HTTP 200 (GetMapping 合法, 应 200)
#   G) GET /api/distributor/center → HTTP 200 (GetMapping 合法, 应 200)
#   H) POST /api/pay/notify → 200 (业务错数据) — 不影响 200 路径
# 前置: 后端 8080 在跑
set -e
H=http://127.0.0.1:8080
PASS=0; FAIL=0
chk_code() { local n="$1" want="$2" got="$3"
  [ "$got" = "$want" ] && { echo "  ✅ $n (HTTP $got)"; PASS=$((PASS+1)); } || { echo "  ❌ $n want $want got $got"; FAIL=$((FAIL+1)); }
}

echo "C29 GlobalExceptionHandler 修 405 smoke:"

# 错方法 → 405
for ep in /api/pay/notify /api/auth/login /api/auth/logout /api/booking /api/store/staff/login; do
  C=$(curl -s -o /dev/null -w "%{http_code}" -X GET $H$ep)
  chk_code "GET $ep → 405" 405 $C
done

# 合法方法 → 200
for ep in /api/member/profile /api/distributor/center; do
  C=$(curl -s -o /dev/null -w "%{http_code}" -X GET $H$ep)
  chk_code "GET $ep → 200" 200 $C
done

# 200 路径仍工作 (业务错数据)
H_RESP=$(curl -s -o /dev/null -w "%{http_code}" -X POST $H/api/pay/notify -H "Content-Type: application/json" -d '{}')
chk_code "POST /api/pay/notify (业务)" 200 $H_RESP

echo "C29 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
