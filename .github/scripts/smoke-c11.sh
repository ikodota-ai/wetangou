#!/usr/bin/env bash
# C11 商家端商品创建端到端（PRD §8 主流程）
# 验证:
#   A) 员工账号密码登录 /api/merchant/staff/login
#   B) /api/merchant/staff/me 拿员工 + 门店列表
#   C) /api/product/category/list?storeId=... 拿分类下拉
#   D) /biz/productType/appCreatable 拿 typeCode 字典
#   E) POST /api/product/add 创建 GROUPON 商品，merchantId 强制覆盖为员工所属
#   F) 创建 VOUCHER 商品，验证 typeCode 业务字段不冲突
#   G) 缺 storeIds 应被拒
#   H) 防越权：员工不能给非自己 merchantId 的门店建（merchantId 强制覆盖）
#   I) 创建后 productId 真实落库 + biz_product.typeCode 与请求一致

# fixture 自备（见 .github/scripts/lib/smoke-fixture.sh）
# 背景：62 smoke 串行跑会互相污染（改密码/耗库存/覆盖 openid），造成假 FAIL
source "$(dirname "$0")/lib/smoke-fixture.sh"
fx_ensure_mock_on
fx_reset_staff_pwd owner_c43
fx_fix_staff_user_type owner_c43

set -e
H=http://127.0.0.1:8080
DB_CMD="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 --default-character-set=utf8mb4 ry-vue"
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

# A) 员工登录
# 用 owner_c43（OWNER）而不是 staff001（STAFF）：本脚本 E/F/G/H 用例要调
# /api/product/add，而它是 @RequireRole({OWNER,MANAGER})。STAFF 建商品本就该 403。
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"owner_c43","password":"admin123"}' \
  $H/api/merchant/staff/login)
STAFF_TOK=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
STAFF_MID=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('merchantId',0))")
[ ${#STAFF_TOK} -gt 50 ] && [ "$STAFF_MID" -gt 0 ] || { echo "FAIL: staff login: $LOGIN"; exit 1; }
echo "[A] staff login OK merchantId=$STAFF_MID"

# B) /me
ME=$(curl -s -H "Authorization: Bearer $STAFF_TOK" $H/api/merchant/staff/me)
chk "B me 返回 storeId" "storeId" "$ME"
# 解析一个 storeId（取主 storeId）
STORE_ID=$(echo "$ME" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data',{}); print(d.get('storeId') or (d.get('stores') or [{}])[0].get('storeId') or 0)")
[ "$STORE_ID" -gt 0 ] || { echo "FAIL: extract storeId from me: $ME"; exit 1; }
echo "[B] me storeId=$STORE_ID"

# C) 分类下拉（mini 端实际用法：不传 storeId 拿平台级 NULL 分类；传 storeId 拿门店专属）
CATS=$(curl -s "$H/api/product/category/list")
chk "C 平台级分类下拉返回 美食" "10000" "$CATS"

# D) typeCode 字典
TYPES=$(curl -s $H/biz/productType/appCreatable)
chk "D appCreatable 包含 GROUPON" "GROUPON" "$TYPES"
chk "D appCreatable 包含 VOUCHER" "VOUCHER" "$TYPES"

# E) 创建 GROUPON 商品
P1_PAYLOAD=$(python3 -c "import json; print(json.dumps({
  'typeCode':'GROUPON','productName':'C11_GROUPO烟测套餐',
  'subtitle':'smoke 套餐','storeId':$STORE_ID,'storeIds':'$STORE_ID',
  'categoryId':10000,'price':99.50,'marketPrice':128.00,
  'validityDays':30,'bookingRequired':0,'stock':100,
  'limitPerUser':0,'maxPerOrder':1,'notice':'smoke'
}))")
P1=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STAFF_TOK" \
  -d "$P1_PAYLOAD" $H/api/product/add)
echo "  [E] /add resp: $(echo $P1 | head -c 200)"
P1_ID=$(echo "$P1" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('productId') or d.get('data',{}).get('productId') or 0)")
[ "$P1_ID" -gt 0 ] && echo "  ✅ E GROUPON 创建成功 productId=$P1_ID" && PASS=$((PASS+1)) || { echo "  ❌ E 创建失败: $P1"; FAIL=$((FAIL+1)); }
# 校验落库
if [ "$P1_ID" -gt 0 ]; then
  P1_DB_TC=$($DB_CMD -N -e "SELECT type_code FROM biz_product WHERE product_id=$P1_ID;" 2>/dev/null)
  P1_DB_MID=$($DB_CMD -N -e "SELECT merchant_id FROM biz_product WHERE product_id=$P1_ID;" 2>/dev/null)
  [ "$P1_DB_TC" = "GROUPON" ] && echo "  ✅ E 落库 typeCode=GROUPON" && PASS=$((PASS+1)) || { echo "  ❌ E db typeCode=$P1_DB_TC"; FAIL=$((FAIL+1)); }
  [ "$P1_DB_MID" = "$STAFF_MID" ] && echo "  ✅ E 落库 merchantId 强制覆盖=$STAFF_MID" && PASS=$((PASS+1)) || { echo "  ❌ E db mid=$P1_DB_MID want=$STAFF_MID"; FAIL=$((FAIL+1)); }
fi

# F) 创建 VOUCHER 商品（面额/门槛字段）
P2_PAYLOAD=$(python3 -c "import json; print(json.dumps({
  'typeCode':'VOUCHER','productName':'C11_VOUCHER烟测代金券',
  'storeId':$STORE_ID,'storeIds':'$STORE_ID',
  'price':80.00,'faceValue':100.00,'minConsume':200.00,
  'validityDays':60,'stock':50,'maxPerOrder':3
}))")
P2=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STAFF_TOK" \
  -d "$P2_PAYLOAD" $H/api/product/add)
