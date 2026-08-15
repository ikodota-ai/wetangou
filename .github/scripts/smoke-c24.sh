#!/usr/bin/env bash
# C24 /api/distributor/withdraw 成功路径端到端
# 验证:
#   A) member 登录 + join 推客
#   B) fixture: DB 注入 availableAmount=100.00, frozenAmount=0, withdrawAmount=0
#   C) 提现 30 元 → withdraw status=0, withdrawAmount=30, availableAmount=70
#   D) GET /api/distributor/withdraw/list → 含新提现 (status=0)
#   E) GET /api/distributor/center → availableAmount=70, withdrawAmount=30
#   F) 防御: 再提现 200 元 → 余额不足 (前置 available=70)
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
num_eq() { python3 -c "import sys; sys.exit(0 if abs($1 - $2) < 0.01 else 1)"; }

echo "C24 /api/distributor/withdraw 成功路径 smoke:"

# A) member 登录 + join
JSCODE="c24_$(date +%s)_$$"
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE\",\"appid\":\"$APPID\",\"nickName\":\"c24\"}" $H/api/auth/login)
TOK=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
MID=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ ${#TOK} -gt 50 ] && echo "  ✅ A) member login (memberId=$MID)" && PASS=$((PASS+1)) || { echo "  ❌ A) login"; FAIL=$((FAIL+1)); exit 1; }

# 兜底: 删残留
EXIST_DID=$($DB -N -e "SELECT distributor_id FROM biz_distributor WHERE member_id=$MID;" 2>/dev/null | tail -1)
[ -n "$EXIST_DID" ] && $DB -e "DELETE FROM biz_withdraw WHERE distributor_id=$EXIST_DID; DELETE FROM biz_distributor WHERE distributor_id=$EXIST_DID;" 2>/dev/null
DIST_ID=""
W_ID=""

cleanup() {
  [ -n "$W_ID" ] && $DB -e "DELETE FROM biz_withdraw WHERE withdraw_id=$W_ID;" 2>/dev/null || true
  [ -n "$DIST_ID" ] && $DB -e "DELETE FROM biz_distributor WHERE distributor_id=$DIST_ID;" 2>/dev/null || true
}
trap cleanup EXIT

# B) join 推客
JOIN=$(curl -s -X POST -H "Authorization: Bearer $TOK" $H/api/distributor/join)
DIST_ID=$(echo "$JOIN" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['distributorId'])" 2>/dev/null)
[ -n "$DIST_ID" ] && [ "$DIST_ID" -gt 0 ] && echo "  ✅ B) join (distributorId=$DIST_ID)" && PASS=$((PASS+1)) || { echo "  ❌ B) join: $JOIN"; FAIL=$((FAIL+1)); exit 1; }

# fixture: 注入 availableAmount=100
$DB -e "UPDATE biz_distributor SET available_amount=100.00, frozen_amount=0, withdraw_amount=0 WHERE distributor_id=$DIST_ID;" 2>/dev/null
INIT_AVAIL=$($DB -N -e "SELECT available_amount FROM biz_distributor WHERE distributor_id=$DIST_ID;" 2>/dev/null | tail -1)
num_eq "$INIT_AVAIL" "100" && echo "  ✅ B+) fixture available=100" && PASS=$((PASS+1)) || { echo "  ❌ B+) avail=$INIT_AVAIL"; FAIL=$((FAIL+1)); }

# C) 提现 30 元
W=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $TOK" \
  -d '{"amount":30.00,"withdrawType":"0","account":"test_wx_c24","accountName":"C24测试"}' \
  $H/api/distributor/withdraw)
W_ID=$(echo "$W" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['withdrawId'])" 2>/dev/null)
W_STATUS=$(echo "$W" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['status'])" 2>/dev/null)
W_AMT=$(echo "$W" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['amount'])" 2>/dev/null)
[ -n "$W_ID" ] && echo "  ✅ C) withdraw (withdrawId=$W_ID amount=$W_AMT status=$W_STATUS)" && PASS=$((PASS+1)) || { echo "  ❌ C) withdraw: $W"; FAIL=$((FAIL+1)); }
[ "$W_STATUS" = "0" ] && echo "  ✅ C+) status=0 (待审核)" && PASS=$((PASS+1)) || { echo "  ❌ C+) status: $W_STATUS"; FAIL=$((FAIL+1)); }
num_eq "$W_AMT" "30" && echo "  ✅ C++) amount=30" && PASS=$((PASS+1)) || { echo "  ❌ C++) amt: $W_AMT"; FAIL=$((FAIL+1)); }

# D) DB 验证: availableAmount 减 30, frozenAmount 不变
NEW_AVAIL=$($DB -N -e "SELECT available_amount FROM biz_distributor WHERE distributor_id=$DIST_ID;" 2>/dev/null | tail -1)
NEW_FROZEN=$($DB -N -e "SELECT IFNULL(frozen_amount,0) FROM biz_distributor WHERE distributor_id=$DIST_ID;" 2>/dev/null | tail -1)
num_eq "$NEW_AVAIL" "70" && echo "  ✅ D) availableAmount 100→70 (申请时锁定)" && PASS=$((PASS+1)) || { echo "  ❌ D) avail=$NEW_AVAIL want 70"; FAIL=$((FAIL+1)); }
num_eq "$NEW_FROZEN" "0" && echo "  ✅ D+) frozenAmount 仍=0 (待审核不冻结)" && PASS=$((PASS+1)) || { echo "  ❌ D+) frozen=$NEW_FROZEN"; FAIL=$((FAIL+1)); }

# E) /withdraw/list 含新提现
WL=$(curl -s -H "Authorization: Bearer $TOK" $H/api/distributor/withdraw/list)
echo "$WL" | grep -q "\"withdrawId\":$W_ID" && echo "  ✅ E) GET /withdraw/list 含新记录" && PASS=$((PASS+1)) || { echo "  ❌ E) list: ${WL:0:200}"; FAIL=$((FAIL+1)); }

# F) /center 聚合正确
CENTER=$(curl -s -H "Authorization: Bearer $TOK" $H/api/distributor/center)
echo "$CENTER" | grep -qE '"availableAmount":\s*70' && echo "  ✅ F) center availableAmount=70" && PASS=$((PASS+1)) || { echo "  ❌ F) center avail: ${CENTER:0:200}"; FAIL=$((FAIL+1)); }
echo "$CENTER" | grep -qE '"withdrawCount":\s*1' && echo "  ✅ F+) center withdrawCount=1" && PASS=$((PASS+1)) || { echo "  ❌ F+) withdrawCount: ${CENTER:0:200}"; FAIL=$((FAIL+1)); }

# G) 防御: 再提现 200 元 → 余额不足
W_FAIL=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $TOK" \
  -d '{"amount":200.00,"withdrawType":"0","account":"test","accountName":"c24"}' \
  $H/api/distributor/withdraw)
echo "$W_FAIL" | grep -q "余额不足\|不足" && echo "  ✅ G) 200 元超额 → 余额不足" && PASS=$((PASS+1)) || { echo "  ❌ G) 超额应拒绝: ${W_FAIL:0:200}"; FAIL=$((FAIL+1)); }

echo "C24 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
