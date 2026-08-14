#!/usr/bin/env bash
# E21 商品类型字典化端到端（P1 字典化验收）
# 验证:
#   A) admin GET /biz/productType/list 返回全部 status=0 字典
#   B) /biz/productType/appCreatable 仅返 app_can_create=1 的（小程序创建商品用）
#   C) 数据库种子数 = API 返回数（对账）
#   D) 字典新增 → 立即出现在 list
#   E) 字典 status=1 停用 → 立即从 status=0 列表消失
#   F) 按 typeCode 详情 GET /biz/productType/{code} 正确
#   G) 前端下拉 typeList 至少含 GROUPON/VOUCHER/TIMECARD（v-for 数据源覆盖业务主流）
set -e
H=http://127.0.0.1:8080
DB_CMD="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

ADMIN_TOK=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"admin","password":"admin123"}' $H/login | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")
[ ${#ADMIN_TOK} -gt 50 ] || { echo "FAIL: admin login"; exit 1; }

# 临时字典 typeCode（保证不污染 + 末位 cleanup）
TEST_CODE="E21_$(date +%s)_$$"

cleanup() {
  $DB_CMD -e "DELETE FROM biz_product_type WHERE type_code='$TEST_CODE';" 2>/dev/null || true
}
trap cleanup EXIT

echo "E21 商品类型字典化 smoke:"

# A) 全量列表 status=0
LIST_A=$(curl -s -H "Authorization: Bearer $ADMIN_TOK" "$H/biz/productType/list?pageNum=1&pageSize=20&status=0")
ROW_COUNT=$(echo "$LIST_A" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('rows',[])))")
[ "$ROW_COUNT" -ge 11 ] && echo "  ✅ A 全量 status=0 列表 (rows=$ROW_COUNT >= 11)" && PASS=$((PASS+1)) || { echo "  ❌ A rows=$ROW_COUNT want >= 11"; FAIL=$((FAIL+1)); }
chk "A 包含 GROUPON" "GROUPON" "$LIST_A"
chk "A 包含 VOUCHER" "VOUCHER" "$LIST_A"
chk "A 包含 TIMECARD" "TIMECARD" "$LIST_A"
chk "A 包含 STORED_CARD" "STORED_CARD" "$LIST_A"
chk "A 包含 COMBO" "COMBO" "$LIST_A"
chk "A 包含 BILL" "BILL" "$LIST_A"
chk "A 包含 BOOKING" "BOOKING" "$LIST_A"

# B) appCreatable 端点
APP=$(curl -s -H "Authorization: Bearer $ADMIN_TOK" "$H/biz/productType/appCreatable")
APP_CODES=$(echo "$APP" | python3 -c "import sys,json; print(','.join(sorted(t.get('typeCode','') for t in json.load(sys.stdin).get('data',[]))))")
# appCanCreate=1 应该是 GROUPON/VOUCHER/TIMECARD/STORED_CARD/PERIOD_CARD/HUIXIANG_CARD/COMBO/BILL/BOOKING = 9
APP_COUNT=$(echo "$APP" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('data',[])))")
[ "$APP_COUNT" -eq 9 ] && echo "  ✅ B appCreatable 数量=9 (appCanCreate=1)" && PASS=$((PASS+1)) || { echo "  ❌ B appCount=$APP_COUNT want 9, codes=$APP_CODES"; FAIL=$((FAIL+1)); }
echo "$APP_CODES" | grep -q "PRESALE" && { echo "  ❌ B 不应包含 PRESALE (appCanCreate=0)"; FAIL=$((FAIL+1)); } || { echo "  ✅ B 排除 PRESALE (appCanCreate=0)"; PASS=$((PASS+1)); }
echo "$APP_CODES" | grep -q "PICKUP_VOUCHER" && { echo "  ❌ B 不应包含 PICKUP_VOUCHER (appCanCreate=0)"; FAIL=$((FAIL+1)); } || { echo "  ✅ B 排除 PICKUP_VOUCHER (appCanCreate=0)"; PASS=$((PASS+1)); }

