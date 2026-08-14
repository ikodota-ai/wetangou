#!/usr/bin/env bash
# C1 代理商佣金概览 smoke test
# 验证：
#   1) agentId=1（1 商户）→ total=62.80, byMerchant=1 行
#   2) agentId=999（无商户）→ total=0, byMerchant=0 行（防跨租户泄漏）
#   3) 端点需要鉴权（无 token → 401）
#
# 前置：后端在 8080 运行，admin/admin123 可登录
# 用法：bash .github/scripts/smoke-c1.sh
set -e

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
USER="${ADMIN_USER:-admin}"
PASS="${ADMIN_PASS:-admin123}"

# 1) login
TOKEN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"username\":\"$USER\",\"password\":\"$PASS\"}" \
  "$BASE_URL/login" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
[ -n "$TOKEN" ] || { echo "FAIL: login no token"; exit 1; }

# 2) agentId=1
RESP=$(curl -s "$BASE_URL/biz/agent/commission/summary?agentId=1" -H "Authorization: $TOKEN")
echo "[A] agentId=1: $(echo $RESP | head -c 200)"
TOTAL=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['totalAmount'])")
ROWS=$(echo "$RESP" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data']['byMerchant']))")
[ "$TOTAL" = "62.8" ] || { echo "FAIL: agentId=1 totalAmount=$TOTAL (expect 62.8)"; exit 1; }
[ "$ROWS" = "1" ] || { echo "FAIL: agentId=1 byMerchant rows=$ROWS (expect 1)"; exit 1; }
echo "  [A] OK: total=62.8, byMerchant=1 row"

# 3) agentId=999 (no merchants) — 跨租户防泄漏
RESP=$(curl -s "$BASE_URL/biz/agent/commission/summary?agentId=999" -H "Authorization: $TOKEN")
echo "[B] agentId=999: $(echo $RESP | head -c 200)"
TOTAL=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['totalAmount'])")
ROWS=$(echo "$RESP" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data']['byMerchant']))")
[ "$TOTAL" = "0.0" ] || { echo "FAIL: agentId=999 totalAmount=$TOTAL (expect 0.0)"; exit 1; }
[ "$ROWS" = "0" ] || { echo "FAIL: agentId=999 byMerchant rows=$ROWS (expect 0, 跨租户泄漏!)"; exit 1; }
echo "  [B] OK: total=0.0, byMerchant=0 row (no cross-tenant leak)"

# 4) no auth
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/biz/agent/commission/summary?agentId=1")
[ "$CODE" = "401" ] || { echo "FAIL: no auth got $CODE (expect 401)"; exit 1; }
echo "  [C] OK: no auth -> 401"

echo "C1 smoke test PASSED"
