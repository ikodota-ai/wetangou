#!/usr/bin/env bash
# subitem 创建 E2E smoke test
# 验证:
#   A) POST /biz/productSubitem/group 创建 group → 200
#   B) POST /biz/productSubitem/subitem 创建 subitem → 200
#   C) GET /api/product/{id} (GROUPON) 返新创建的 subitemGroups
#   D) DELETE 清理（不污染 seed）
#   E) no auth → 401
#
# 前置: 后端在 8080 运行, admin/admin123 可登录, MySQL 可直连查最新 groupId
# 用法: bash .github/scripts/smoke-subitem.sh
set -e

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
USER="${ADMIN_USER:-admin}"
PASS="${ADMIN_PASS:-admin123}"
PRODUCT_ID="${PRODUCT_ID:-2000}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-133301}"
DB_NAME="${DB_NAME:-ry-vue}"
MYSQL="${MYSQL:-/usr/local/mysql/bin/mysql}"

GROUP_ID=""
SUB_ID=""

cleanup() {
  if [ -n "$SUB_ID" ]; then
    curl -s -X DELETE "$BASE_URL/biz/productSubitem/subitem/$SUB_ID" -H "Authorization: $TOKEN" >/dev/null 2>&1 || true
  fi
  if [ -n "$GROUP_ID" ]; then
    curl -s -X DELETE "$BASE_URL/biz/productSubitem/group/$GROUP_ID" -H "Authorization: $TOKEN" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# login
TOKEN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"username\":\"$USER\",\"password\":\"$PASS\"}" \
  "$BASE_URL/login" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
[ -n "$TOKEN" ] || { echo "FAIL: login no token"; exit 1; }

# A) 创建 group（DB 查最新 groupId，因为 controller 返 rows 不返 id）
RESP=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: $TOKEN" \
  -d "{\"productId\":$PRODUCT_ID,\"groupName\":\"SMOKE_TEST_GROUP\",\"pickRule\":\"PICK\",\"sort\":99}" \
  "$BASE_URL/biz/productSubitem/group")
echo "[A] POST /group: $RESP"
CODE=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',0))")
[ "$CODE" = "200" ] || { echo "FAIL: create group code=$CODE"; exit 1; }
sleep 0.3
GROUP_ID=$($MYSQL -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -N -e "SELECT group_id FROM biz_product_subitem_group WHERE product_id=$PRODUCT_ID AND group_name='SMOKE_TEST_GROUP' ORDER BY group_id DESC LIMIT 1" 2>/dev/null)
[ -n "$GROUP_ID" ] || { echo "FAIL: groupId not found in DB"; exit 1; }
echo "  [A] OK: groupId=$GROUP_ID"

# B) 创建 subitem
RESP=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: $TOKEN" \
  -d "{\"groupId\":$GROUP_ID,\"productId\":$PRODUCT_ID,\"subitemName\":\"SMOKE_TEST_SUB\",\"quantity\":1,\"price\":99.99,\"sort\":1}" \
  "$BASE_URL/biz/productSubitem/subitem")
echo "[B] POST /subitem: $RESP"
CODE=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',0))")
[ "$CODE" = "200" ] || { echo "FAIL: create subitem code=$CODE"; exit 1; }
sleep 0.3
SUB_ID=$($MYSQL -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -N -e "SELECT subitem_id FROM biz_product_subitem WHERE group_id=$GROUP_ID AND subitem_name='SMOKE_TEST_SUB' ORDER BY subitem_id DESC LIMIT 1" 2>/dev/null)
[ -n "$SUB_ID" ] || { echo "FAIL: subitemId not found in DB"; exit 1; }
echo "  [B] OK: subitemId=$SUB_ID"

# C) GET /api/product/{id} 验 subitemGroups 含新建
RESP=$(curl -s "$BASE_URL/api/product/$PRODUCT_ID")
echo "[C] /api/product/$PRODUCT_ID: $(echo $RESP | head -c 100)..."
HAS_GROUP=$(echo "$RESP" | python3 -c "
import sys, json
d = json.load(sys.stdin)
groups = d.get('subitemGroups') or d.get('data', {}).get('subitemGroups', [])
names = [g.get('groupName') for g in groups]
print('SMOKE_TEST_GROUP' in names)
")
[ "$HAS_GROUP" = "True" ] || { echo "FAIL: SMOKE_TEST_GROUP not in subitemGroups"; exit 1; }
echo "  [C] OK: SMOKE_TEST_GROUP found in subitemGroups"

# D) DELETE 由 trap 自动清理

# E) no auth
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/biz/productSubitem/group" -X POST -H "Content-Type: application/json" -d "{\"productId\":$PRODUCT_ID}")
[ "$CODE" = "401" ] || { echo "FAIL: no auth got $CODE (expect 401)"; exit 1; }
echo "  [E] OK: no auth -> 401"

echo "subitem smoke test PASSED"
