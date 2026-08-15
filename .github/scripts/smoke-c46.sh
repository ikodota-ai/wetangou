#!/bin/bash
set -e
H=http://127.0.0.1:8080
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

login() { curl -s -X POST -H "Content-Type: application/json" -d "{\"username\":\"$1\",\"password\":\"admin123\"}" $H/api/merchant/staff/login | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))"; }
TK_OWNER=$(login owner_c43)
TK_STAFF=$(login staff_c43)
TK_AGENT=$(login agent_c43)
TK_PLATFORM=$(login platform_c43)

# 1. /api/product/add: 商家端商品创建
echo "--- /api/product/add ---"
chk "[owner] product/add 200" "操作成功" "$(curl -s -X POST $H/api/product/add -H "Authorization: Bearer $TK_OWNER" -H "Content-Type: application/json" -d '{"productName":"v51-测试","typeCode":"GROUPON","price":10,"validityDays":30,"storeIds":"100","merchantId":1}')"
chk "[staff] product/add 403" "需要" "$(curl -s -X POST $H/api/product/add -H "Authorization: Bearer $TK_STAFF" -H "Content-Type: application/json" -d '{"productName":"v51-测试","typeCode":"GROUPON","price":10,"validityDays":30,"storeIds":"100","merchantId":1}')"
chk "[agent] product/add 403" "需要" "$(curl -s -X POST $H/api/product/add -H "Authorization: Bearer $TK_AGENT" -H "Content-Type: application/json" -d '{"productName":"v51-测试","typeCode":"GROUPON","price":10,"validityDays":30,"storeIds":"100","merchantId":1}')"

# 2. /api/merchant/staff/home 商家端 dashboard: 全 4 角色都允许
echo "--- /api/merchant/staff/home ---"
chk "[owner] home 403 (STAFF only)" "需要 STAFF" "$(curl -s $H/api/merchant/staff/home -H "Authorization: Bearer $TK_OWNER")"
chk "[staff] home 200" "storeId" "$(curl -s $H/api/merchant/staff/home -H "Authorization: Bearer $TK_STAFF")"
chk "[agent] home 403 (STAFF only)" "需要 STAFF" "$(curl -s $H/api/merchant/staff/home -H "Authorization: Bearer $TK_AGENT")"

# 3. /api/merchant/staff/today/orders
echo "--- /api/merchant/staff/today/orders ---"
chk "[owner] today/orders 403 (STAFF only)" "需要 STAFF" "$(curl -s $H/api/merchant/staff/today/orders -H "Authorization: Bearer $TK_OWNER")"

# 4. /api/merchant/staff/finance/summary (已存在)
echo "--- /api/merchant/staff/finance/summary ---"
chk "[owner] finance/summary 200" "totalRevenue" "$(curl -s $H/api/merchant/staff/finance/summary -H "Authorization: Bearer $TK_OWNER")"
chk "[staff] finance/summary 403" "需要" "$(curl -s $H/api/merchant/staff/finance/summary -H "Authorization: Bearer $TK_STAFF")"

# 5. /api/merchant/staff/me 任何登录
echo "--- /api/merchant/staff/me ---"
chk "[owner] me 200" "userId" "$(curl -s $H/api/merchant/staff/me -H "Authorization: Bearer $TK_OWNER")"
chk "[staff] me 200" "userId" "$(curl -s $H/api/merchant/staff/me -H "Authorization: Bearer $TK_STAFF")"

echo ""
echo "V5-1 smoke: $PASS PASS / $FAIL FAIL"
