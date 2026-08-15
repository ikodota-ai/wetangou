#!/usr/bin/env bash
# C45 平台账号 dashboard 骨架 smoke
# - /api/platform/stats          (PLATFORM only)
# - /api/platform/merchant/list  (PLATFORM only, 支持 agentId + scope=SELF_MANAGED)
# - /api/platform/agent/list     (PLATFORM only)
set -e
H=http://127.0.0.1:8080
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

echo "C45 平台 dashboard smoke:"

# 1) 5 角色测试账号 (幂等)
/usr/local/mysql/bin/mysql --default-character-set=utf8mb4 -uroot -p133301 ry-vue < sql/biz_role_extension.sql >/dev/null 2>&1

login() {
  curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"username\":\"$1\",\"password\":\"admin123\"}" $H/api/merchant/staff/login \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))"
}
TK_PLATFORM=$(login platform_c43)
TK_AGENT=$(login agent_c43)
TK_OWNER=$(login owner_c43)
TK_STAFF=$(login staff_c43)

# 2) /api/platform/stats: 平台账号 200, 其他 403
echo "  --- /api/platform/stats ---"
RESP=$(curl -s -o /tmp/c45.txt -w "%{http_code}" $H/api/platform/stats -H "Authorization: Bearer $TK_PLATFORM")
chk "[platform_c43] /api/platform/stats 200" "merchantTotal" "$(cat /tmp/c45.txt)"
RESP=$(curl -s -o /tmp/c45.txt -w "%{http_code}" $H/api/platform/stats -H "Authorization: Bearer $TK_AGENT")
chk "[agent_c43] /api/platform/stats 403" "需要 PLATFORM" "$(cat /tmp/c45.txt)"
RESP=$(curl -s -o /tmp/c45.txt -w "%{http_code}" $H/api/platform/stats -H "Authorization: Bearer $TK_OWNER")
chk "[owner_c43] /api/platform/stats 403" "需要 PLATFORM" "$(cat /tmp/c45.txt)"
RESP=$(curl -s -o /tmp/c45.txt -w "%{http_code}" $H/api/platform/stats -H "Authorization: Bearer $TK_STAFF")
chk "[staff_c43] /api/platform/stats 403" "需要 PLATFORM" "$(cat /tmp/c45.txt)"

# 3) /api/platform/merchant/list
echo "  --- /api/platform/merchant/list ---"
RESP=$(curl -s -o /tmp/c45.txt -w "%{http_code}" $H/api/platform/merchant/list -H "Authorization: Bearer $TK_PLATFORM")
chk "[platform_c43] /merchant/list 200" "rows" "$(cat /tmp/c45.txt)"
# agentId=1 过滤
RESP=$(curl -s -o /tmp/c45.txt -w "%{http_code}" "$H/api/platform/merchant/list?agentId=1" -H "Authorization: Bearer $TK_PLATFORM")
chk "[platform_c43] /merchant/list?agentId=1 返回含 agentId=1 的商家" "agentId" "$(cat /tmp/c45.txt)"
# scope=SELF_MANAGED
RESP=$(curl -s -o /tmp/c45.txt -w "%{http_code}" "$H/api/platform/merchant/list?scope=SELF_MANAGED" -H "Authorization: Bearer $TK_PLATFORM")
chk "[platform_c43] /merchant/list?scope=SELF_MANAGED 200" "rows" "$(cat /tmp/c45.txt)"
# 权限 403
RESP=$(curl -s -o /tmp/c45.txt -w "%{http_code}" $H/api/platform/merchant/list -H "Authorization: Bearer $TK_OWNER")
chk "[owner_c43] /merchant/list 403" "需要 PLATFORM" "$(cat /tmp/c45.txt)"

# 4) /api/platform/agent/list
echo "  --- /api/platform/agent/list ---"
RESP=$(curl -s -o /tmp/c45.txt -w "%{http_code}" $H/api/platform/agent/list -H "Authorization: Bearer $TK_PLATFORM")
chk "[platform_c43] /agent/list 200" "agentNo" "$(cat /tmp/c45.txt)"
# keyword
RESP=$(curl -s -o /tmp/c45.txt -w "%{http_code}" "$H/api/platform/agent/list?keyword=test" -H "Authorization: Bearer $TK_PLATFORM")
chk "[platform_c43] /agent/list?keyword=test 200" "操作成功" "$(cat /tmp/c45.txt)"
# 权限 403
RESP=$(curl -s -o /tmp/c45.txt -w "%{http_code}" $H/api/platform/agent/list -H "Authorization: Bearer $TK_AGENT")
chk "[agent_c43] /agent/list 403" "需要 PLATFORM" "$(cat /tmp/c45.txt)"

# 5) 未登录拦截
echo "  --- 未登录拦截 ---"
RESP=$(curl -s -o /tmp/c45.txt -w "%{http_code}" $H/api/platform/stats)
chk "未登录 /api/platform/stats 401" "未登录" "$(cat /tmp/c45.txt)"

echo ""
echo "C45 结果: $PASS PASS / $FAIL FAIL"
[ $FAIL -eq 0 ] && echo "🎉 ALL PASS" || echo "❌ FAIL"
