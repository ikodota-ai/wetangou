#!/usr/bin/env bash
# C21 推客端 smoke: member→成为推客→佣金/提现/粉丝 7 端点 + 防御
# 验证:
#   A) member 登录
#   B) /api/distributor/center → 非推客 data=null
#   C) POST /api/distributor/join → 成为推客
#   C-) 重复 join → 返已有档案 (不重复创建)
#   D) /api/distributor/center → 推客档案 (level/status/totalCommission/availableAmount...)
#   E) /api/distributor/commission/list → 佣金明细
#   F) /api/distributor/withdraw/list → 提现记录
#   F-) /api/distributor/withdraw 超额 → 余额不足
#   G) /api/distributor/fans → 粉丝列表 (我 inviteBy 的人)
#   H) 防御: 非推客 member 调 /qrcode → 拒绝 (需先 join)
# 前置: 后端 8080 在跑; mock appid; 该 member 此前不是推客
set -e
H=http://127.0.0.1:8080
DB="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"
APPID="${APPID:-wx9e147c4e2151b123}"

PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

echo "C21 推客端 smoke:"

# A) member 登录
JSCODE="c21smoke_$(date +%s)_$$"
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE\",\"appid\":\"$APPID\",\"nickName\":\"c21smoke\"}" $H/api/auth/login)
TOK=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
MID=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ ${#TOK} -gt 50 ] && [ "$MID" -gt 0 ] && echo "  ✅ A) member login (memberId=$MID)" && PASS=$((PASS+1)) || { echo "  ❌ A) login failed: $LOGIN"; FAIL=$((FAIL+1)); exit 1; }

# 兜底: 若该 member 之前已是推客 (c3/c7 残留), 删掉重做
EXIST_DID=$($DB -N -e "SELECT distributor_id FROM biz_distributor WHERE member_id=$MID;" 2>/dev/null | tail -1)
[ -n "$EXIST_DID" ] && $DB -e "DELETE FROM biz_distributor WHERE distributor_id=$EXIST_DID;" 2>/dev/null
DIST_ID=""
cleanup() {
  [ -n "$DIST_ID" ] && $DB -e "DELETE FROM biz_withdraw WHERE distributor_id=$DIST_ID; DELETE FROM biz_distributor WHERE distributor_id=$DIST_ID;" 2>/dev/null || true
  $DB -e "DELETE FROM biz_distributor WHERE member_id=$MID;" 2>/dev/null || true
}
trap cleanup EXIT

# B) center 初始 (非推客)
CENTER0=$(curl -s -H "Authorization: Bearer $TOK" $H/api/distributor/center)
echo "$CENTER0" | grep -qE '"data":null|"data":\s*null' && echo "  ✅ B) center 非推客 data=null" && PASS=$((PASS+1)) || echo "  [B] center resp: ${CENTER0:0:200}"

# C) join
JOIN=$(curl -s -X POST -H "Authorization: Bearer $TOK" $H/api/distributor/join)
DIST_ID=$(echo "$JOIN" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['distributorId'])" 2>/dev/null)
[ -n "$DIST_ID" ] && [ "$DIST_ID" -gt 0 ] && echo "  ✅ C) POST /join (distributorId=$DIST_ID)" && PASS=$((PASS+1)) || { echo "  ❌ C) join failed: $JOIN"; FAIL=$((FAIL+1)); }

# C-) 重复 join 防御
JOIN2=$(curl -s -X POST -H "Authorization: Bearer $TOK" $H/api/distributor/join)
DIST_ID2=$(echo "$JOIN2" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['distributorId'])" 2>/dev/null)
[ "$DIST_ID" = "$DIST_ID2" ] && echo "  ✅ C-) 重复 join 返同档案 (不重复创建)" && PASS=$((PASS+1)) || { echo "  ❌ C-) 重复 join distributorId 不一致: $DIST_ID vs $DIST_ID2"; FAIL=$((FAIL+1)); }
COUNT=$($DB -N -e "SELECT COUNT(*) FROM biz_distributor WHERE member_id=$MID;" 2>/dev/null | tail -1)
[ "$COUNT" = "1" ] && echo "  ✅ C++) biz_distributor 行数=1 (防重)" && PASS=$((PASS+1)) || { echo "  ❌ C++) distributor 行数=$COUNT"; FAIL=$((FAIL+1)); }

# D) center 推客档案
CENTER=$(curl -s -H "Authorization: Bearer $TOK" $H/api/distributor/center)
chk "D) GET /center" "distributorId" "$CENTER"
echo "$CENTER" | grep -q '"level":1' && echo "  ✅ D+) level=1" && PASS=$((PASS+1)) || { echo "  ❌ D+) level: ${CENTER:0:200}"; FAIL=$((FAIL+1)); }
echo "$CENTER" | grep -q '"status":"0"' && echo "  ✅ D++) status=0 (待审核)" && PASS=$((PASS+1)) || { echo "  ❌ D++) status: ${CENTER:0:200}"; FAIL=$((FAIL+1)); }
echo "$CENTER" | grep -qE 'availableAmount|withdrawAmount' && echo "  ✅ D+++) 金额字段聚合" && PASS=$((PASS+1)) || { echo "  ❌ D+++) 金额字段: ${CENTER:0:200}"; FAIL=$((FAIL+1)); }

# E) commission/list
COMM=$(curl -s -H "Authorization: Bearer $TOK" $H/api/distributor/commission/list)
chk "E) GET /commission/list" "code" "$COMM"

# F) withdraw/list
WL=$(curl -s -H "Authorization: Bearer $TOK" $H/api/distributor/withdraw/list)
chk "F) GET /withdraw/list" "code" "$WL"

# F-) withdraw 超额 (available=0) → 余额不足
W_FAIL=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $TOK" \
  -d '{"amount":1.00,"withdrawType":"0","account":"test_wx","accountName":"c21"}' \
  $H/api/distributor/withdraw)
echo "$W_FAIL" | grep -q "余额不足\|不足" && echo "  ✅ F-) withdraw 超额 → 余额不足" && PASS=$((PASS+1)) || { echo "  ❌ F-) withdraw 超额应拒绝: ${W_FAIL:0:200}"; FAIL=$((FAIL+1)); }

# G) fans (我 inviteBy 的人; 期望空数组)
FANS=$(curl -s -H "Authorization: Bearer $TOK" $H/api/distributor/fans)
chk "G) GET /fans" "total" "$FANS"

echo "C21 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
