#!/usr/bin/env bash
# E11 AgentController 越权防护 smoke
# 验证:
#   A) agent001 (agentId=1) 查自己 /biz/agent/1 → 200
#   B) agent001 查别人 /biz/agent/101 → 500 + msg="没有权限访问该代理商数据"
#   C) agent002 (agentId=101) 查自己 → 200
#   D) agent002 查别人 → 500
#   E) admin (平台) 查任意 → 200
#   F) no auth → 401
#
# 前置: 后端在 8080, MySQL 可直连, agent001/agent002 账号已设密码 admin123
set -e

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"

# A. agent001 登录
T1=$(curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"agent001","password":"admin123"}' \
  "$BASE_URL/login" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
[ -n "$T1" ] || { echo "FAIL: agent001 login"; exit 1; }
echo "[login] agent001 ok"

# B. agent001 查自己 (1) → 200
RESP=$(curl -s -H "Authorization: $T1" "$BASE_URL/biz/agent/1")
CODE=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',0))")
[ "$CODE" = "200" ] || { echo "FAIL: A expected 200 got $CODE: $RESP"; exit 1; }
echo "  [A] OK: agent001 → /biz/agent/1 self → 200"

# C. agent001 查别人 (101) → 500
RESP=$(curl -s -H "Authorization: $T1" "$BASE_URL/biz/agent/101")
CODE=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',0))")
MSG=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('msg',''))")
[ "$CODE" = "500" ] || { echo "FAIL: B expected 500 got $CODE: $RESP"; exit 1; }
[ "$MSG" = "没有权限访问该代理商数据" ] || { echo "FAIL: B msg=$MSG"; exit 1; }
echo "  [B] OK: agent001 → /biz/agent/101 other → 500 (no permission)"

# D. agent002 登录
T2=$(curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"agent002","password":"admin123"}' \
  "$BASE_URL/login" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
[ -n "$T2" ] || { echo "FAIL: agent002 login"; exit 1; }
echo "[login] agent002 ok"

# E. agent002 查自己 (101) → 200
RESP=$(curl -s -H "Authorization: $T2" "$BASE_URL/biz/agent/101")
CODE=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',0))")
[ "$CODE" = "200" ] || { echo "FAIL: C expected 200 got $CODE: $RESP"; exit 1; }
echo "  [C] OK: agent002 → /biz/agent/101 self → 200"

# F. agent002 查别人 (1) → 500
RESP=$(curl -s -H "Authorization: $T2" "$BASE_URL/biz/agent/1")
CODE=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',0))")
[ "$CODE" = "500" ] || { echo "FAIL: D expected 500 got $CODE: $RESP"; exit 1; }
echo "  [D] OK: agent002 → /biz/agent/1 other → 500 (no permission)"

# G. admin 平台查任意 → 200
ADMIN_TOKEN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' \
  "$BASE_URL/login" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
RESP=$(curl -s -H "Authorization: $ADMIN_TOKEN" "$BASE_URL/biz/agent/1")
CODE=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',0))")
[ "$CODE" = "200" ] || { echo "FAIL: E admin/1 expected 200 got $CODE"; exit 1; }
RESP=$(curl -s -H "Authorization: $ADMIN_TOKEN" "$BASE_URL/biz/agent/101")
CODE=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',0))")
[ "$CODE" = "200" ] || { echo "FAIL: E admin/101 expected 200 got $CODE"; exit 1; }
echo "  [E] OK: admin → /biz/agent/{1,101} → 200 (platform bypass)"

# H. no auth
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/biz/agent/1")
[ "$CODE" = "401" ] || { echo "FAIL: F no auth got $CODE"; exit 1; }
echo "  [F] OK: no auth → 401"

echo "E11 smoke test PASSED"
