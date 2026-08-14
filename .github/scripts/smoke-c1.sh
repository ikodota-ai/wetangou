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

# 清理 E15/E16 smoke fixture 中可能污染 c1 断言的数据 (commission 999x + commission 999x 各自 80)
if command -v /usr/local/mysql/bin/mysql >/dev/null 2>&1; then
  /usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue -e "DELETE FROM biz_commission WHERE commission_id IN (999201, 999202);" 2>/dev/null || true
fi

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

# 5) 恢复 E15/E16 fixture（c1 开头删了 commission 999x 防止污染 c1 总额断言）
#    c1 测完把 commission fixture 还回去，让 E15 后续可正常跑
if command -v /usr/local/mysql/bin/mysql >/dev/null 2>&1; then
  /usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue <<'SQL' 2>/dev/null || true
INSERT INTO biz_commission (commission_id, merchant_id, distributor_id, order_id, store_id, amount, rate, status, create_time) VALUES
  (999201, 2, 1, 1, 1, 50.00, 0.10, '0', NOW()),
  (999202, 1, 1, 1, 1, 80.00, 0.10, '0', NOW())
ON DUPLICATE KEY UPDATE merchant_id=VALUES(merchant_id), amount=VALUES(amount), status=VALUES(status);
SQL
fi

echo "C1 smoke test PASSED"
