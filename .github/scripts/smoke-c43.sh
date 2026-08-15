#!/usr/bin/env bash
# C43 5 角色权限模型 smoke
# 平台(PLATFORM) / 代理商(AGENT) / 老板(OWNER) / 店长(MANAGER) / 店员(STAFF)
set -e
H=http://127.0.0.1:8080
TS=$(date +%s | tail -c 7)
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

echo "C43 5 角色权限模型 smoke:"

# 1) 确保 5 个测试账号 (幂等)
echo "  [setup] 5 角色测试账号 (幂等)"
/usr/local/mysql/bin/mysql --default-character-set=utf8mb4 -uroot -p133301 ry-vue < sql/biz_role_extension.sql >/dev/null 2>&1

# 2) 5 角色登录
login() {
  local u=$1
  curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"username\":\"$u\",\"password\":\"admin123\"}" $H/api/merchant/staff/login
}
TK_PLATFORM=$(login platform_c43 | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
TK_AGENT=$(login agent_c43 | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
TK_OWNER=$(login owner_c43 | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
TK_MANAGER=$(login manager_c43 | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
TK_STAFF=$(login staff_c43 | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")

# 各角色 userType/roles 期望
RESP=$(login platform_c43)
UT=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('userType',''))")
RL=$(echo "$RESP" | python3 -c "import sys,json; print(','.join(json.load(sys.stdin).get('roles',[])))")
chk "[platform_c43] userType=platform" "platform" "$UT"
chk "[platform_c43] roles=PLATFORM" "PLATFORM" "$RL"

RESP=$(login agent_c43)
UT=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('userType',''))")
RL=$(echo "$RESP" | python3 -c "import sys,json; print(','.join(json.load(sys.stdin).get('roles',[])))")
chk "[agent_c43] userType=agent" "agent" "$UT"
chk "[agent_c43] roles=AGENT" "AGENT" "$RL"

RESP=$(login owner_c43)
UT=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('userType',''))")
RL=$(echo "$RESP" | python3 -c "import sys,json; print(','.join(json.load(sys.stdin).get('roles',[])))")
chk "[owner_c43] userType=owner" "owner" "$UT"
chk "[owner_c43] roles=OWNER" "OWNER" "$RL"

RESP=$(login manager_c43)
UT=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('userType',''))")
RL=$(echo "$RESP" | python3 -c "import sys,json; print(','.join(json.load(sys.stdin).get('roles',[])))")
chk "[manager_c43] userType=manager" "manager" "$UT"
chk "[manager_c43] roles=MANAGER" "MANAGER" "$RL"

RESP=$(login staff_c43)
UT=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('userType',''))")
RL=$(echo "$RESP" | python3 -c "import sys,json; print(','.join(json.load(sys.stdin).get('roles',[])))")
chk "[staff_c43] userType=staff" "staff" "$UT"
chk "[staff_c43] roles=STAFF" "STAFF" "$RL"

# 3) /finance/summary 权限 (OWNER+MANAGER 200, AGENT+STAFF 403, PLATFORM 走通但 merchantId=null 报 500 业务错)
echo ""
echo "  --- /api/merchant/staff/finance/summary ---"
RESP=$(curl -s -o /tmp/c43.txt -w "%{http_code}" $H/api/merchant/staff/finance/summary -H "Authorization: Bearer $TK_PLATFORM")
chk "[platform_c43] /finance/summary 200 (拦截器放行，商家业务 500)" "未关联商家" "$(cat /tmp/c43.txt)"
RESP=$(curl -s -o /tmp/c43.txt -w "%{http_code}" $H/api/merchant/staff/finance/summary -H "Authorization: Bearer $TK_AGENT")
chk "[agent_c43] /finance/summary 403" "需要 OWNER/MANAGER" "$(cat /tmp/c43.txt)"
RESP=$(curl -s -o /tmp/c43.txt -w "%{http_code}" $H/api/merchant/staff/finance/summary -H "Authorization: Bearer $TK_OWNER")
chk "[owner_c43] /finance/summary 200" "totalRevenue" "$(cat /tmp/c43.txt)"
RESP=$(curl -s -o /tmp/c43.txt -w "%{http_code}" $H/api/merchant/staff/finance/summary -H "Authorization: Bearer $TK_MANAGER")
chk "[manager_c43] /finance/summary 200" "totalRevenue" "$(cat /tmp/c43.txt)"
RESP=$(curl -s -o /tmp/c43.txt -w "%{http_code}" $H/api/merchant/staff/finance/summary -H "Authorization: Bearer $TK_STAFF")
chk "[staff_c43] /finance/summary 403" "需要 OWNER/MANAGER" "$(cat /tmp/c43.txt)"

