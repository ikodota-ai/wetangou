#!/usr/bin/env bash
# V5-2 ApiPlatformController /order/list + /staff/list 平台端点 smoke
# 期望:
#   platform_c43 → 200, body.code=200, rows 非空
#   agent/owner/manager/staff → body.code=403 (拦截器 body 格式)
#   未登录 → 401
set -u
H=http://127.0.0.1:8080
PASS=0; FAIL=0

login() {
    curl -s -X POST $H/api/merchant/staff/login \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$1\",\"password\":\"admin123\"}" \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))"
}

# body 码判定（status code 故意 200，body.code 才是真值）
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

TK_PLATFORM=$(login platform_c43)
TK_AGENT=$(login agent_c43)
TK_OWNER=$(login owner_c43)
TK_MANAGER=$(login manager_c43)
TK_STAFF=$(login staff_c43)
echo "token lens: platform=${#TK_PLATFORM} agent=${#TK_AGENT} owner=${#TK_OWNER} manager=${#TK_MANAGER} staff=${#TK_STAFF}"

echo ""
echo "--- /api/platform/order/list ---"
check "[platform_c43] /order/list 200" 200 "$(curl -s $H/api/platform/order/list?limit=3 -H "Authorization: Bearer $TK_PLATFORM")"
check "[agent_c43]   /order/list 403"  403 "$(curl -s $H/api/platform/order/list       -H "Authorization: Bearer $TK_AGENT")"
check "[owner_c43]   /order/list 403"  403 "$(curl -s $H/api/platform/order/list       -H "Authorization: Bearer $TK_OWNER")"
check "[manager_c43] /order/list 403"  403 "$(curl -s $H/api/platform/order/list       -H "Authorization: Bearer $TK_MANAGER")"
check "[staff_c43]   /order/list 403"  403 "$(curl -s $H/api/platform/order/list       -H "Authorization: Bearer $TK_STAFF")"

echo ""
echo "--- /api/platform/order/list?scope=SELF_MANAGED ---"
check "[platform_c43] scope=SELF_MANAGED 200" 200 "$(curl -s "$H/api/platform/order/list?scope=SELF_MANAGED&limit=3" -H "Authorization: Bearer $TK_PLATFORM")"
check "[platform_c43] ?agentId=1 200" 200 "$(curl -s "$H/api/platform/order/list?agentId=1&limit=3" -H "Authorization: Bearer $TK_PLATFORM")"

echo ""
echo "--- /api/platform/staff/list ---"
check "[platform_c43] /staff/list 200" 200 "$(curl -s $H/api/platform/staff/list?limit=3 -H "Authorization: Bearer $TK_PLATFORM")"
check "[agent_c43]   /staff/list 403"  403 "$(curl -s $H/api/platform/staff/list       -H "Authorization: Bearer $TK_AGENT")"
check "[owner_c43]   /staff/list 403"  403 "$(curl -s $H/api/platform/staff/list       -H "Authorization: Bearer $TK_OWNER")"

echo ""
echo "--- /api/platform/staff/list?role=OWNER ---"
check "[platform_c43] ?role=OWNER 200" 200 "$(curl -s "$H/api/platform/staff/list?role=OWNER&limit=5" -H "Authorization: Bearer $TK_PLATFORM")"

echo ""
echo "--- 未登录 body.code=401（与拦截器约定一致） ---"
check "未登录 /order/list body.code=401" 401 "$(curl -s $H/api/platform/order/list)"
check "未登录 /staff/list body.code=401" 401 "$(curl -s $H/api/platform/staff/list)"

echo ""
echo "C47 结果: $PASS PASS / $FAIL FAIL"
[ $FAIL -eq 0 ] && echo "🎉 ALL PASS" || echo "💥 HAS FAIL"
