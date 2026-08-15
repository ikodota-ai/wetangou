#!/usr/bin/env bash
# C26 修 C23 dead-end 验证: /api/distributor/agent/summary 端到端
# 验证:
#   A) 普通 member (user_type=0) → 仍被拒绝 (防御保留)
#   B) DB 升级为代理商 (user_type=1, agent_id=1) + 重新登录 → token
#   C) /api/distributor/agent/summary → 返 200 + agentId=1 + 数据
#   D) /api/auth/info 返 userType/agentId 字段 (新写入)
#   E) DB 还原 user_type=0, agent_id=NULL (cleanup)
# 前置: 后端 8080 在跑; mock appid
set -e
H=http://127.0.0.1:8080
DB="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"
APPID="${APPID:-wx9e147c4e2151b123}"

PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

echo "C26 /api/distributor/agent/summary dead-end 解锁验证 smoke:"

# A) 普通 member
JSCODE="c26_$(date +%s)_$$"
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE\",\"appid\":\"$APPID\",\"nickName\":\"c26\"}" $H/api/auth/login)
TOK=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
MID=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ ${#TOK} -gt 50 ] && echo "  ✅ A) member login (memberId=$MID)" && PASS=$((PASS+1)) || { echo "  ❌ A) login"; FAIL=$((FAIL+1)); exit 1; }

# A+) 普通 member → /agent/summary 应被 userType 拦截
A_SUM=$(curl -s -H "Authorization: Bearer $TOK" $H/api/distributor/agent/summary)
chk "A+) 普通 member → 拒绝" "仅代理商账号可调用" "$A_SUM"

# cleanup
trap '$DB -e "UPDATE biz_member SET user_type=\"0\", agent_id=NULL WHERE member_id='"$MID"';" 2>/dev/null || true' EXIT

# B) DB 升级为代理商
$DB -e "UPDATE biz_member SET user_type='1', agent_id=1 WHERE member_id=$MID;" 2>/dev/null
USER_TYPE=$($DB -N -e "SELECT user_type FROM biz_member WHERE member_id=$MID;" 2>/dev/null | tail -1)
AGENT_ID=$($DB -N -e "SELECT agent_id FROM biz_member WHERE member_id=$MID;" 2>/dev/null | tail -1)
[ "$USER_TYPE" = "1" ] && [ "$AGENT_ID" = "1" ] && echo "  ✅ B) DB 升级 userType=1 agentId=1" && PASS=$((PASS+1)) || { echo "  ❌ B) userType=$USER_TYPE agentId=$AGENT_ID"; FAIL=$((FAIL+1)); }

# 重新登录拿新 token (读 DB userType/agentId)
LOGIN2=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE\",\"appid\":\"$APPID\",\"nickName\":\"c26\"}" $H/api/auth/login)
TOK2=$(echo "$LOGIN2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
[ -n "$TOK2" ] && echo "  ✅ B+) 重新登录拿新 token" && PASS=$((PASS+1)) || { echo "  ❌ B+) login"; FAIL=$((FAIL+1)); }

# C) /agent/summary 200
SUM=$(curl -s -H "Authorization: Bearer $TOK2" $H/api/distributor/agent/summary)
chk "C) 代理商 → /agent/summary 200" "操作成功" "$SUM"
echo "$SUM" | grep -q '"agentId":1' && echo "  ✅ C+) agentId=1" && PASS=$((PASS+1)) || { echo "  ❌ C+) agentId: ${SUM:0:200}"; FAIL=$((FAIL+1)); }
echo "$SUM" | grep -q '"merchantCount":1' && echo "  ✅ C++) merchantCount=1" && PASS=$((PASS+1)) || { echo "  ❌ C++) merchantCount: ${SUM:0:200}"; FAIL=$((FAIL+1)); }
echo "$SUM" | grep -qE "byMerchant|total_amount" && echo "  ✅ C+++) byMerchant 数据" && PASS=$((PASS+1)) || { echo "  ❌ C+++) byMerchant: ${SUM:0:200}"; FAIL=$((FAIL+1)); }

# D) /api/auth/info 返 userType/agentId
INFO=$(curl -s -X POST -H "Authorization: Bearer $TOK2" $H/api/auth/info)
echo "$INFO" | grep -q '"userType":"1"' && echo "  ✅ D) info.userType=1" && PASS=$((PASS+1)) || { echo "  ❌ D) userType: ${INFO:0:200}"; FAIL=$((FAIL+1)); }
echo "$INFO" | grep -q '"agentId":1' && echo "  ✅ D+) info.agentId=1" && PASS=$((PASS+1)) || { echo "  ❌ D+) agentId: ${INFO:0:200}"; FAIL=$((FAIL+1)); }

# 还原 user_type=0 (trapped)
$DB -e "UPDATE biz_member SET user_type='0', agent_id=NULL WHERE member_id=$MID;" 2>/dev/null

echo "C26 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