# 4) /platform/finance/summary 权限 (仅 PLATFORM 200)
echo ""
echo "  --- /api/merchant/staff/platform/finance/summary ---"
RESP=$(curl -s -o /tmp/c43.txt -w "%{http_code}" $H/api/merchant/staff/platform/finance/summary -H "Authorization: Bearer $TK_PLATFORM")
chk "[platform_c43] /platform/finance/summary 200" "totalRevenue" "$(cat /tmp/c43.txt)"
RESP=$(curl -s -o /tmp/c43.txt -w "%{http_code}" $H/api/merchant/staff/platform/finance/summary -H "Authorization: Bearer $TK_AGENT")
chk "[agent_c43] /platform/finance/summary 403" "需要 PLATFORM" "$(cat /tmp/c43.txt)"
RESP=$(curl -s -o /tmp/c43.txt -w "%{http_code}" $H/api/merchant/staff/platform/finance/summary -H "Authorization: Bearer $TK_OWNER")
chk "[owner_c43] /platform/finance/summary 403" "需要 PLATFORM" "$(cat /tmp/c43.txt)"
RESP=$(curl -s -o /tmp/c43.txt -w "%{http_code}" $H/api/merchant/staff/platform/finance/summary -H "Authorization: Bearer $TK_MANAGER")
chk "[manager_c43] /platform/finance/summary 403" "需要 PLATFORM" "$(cat /tmp/c43.txt)"
RESP=$(curl -s -o /tmp/c43.txt -w "%{http_code}" $H/api/merchant/staff/platform/finance/summary -H "Authorization: Bearer $TK_STAFF")
chk "[staff_c43] /platform/finance/summary 403" "需要 PLATFORM" "$(cat /tmp/c43.txt)"

# 5) 平台端 scope 维度
echo ""
echo "  --- 平台端 scope 维度 ---"
RESP_ALL=$(curl -s "$H/api/merchant/staff/platform/finance/summary" -H "Authorization: Bearer $TK_PLATFORM")
RESP_SM=$(curl -s "$H/api/merchant/staff/platform/finance/summary?scope=SELF_MANAGED" -H "Authorization: Bearer $TK_PLATFORM")
RESP_A=$(curl -s "$H/api/merchant/staff/platform/finance/summary?agentId=101" -H "Authorization: Bearer $TK_PLATFORM")
ALL_TOTAL=$(echo "$RESP_ALL" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['totalRevenue'])")
SM_TOTAL=$(echo "$RESP_SM" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['totalRevenue'])")
A_TOTAL=$(echo "$RESP_A" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['totalRevenue'])")
SM_SCOPE=$(echo "$RESP_SM" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['scope'])")
A_AGENT=$(echo "$RESP_A" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['agentId'])")
chk "scope=ALL 全部 (totalRevenue 起头)" "219" "${ALL_TOTAL:0:3}"
chk "scope=SELF_MANAGED 自营" "100" "$SM_TOTAL"
chk "scope=SELF_MANAGED 标识" "SELF_MANAGED" "$SM_SCOPE"
chk "agentId=101 某代理 0" "0" "$A_TOTAL"
chk "agentId=101 回填" "101" "$A_AGENT"

echo ""
echo "C43 结果: $PASS PASS / $FAIL FAIL"
[ $FAIL -eq 0 ] && echo "🎉 ALL PASS" || echo "❌ FAIL"
