#!/usr/bin/env bash
# C23 /api/distributor/agent/summary dead-end 文档化
# 验证:
#   A) member 登录 (任意 mini member) → token
#   B) GET /api/distributor/agent/summary → "仅代理商账号可调用" (code 500)
#   C) 该端点对小程序端不可达: LoginMember(Member) 构造未读 userType
#      → userType 始终为 null → !"1".equals(null) → 拒绝
#   D) 防御: 端点存在但死锁, 业务侧应改走 /biz/agent/commission/summary (admin 端)
# 前置: 后端 8080 在跑; mock appid

# fixture 自备（见 .github/scripts/lib/smoke-fixture.sh）
# 背景：62 smoke 串行跑会互相污染（改密码/耗库存/覆盖 openid），造成假 FAIL
source "$(dirname "$0")/lib/smoke-fixture.sh"
fx_ensure_mock_on

set -e
H=http://127.0.0.1:8080
APPID="${APPID:-wx9e147c4e2151b123}"

PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

echo "C23 /api/distributor/agent/summary dead-end smoke:"

# A) member 登录
JSCODE="c23_$(date +%s)_$$"
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE\",\"appid\":\"$APPID\",\"nickName\":\"c23\"}" $H/api/auth/login)
TOK=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
MID=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ ${#TOK} -gt 50 ] && [ "$MID" -gt 0 ] && echo "  ✅ A) member login (memberId=$MID)" && PASS=$((PASS+1)) || { echo "  ❌ A) login"; FAIL=$((FAIL+1)); exit 1; }

# B) agent/summary 拒绝 mini member
SUM=$(curl -s -H "Authorization: Bearer $TOK" $H/api/distributor/agent/summary)
chk "B) mini member → 拒绝" "仅代理商账号可调用" "$SUM"
echo "$SUM" | grep -q '"code":500' && echo "  ✅ B+) code=500 (业务异常)" && PASS=$((PASS+1)) || { echo "  ❌ B+) code: ${SUM:0:200}"; FAIL=$((FAIL+1)); }

# C) 越权/匿名: 无 token
SUM_ANON=$(curl -s $H/api/distributor/agent/summary)
chk "C) 无 token → 401" "401" "$SUM_ANON"

# D) 文档化: 端点存在但 mini 端不可达; 业务侧应改走 /biz/agent/commission/summary
#   用 c1 的 admin 端验证 ($BASE_URL/login 拿 token) → 该端点可达
ADMIN_TOKEN=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"admin","password":"admin123"}' $H/login | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
ADMIN_RESP=$(curl -s "$H/biz/agent/commission/summary?agentId=1" -H "Authorization: Bearer $ADMIN_TOKEN")
echo "  [D] admin 端 /biz/agent/commission/summary?agentId=1 → 200: $(echo $ADMIN_RESP | head -c 120)..."
echo "$ADMIN_RESP" | grep -q '"code":200' && echo "  ✅ D) admin 端可达 (推荐替代)" && PASS=$((PASS+1)) || { echo "  ❌ D) admin 端: ${ADMIN_RESP:0:200}"; FAIL=$((FAIL+1)); }

echo "C23 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
