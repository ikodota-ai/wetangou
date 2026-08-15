#!/usr/bin/env bash
# C31 admin 端代理商升级入口端到端 smoke
# 验证:
#   A) admin 登录拿 token
#   B) 创建测试 member (mock appid login)
#   C) 缺 memberId/agentId → 必填校验
#   D) 不存在 memberId → 业务异常
#   E) 升级 memberId → agentId=1: 200 + DB user_type=1 agent_id=1
#   F) 降级 memberId: 200 + DB user_type=0 agent_id=NULL
#   G) 越权: 普通 member token 访问 admin 端 → 403
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

echo "C31 admin 端代理商升级入口 smoke:"

# A) admin token
ADMIN_TOK=$(curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' $H/login | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
[ ${#ADMIN_TOK} -gt 50 ] && echo "  ✅ A) admin login" && PASS=$((PASS+1)) || { echo "  ❌ A) admin login"; FAIL=$((FAIL+1)); exit 1; }

# B) 创建测试 member
JSCODE="c31_$(date +%s)_$$"
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE\",\"appid\":\"$APPID\",\"nickName\":\"c31\"}" $H/api/auth/login)
MID=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ "$MID" -gt 0 ] && echo "  ✅ B) member login (memberId=$MID)" && PASS=$((PASS+1)) || { echo "  ❌ B) login"; FAIL=$((FAIL+1)); exit 1; }

trap '$DB -e "UPDATE biz_member SET user_type=\"0\", agent_id=NULL WHERE member_id='"$MID"';" 2>/dev/null || true' EXIT

# C) 缺参
C=$(curl -s -X POST -H "Authorization: Bearer $ADMIN_TOK" $H/biz/agent/upgrade)
chk "C) 缺参必填校验" "必填" "$C"

# D) 不存在 memberId
D=$(curl -s -X POST -H "Authorization: Bearer $ADMIN_TOK" "$H/biz/agent/upgrade?memberId=999999&agentId=1")
chk "D) 不存在 memberId" "会员不存在" "$D"

# E) 升级
E=$(curl -s -X POST -H "Authorization: Bearer $ADMIN_TOK" "$H/biz/agent/upgrade?memberId=$MID&agentId=1")
chk "E) 升级成功" "升级成功" "$E"
USER_TYPE=$($DB -N -e "SELECT user_type FROM biz_member WHERE member_id=$MID;" 2>/dev/null | tail -1)
AGENT_ID=$($DB -N -e "SELECT agent_id FROM biz_member WHERE member_id=$MID;" 2>/dev/null | tail -1)
[ "$USER_TYPE" = "1" ] && [ "$AGENT_ID" = "1" ] && echo "  ✅ E+) DB user_type=1 agent_id=1" && PASS=$((PASS+1)) || { echo "  ❌ E+) userType=$USER_TYPE agentId=$AGENT_ID"; FAIL=$((FAIL+1)); }

# 重复升级: 应仍成功 (覆盖)
E2=$(curl -s -X POST -H "Authorization: Bearer $ADMIN_TOK" "$H/biz/agent/upgrade?memberId=$MID&agentId=1")
chk "E++) 重复升级" "升级成功" "$E2"

# F) 降级
F=$(curl -s -X POST -H "Authorization: Bearer $ADMIN_TOK" $H/biz/agent/upgrade/downgrade/$MID)
chk "F) 降级成功" "降级成功" "$F"
USER_TYPE2=$($DB -N -e "SELECT user_type FROM biz_member WHERE member_id=$MID;" 2>/dev/null | tail -1)
AGENT_ID2=$($DB -N -e "SELECT IFNULL(agent_id,0) FROM biz_member WHERE member_id=$MID;" 2>/dev/null | tail -1)
[ "$USER_TYPE2" = "0" ] && [ "$AGENT_ID2" = "0" ] && echo "  ✅ F+) DB user_type=0 agent_id=NULL" && PASS=$((PASS+1)) || { echo "  ❌ F+) userType=$USER_TYPE2 agentId=$AGENT_ID2"; FAIL=$((FAIL+1)); }

# G) 越权: member token 访问 admin 端 → 403
JSCODE2="c31g_$(date +%s)_$$"
LOGIN2=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE2\",\"appid\":\"$APPID\",\"nickName\":\"c31g\"}" $H/api/auth/login)
MEM_TOK=$(echo "$LOGIN2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
G=$(curl -s -X POST -H "Authorization: Bearer $MEM_TOK" $H/biz/agent/upgrade)
echo "$G" | grep -qE "401|403|没有权限" && echo "  ✅ G) member token 拒绝" && PASS=$((PASS+1)) || { echo "  ❌ G) member token 应拒绝: ${G:0:200}"; FAIL=$((FAIL+1)); }

echo "C31 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