# C) 数据库种子数与 API 返回数对账
DB_COUNT=$($DB_CMD -N -e "SELECT COUNT(*) FROM biz_product_type WHERE status='0';" 2>/dev/null)
[ "$DB_COUNT" = "$ROW_COUNT" ] && echo "  ✅ C SQL 种子数=$DB_COUNT = API rows=$ROW_COUNT" && PASS=$((PASS+1)) || { echo "  ❌ C SQL=$DB_COUNT API=$ROW_COUNT"; FAIL=$((FAIL+1)); }

# D) 新增字典
ADD=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $ADMIN_TOK" \
  -d "{\"typeCode\":\"$TEST_CODE\",\"typeName\":\"E21测试字典\",\"typeDesc\":\"smoke\",\"sort\":99,\"status\":\"0\",\"appCanCreate\":1}" \
  $H/biz/productType)
chk "D 新增字典 HTTP 200" "操作成功" "$ADD"
LIST_AFTER_ADD=$(curl -s -H "Authorization: Bearer $ADMIN_TOK" "$H/biz/productType/list?pageNum=1&pageSize=30&status=0")
echo "$LIST_AFTER_ADD" | grep -q "$TEST_CODE" && echo "  ✅ D 新字典立即出现在 list" && PASS=$((PASS+1)) || { echo "  ❌ D 新字典未出现"; FAIL=$((FAIL+1)); }

# E) 停用后立刻从 status=0 列表消失
$DB_CMD -e "UPDATE biz_product_type SET status='1' WHERE type_code='$TEST_CODE';" 2>/dev/null
LIST_DISABLED=$(curl -s -H "Authorization: Bearer $ADMIN_TOK" "$H/biz/productType/list?pageNum=1&pageSize=30&status=0")
echo "$LIST_DISABLED" | grep -q "$TEST_CODE" && { echo "  ❌ E 停用后仍出现"; FAIL=$((FAIL+1)); } || { echo "  ✅ E status=1 停用后从 status=0 列表消失"; PASS=$((PASS+1)); }

# F) 按 typeCode 详情
INFO=$(curl -s -H "Authorization: Bearer $ADMIN_TOK" "$H/biz/productType/GROUPON")
chk "F GROUPON 详情 typeName=团购套餐" "团购套餐" "$INFO"

# G) 验证 8-14 计划里"前端下拉"数据源覆盖：核对 SELECT 出来的 typeCode 集合
G_NEEDED="GROUPON,VOUCHER,TIMECARD,STORED_CARD,COMBO,BILL,BOOKING"
MISSING=""
for code in GROUPON VOUCHER TIMECARD STORED_CARD COMBO BILL BOOKING; do
  echo "$LIST_A" | grep -q "$code" || MISSING="$MISSING $code"
done
[ -z "$MISSING" ] && echo "  ✅ G 前端下拉数据源覆盖 7 种核心 typeCode" && PASS=$((PASS+1)) || { echo "  ❌ G 缺失: $MISSING"; FAIL=$((FAIL+1)); }

# H) admin PUT 修改字典元数据
$DB_CMD -e "UPDATE biz_product_type SET status='0' WHERE type_code='$TEST_CODE';" 2>/dev/null
MOD=$(curl -s -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $ADMIN_TOK" \
  -d "{\"typeCode\":\"$TEST_CODE\",\"typeName\":\"E21改名\",\"typeDesc\":\"smoke改\",\"sort\":99,\"status\":\"0\",\"appCanCreate\":1}" \
  $H/biz/productType)
chk "H PUT 改字典 HTTP 200" "操作成功" "$MOD"
INFO_MOD=$(curl -s -H "Authorization: Bearer $ADMIN_TOK" "$H/biz/productType/$TEST_CODE")
chk "H 改后 typeName=E21改名" "E21改名" "$INFO_MOD"

# I) DELETE 清理
DEL=$(curl -s -X DELETE -H "Authorization: Bearer $ADMIN_TOK" "$H/biz/productType/$TEST_CODE")
chk "I DELETE 字典 HTTP 200" "操作成功" "$DEL"
LIST_AFTER_DEL=$(curl -s -H "Authorization: Bearer $ADMIN_TOK" "$H/biz/productType/list?pageNum=1&pageSize=30&status=0")
echo "$LIST_AFTER_DEL" | grep -q "$TEST_CODE" && { echo "  ❌ I 删后仍出现"; FAIL=$((FAIL+1)); } || { echo "  ✅ I 删除生效"; PASS=$((PASS+1)); }

echo ""
echo "E21 smoke: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
