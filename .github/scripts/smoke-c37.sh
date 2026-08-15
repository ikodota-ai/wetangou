#!/usr/bin/env bash
# C37 登录入口 userType 路由分流 smoke
# admin → /index (平台)
# agent 账号 → /agent/index
# merchant 账号 → /merchant/index
set -e
H=http://127.0.0.1:8080
DB="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"
LOG=/tmp/jrun-c37.log
TS=$(date +%s | tail -c 7)
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

echo "C37 登录路由分流 smoke:"

# 准备：插入一个 agent 账号 + 一个 merchant 账号（sys_user + biz_merchant_user）
# 1) 创建测试 agent
$DB -e "INSERT INTO sys_user (user_name, nick_name, password, status, user_type, merchant_id) VALUES ('agent_c37_${TS}', 'agent_c37', '\$2a\$10\$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2', '0', '1', 0);" 2>/dev/null
AGENT_UID=$($DB -N -e "SELECT user_id FROM sys_user WHERE user_name='agent_c37_${TS}';" 2>/dev/null | head -1)
$DB -e "INSERT INTO biz_merchant_user (user_id, agent_id, user_type) VALUES ($AGENT_UID, 1, '1');" 2>/dev/null
echo "  [setup] agent userId=$AGENT_UID"

# 2) 创建测试 merchant
$DB -e "INSERT INTO sys_user (user_name, nick_name, password, status, user_type, merchant_id) VALUES ('mer_c37_${TS}', 'mer_c37', '\$2a\$10\$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2', '0', '2', 1);" 2>/dev/null
MER_UID=$($DB -N -e "SELECT user_id FROM sys_user WHERE user_name='mer_c37_${TS}';" 2>/dev/null | head -1)
$DB -e "INSERT INTO biz_merchant_user (user_id, merchant_id, user_type) VALUES ($MER_UID, 1, '2');" 2>/dev/null
echo "  [setup] merchant userId=$MER_UID"

# A) admin 登录（userType=0 平台）
LOGIN_A=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"username\":\"admin\",\"password\":\"admin123\"}" $H/login)
TOK_A=$(echo "$LOGIN_A" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
INFO_A=$(curl -s -H "Authorization: Bearer $TOK_A" $H/getInfo)
UT_A=$(echo "$INFO_A" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('userType',''))")
MID_A=$(echo "$INFO_A" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('merchantId',''))")
echo "  [A] admin userType=$UT_A merchantId=$MID_A"
chk "A) admin userType=0 (平台)" "0" "$UT_A"
chk "A) admin 无 merchantId" "" "$MID_A"

# B) agent 账号登录（userType=1）
LOGIN_B=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"username\":\"agent_c37_${TS}\",\"password\":\"admin123\"}" $H/login)
TOK_B=$(echo "$LOGIN_B" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
INFO_B=$(curl -s -H "Authorization: Bearer $TOK_B" $H/getInfo)
UT_B=$(echo "$INFO_B" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('userType',''))")
AID_B=$(echo "$INFO_B" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('agentId',''))")
echo "  [B] agent userType=$UT_B agentId=$AID_B"
chk "B) agent userType=1" "1" "$UT_B"
chk "B) agent 有 agentId" "1" "$AID_B"

# C) merchant 账号登录（userType=2）
LOGIN_C=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"username\":\"mer_c37_${TS}\",\"password\":\"admin123\"}" $H/login)
TOK_C=$(echo "$LOGIN_C" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
INFO_C=$(curl -s -H "Authorization: Bearer $TOK_C" $H/getInfo)
UT_C=$(echo "$INFO_C" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('userType',''))")
MID_C=$(echo "$INFO_C" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('merchantId',''))")
echo "  [C] merchant userType=$UT_C merchantId=$MID_C"
chk "C) merchant userType=2" "2" "$UT_C"
chk "C) merchant 有 merchantId=1" "1" "$MID_C"

# D) 前端路由可达性：检查 .vue 文件已存在 + 路由表已注册
[ -f "ruoyi-ui/src/views/agent/index.vue" ] && echo "  ✅ D) /views/agent/index.vue 存在" && PASS=$((PASS+1)) || { echo "  ❌ D) /views/agent/index.vue 缺失"; FAIL=$((FAIL+1)); }
[ -f "ruoyi-ui/src/views/merchant/index.vue" ] && echo "  ✅ D+) /views/merchant/index.vue 存在" && PASS=$((PASS+1)) || { echo "  ❌ D+) /views/merchant/index.vue 缺失"; FAIL=$((FAIL+1)); }
grep -q "agent/index\|views/agent" ruoyi-ui/src/router/index.js && echo "  ✅ D++) /agent/index 路由已注册" && PASS=$((PASS+1)) || { echo "  ❌ D++) agent 路由未注册"; FAIL=$((FAIL+1)); }
grep -q "merchant/index\|views/merchant" ruoyi-ui/src/router/index.js && echo "  ✅ D+++) /merchant/index 路由已注册" && PASS=$((PASS+1)) || { echo "  ❌ D+++) merchant 路由未注册"; FAIL=$((FAIL+1)); }

# E) 前端 resolveEntryPath 路由分发逻辑（基于 login.vue 源码）
grep -q "resolveEntryPath" ruoyi-ui/src/views/login.vue && echo "  ✅ E) login.vue 调 resolveEntryPath()" && PASS=$((PASS+1)) || { echo "  ❌ E) resolveEntryPath 未调"; FAIL=$((FAIL+1)); }
grep -q "/agent/index" ruoyi-ui/src/views/login.vue && echo "  ✅ E+) login.vue 路由 /agent/index" && PASS=$((PASS+1)) || { echo "  ❌ E+) login.vue 路由 /agent/index 缺失"; FAIL=$((FAIL+1)); }
grep -q "/merchant/index" ruoyi-ui/src/views/login.vue && echo "  ✅ E++) login.vue 路由 /merchant/index" && PASS=$((PASS+1)) || { echo "  ❌ E++) login.vue 路由 /merchant/index 缺失"; FAIL=$((FAIL+1)); }

# F) 三 tabs UI
grep -q "平台\|代理商\|商户" ruoyi-ui/src/views/login.vue && echo "  ✅ F) login.vue 含 平台/代理商/商户 三 tab 文案" && PASS=$((PASS+1)) || { echo "  ❌ F) 三 tab 文案缺失"; FAIL=$((FAIL+1)); }

# 清理
$DB -e "DELETE FROM biz_merchant_user WHERE user_id IN ($AGENT_UID, $MER_UID);" 2>/dev/null
$DB -e "DELETE FROM sys_user WHERE user_id IN ($AGENT_UID, $MER_UID);" 2>/dev/null
echo "  [cleanup] 测试账号已删除"

echo ""
echo "C37 结果: $PASS PASS / $FAIL FAIL"
[ $FAIL -eq 0 ] && echo "🎉 ALL PASS" || echo "❌ 有失败用例"