P2_ID=$(echo "$P2" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('productId') or d.get('data',{}).get('productId') or 0)")
[ "$P2_ID" -gt 0 ] && echo "  ✅ F VOUCHER 创建成功 productId=$P2_ID" && PASS=$((PASS+1)) || { echo "  ❌ F VOUCHER 失败: $P2"; FAIL=$((FAIL+1)); }
if [ "$P2_ID" -gt 0 ]; then
  P2_FV=$($DB_CMD -N -e "SELECT IFNULL(face_value,0) FROM biz_product WHERE product_id=$P2_ID;" 2>/dev/null)
  P2_MC=$($DB_CMD -N -e "SELECT IFNULL(min_consume,0) FROM biz_product WHERE product_id=$P2_ID;" 2>/dev/null)
  python3 -c "import sys; sys.exit(0 if abs($P2_FV - 100) < 0.01 else 1)" && echo "  ✅ F 落库 face_value=100" && PASS=$((PASS+1)) || { echo "  ❌ F face_value=$P2_FV"; FAIL=$((FAIL+1)); }
  python3 -c "import sys; sys.exit(0 if abs($P2_MC - 200) < 0.01 else 1)" && echo "  ✅ F 落库 min_consume=200" && PASS=$((PASS+1)) || { echo "  ❌ F min_consume=$P2_MC"; FAIL=$((FAIL+1)); }
fi

# G) 缺 storeIds 应被拒
BAD1=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STAFF_TOK" \
  -d '{"typeCode":"GROUPON","productName":"缺storeIds","price":10}' $H/api/product/add)
echo "$BAD1" | grep -q "适用门店" && echo "  ✅ G 缺 storeIds 被拒" && PASS=$((PASS+1)) || { echo "  ❌ G 未被拒: $BAD1"; FAIL=$((FAIL+1)); }

# H) 防越权：尝试把 merchantId 改成 9999 + storeId 改成别家门店的 999，应被强制覆盖
P3_PAYLOAD=$(python3 -c "import json; print(json.dumps({
  'typeCode':'GROUPON','productName':'C11_越权烟测',
  'merchantId':9999,'storeId':999,'storeIds':'999',
  'price':50,'validityDays':30,
  # ProductValidator 要求 GROUPON 必填 stock/maxPerOrder（v2.6 P1 类型必填校验）。
  # 本用例要验的是「merchantId/storeId 越权被强制覆盖」，必填字段得给全，否则 500 在校验就返回了。
  'stock':10,'maxPerOrder':1
}))")
P3=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $STAFF_TOK" \
  -d "$P3_PAYLOAD" $H/api/product/add)
P3_ID=$(echo "$P3" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('productId') or d.get('data',{}).get('productId') or 0)")
[ "$P3_ID" -gt 0 ] && echo "  ✅ H 越权请求被允许（但 merchantId 强制覆盖）" && PASS=$((PASS+1)) || { echo "  ❌ H 越权请求失败: $P3"; FAIL=$((FAIL+1)); }
if [ "$P3_ID" -gt 0 ]; then
  P3_DB_MID=$($DB_CMD -N -e "SELECT merchant_id FROM biz_product WHERE product_id=$P3_ID;" 2>/dev/null)
  [ "$P3_DB_MID" = "$STAFF_MID" ] && echo "  ✅ H 越权 merchantId=9999 被覆盖为 $STAFF_MID" && PASS=$((PASS+1)) || { echo "  ❌ H mid=$P3_DB_MID"; FAIL=$((FAIL+1)); }
fi

# I) 缺登录应被拒
UNAUTH=$(curl -s -X POST -H "Content-Type: application/json" \
  -d '{"typeCode":"GROUPON","productName":"unauth","storeIds":"1","price":10}' $H/api/product/add)
echo "$UNAUTH" | grep -qE "401|未登录|登录" && echo "  ✅ I 未登录被拒" && PASS=$((PASS+1)) || { echo "  ❌ I 未登录未拒: $UNAUTH"; FAIL=$((FAIL+1)); }

cleanup() {
  [ "$P1_ID" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_product WHERE product_id=$P1_ID;" 2>/dev/null || true
  [ "$P2_ID" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_product WHERE product_id=$P2_ID;" 2>/dev/null || true
  [ "$P3_ID" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_product WHERE product_id=$P3_ID;" 2>/dev/null || true
}
trap cleanup EXIT

echo ""
echo "C11 smoke: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
