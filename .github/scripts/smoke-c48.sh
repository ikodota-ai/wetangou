#!/usr/bin/env bash
# V5-3 ApiAgentController 代理商 dashboard smoke
set -u
H=http://127.0.0.1:8080
PASS=0; FAIL=0

login() {
    curl -s -X POST $H/api/merchant/staff/login \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$1\",\"password\":\"admin123\"}" \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))"
}

check() {
    local label="$1" expected_code="$2" body="$3"
    local got
    got=$(echo "$body" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('code'))" 2>/dev/null)
    if [ "$got" = "$expected_code" ]; then
        echo "  ✅ $label  (body.code=$got)"
        PASS=$((PASS+1))
    else
        echo "  ❌ $label  expect=$expected_code got=$got body=$body"
        FAIL=$((FAIL+1))
    fi
}

# 字段验证
check_field() {
    local label="$1" expected="$2" body="$3" field="$4"
    local got
    got=$(echo "$body" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('$field',''))" 2>/dev/null)
    if [ "$got" = "$expected" ]; then
        echo "  ✅ $label  (data.$field=$got)"
        PASS=$((PASS+1))
    else
        echo "  ❌ $label  expect=$expected got=$got"
        FAIL=$((FAIL+1))
    fi
}

TK_AGENT=$(login agent_c43)
TK_OWNER=$(login owner_c43)
TK_STAFF=$(login staff_c43)
TK_PLATFORM=$(login platform_c43)
echo "tokens: agent=${#TK_AGENT} owner=${#TK_OWNER} staff=${#TK_STAFF} platform=${#TK_PLATFORM}"

echo ""
echo "--- /api/agent/info ---"
check "[agent_c43] /info 200" 200 "$(curl -s $H/api/agent/info -H "Authorization: Bearer $TK_AGENT")"
check "[owner_c43] /info 403"  403 "$(curl -s $H/api/agent/info -H "Authorization: Bearer $TK_OWNER")"
check "[staff_c43] /info 403"  403 "$(curl -s $H/api/agent/info -H "Authorization: Bearer $TK_STAFF")"
# 字段：agentId 必须回填
check_field "[agent_c43] /info agentId=102" 102 "$(curl -s $H/api/agent/info -H "Authorization: Bearer $TK_AGENT")" agentId
check_field "[agent_c43] /info agentNo=AG_C43" AG_C43 "$(curl -s $H/api/agent/info -H "Authorization: Bearer $TK_AGENT")" agentNo

echo ""
echo "--- /api/agent/merchant/list ---"
check "[agent_c43] /merchant/list 200" 200 "$(curl -s "$H/api/agent/merchant/list?limit=10" -H "Authorization: Bearer $TK_AGENT")"
check "[owner_c43] /merchant/list 403" 403 "$(curl -s $H/api/agent/merchant/list -H "Authorization: Bearer $TK_OWNER")"

echo ""
echo "--- /api/agent/order/list ---"
check "[agent_c43] /order/list 200" 200 "$(curl -s "$H/api/agent/order/list?limit=3" -H "Authorization: Bearer $TK_AGENT")"
check "[agent_c43] /order/list?status=1 200" 200 "$(curl -s "$H/api/agent/order/list?status=1&limit=3" -H "Authorization: Bearer $TK_AGENT")"
check "[staff_c43] /order/list 403"  403 "$(curl -s $H/api/agent/order/list -H "Authorization: Bearer $TK_STAFF")"

echo ""
echo "--- /api/agent/stats ---"
check "[agent_c43] /stats 200" 200 "$(curl -s $H/api/agent/stats -H "Authorization: Bearer $TK_AGENT")"
check "[owner_c43] /stats 403" 403 "$(curl -s $H/api/agent/stats -H "Authorization: Bearer $TK_OWNER")"

echo ""
echo "--- 平台账号 (PLATFORM 永远放行) ---"
check "[platform_c43] /info 200" 200 "$(curl -s $H/api/agent/info -H "Authorization: Bearer $TK_PLATFORM")"

echo ""
echo "--- 未登录 body.code=401 ---"
check "未登录 /info body.code=401" 401 "$(curl -s $H/api/agent/info)"

echo ""
echo "C48 结果: $PASS PASS / $FAIL FAIL"
[ $FAIL -eq 0 ] && echo "🎉 ALL PASS" || echo "💥 HAS FAIL"
