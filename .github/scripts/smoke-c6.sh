#!/usr/bin/env bash
# C6 太阳码 + 扫码入会 + 自动归属 commission 链路
# 验证:
#   A) distributor 会员登录 → token + memberId
#   B) GET /api/distributor/qrcode → scene=distributor:1:<memberId>
#   C) 新会员 mock 登录 + 传 inviteBy → invite_by 写入
#   D) 新会员下单（不传 distributorId）→ placeOrder 通过 inviteBy 自动归属
#   E) prepay mock → commission 入账到该 distributor
set -e
H=http://127.0.0.1:8080
APPID="${APPID:-wx9e147c4e2151b123}"
DB_CMD="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"

JSCODE="c6smoke_$(date +%s)_$$"
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}
num_eq() { python3 -c "import sys; sys.exit(0 if abs($1 - $2) < 0.01 else 1)"; }

DIST_MEMBER_ID=""
DIST_ID=""
NEW_MEMBER_ID=""
NEW_ORDER_ID=""
COMM_ID=""

cleanup() {
  [ -n "$NEW_ORDER_ID" ] && $DB_CMD -e "DELETE FROM biz_order WHERE order_id=$NEW_ORDER_ID;" 2>/dev/null || true
  [ -n "$COMM_ID" ] && $DB_CMD -e "DELETE FROM biz_commission WHERE commission_id=$COMM_ID;" 2>/dev/null || true
  [ -n "$DIST_ID" ] && $DB_CMD -e "DELETE FROM biz_distributor WHERE distributor_id=$DIST_ID;" 2>/dev/null || true
  [ -n "$NEW_MEMBER_ID" ] && $DB_CMD -e "DELETE FROM biz_member WHERE member_id=$NEW_MEMBER_ID;" 2>/dev/null || true
  [ -n "$DIST_MEMBER_ID" ] && $DB_CMD -e "DELETE FROM biz_member WHERE member_id=$DIST_MEMBER_ID;" 2>/dev/null || true
}
trap cleanup EXIT

echo "C6 太阳码+扫码入会+自动归属 链路 smoke:"

# A) distributor 会员 mock 登录
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE\",\"appid\":\"$APPID\",\"nickName\":\"c6dist\"}" $H/api/auth/login)
DIST_TOKEN=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
DIST_MEMBER_ID=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ ${#DIST_TOKEN} -gt 50 ] && [ "$DIST_MEMBER_ID" -gt 0 ] || { echo "FAIL: dist member login"; exit 1; }
echo "[A] distributor memberId=$DIST_MEMBER_ID"

# 把 dist member 升级为 distributor (level=1, mid=1)
DIST_ID=$($DB_CMD -N -e "
INSERT INTO biz_distributor (member_id, merchant_id, level, status, join_time, create_time)
VALUES ($DIST_MEMBER_ID, 1, 1, '0', NOW(), NOW());
SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
echo "[A+] distributor_id=$DIST_ID"

# B) GET /api/distributor/qrcode → scene 应含 dist_member_id
QR=$(curl -s -H "Authorization: Bearer $DIST_TOKEN" $H/api/distributor/qrcode)
echo "  [B] qrcode resp: $(echo $QR | head -c 250)"
SCENE=$(echo "$QR" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('scene','') or d.get('data',{}).get('scene',''))" 2>/dev/null)
EXPECTED_SCENE="distributor:1:$DIST_MEMBER_ID"
[ "$SCENE" = "$EXPECTED_SCENE" ] && echo "  ✅ B) scene=$SCENE (匹配 distributor:1:$DIST_MEMBER_ID)" && PASS=$((PASS+1)) || { echo "  ❌ B) scene=$SCENE want $EXPECTED_SCENE"; FAIL=$((FAIL+1)); }
QR_URL=$(echo "$QR" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('url','') or d.get('data',{}).get('url',''))" 2>/dev/null)
[ -n "$QR_URL" ] && echo "  [B+] qrcode url: $(echo $QR_URL | head -c 80)" || echo "  ⚠️  qrcode url empty"

# C) 新会员 mock 登录 + 传 inviteBy
NEW_JSCODE="c6new_$(date +%s)_$$"
NEW_LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$NEW_JSCODE\",\"appid\":\"$APPID\",\"nickName\":\"c6new\",\"inviteBy\":$DIST_MEMBER_ID}" \
  $H/api/auth/login)
NEW_TOKEN=$(echo "$NEW_LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
NEW_MEMBER_ID=$(echo "$NEW_LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ ${#NEW_TOKEN} -gt 50 ] && [ "$NEW_MEMBER_ID" -gt 0 ] || { echo "FAIL: new member login"; exit 1; }
echo "[C] new memberId=$NEW_MEMBER_ID (with inviteBy=$DIST_MEMBER_ID)"

DB_INVITE=$($DB_CMD -N -e "SELECT IFNULL(invite_by,0) FROM biz_member WHERE member_id=$NEW_MEMBER_ID;" 2>/dev/null)
[ "$DB_INVITE" = "$DIST_MEMBER_ID" ] && echo "  ✅ C+) biz_member.invite_by=$DB_INVITE (自动归属)" && PASS=$((PASS+1)) || { echo "  ❌ C+) invite_by=$DB_INVITE want $DIST_MEMBER_ID"; FAIL=$((FAIL+1)); }

# D) 新会员下单 (不传 distributorId) → placeOrder 通过 inviteBy 推断
RESP=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $NEW_TOKEN" \
  -d '{"productId":1000,"num":1}' $H/api/order)
NEW_ORDER_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['orderId'])" 2>/dev/null)
PAY_AMOUNT=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['payAmount'])" 2>/dev/null)
ORDER_DIST_ID=$($DB_CMD -N -e "SELECT IFNULL(distributor_id,0) FROM biz_order WHERE order_id=$NEW_ORDER_ID;" 2>/dev/null)
[ -n "$NEW_ORDER_ID" ] && [ "$NEW_ORDER_ID" -gt 0 ] && echo "  ✅ D1) POST /api/order (orderId=$NEW_ORDER_ID payAmount=$PAY_AMOUNT)" && PASS=$((PASS+1)) || { echo "  ❌ D1) no orderId: $RESP"; FAIL=$((FAIL+1)); exit 1; }
[ "$ORDER_DIST_ID" = "$DIST_ID" ] && echo "  ✅ D2) order.distributor_id=$ORDER_DIST_ID = $DIST_ID (通过 inviteBy 自动归属)" && PASS=$((PASS+1)) || { echo "  ❌ D2) distributor_id=$ORDER_DIST_ID want $DIST_ID"; FAIL=$((FAIL+1)); }

# E) prepay mock → commission 入账
PREPAY=$(curl -s -X POST -H "Authorization: Bearer $NEW_TOKEN" $H/api/order/prepay/$NEW_ORDER_ID)
chk "E1) POST /api/order/prepay (mock)" "mock" "$PREPAY"

sleep 1
COMM_ROW=$($DB_CMD -N -e "SELECT commission_id, distributor_id, amount, rate FROM biz_commission WHERE order_id=$NEW_ORDER_ID;" 2>/dev/null)
echo "  [E2] commission row: '$COMM_ROW'"
COMM_ID=$(echo "$COMM_ROW" | awk '{print $1}')
COMM_DIST=$(echo "$COMM_ROW" | awk '{print $2}')
COMM_AMT=$(echo "$COMM_ROW" | awk '{print $3}')

if [ -n "$COMM_ID" ] && [ "$COMM_ID" -gt 0 ]; then
  echo "  ✅ E2) biz_commission 新行 (id=$COMM_ID distId=$COMM_DIST amount=$COMM_AMT)"
  PASS=$((PASS+1))
  EXPECTED_AMT=$(python3 -c "print(round($PAY_AMOUNT * 0.10, 2))")
  if num_eq "$COMM_AMT" "$EXPECTED_AMT"; then
    echo "  ✅ E3) amount=$COMM_AMT ≈ payAmount($PAY_AMOUNT) * 10%"
    PASS=$((PASS+1))
  else
    echo "  ❌ E3) amount=$COMM_AMT want ~$EXPECTED_AMT"
    FAIL=$((FAIL+1))
  fi
  if [ "$COMM_DIST" = "$DIST_ID" ]; then
    echo "  ✅ E4) commission.distributor_id=$COMM_DIST = $DIST_ID (扫码入会链路正确)"
    PASS=$((PASS+1))
  else
    echo "  ❌ E4) distributor_id=$COMM_DIST want $DIST_ID"
    FAIL=$((FAIL+1))
  fi
else
  echo "  ❌ E2) no commission row for orderId=$NEW_ORDER_ID"
  FAIL=$((FAIL+1))
fi

# F) 防自邀: 第二次用同 openid 登录 + inviteBy=自己 memberId 应被拒 (走 else 分支 line 130)
SAME_CODE_LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$NEW_JSCODE\",\"appid\":\"$APPID\",\"nickName\":\"c6new\",\"inviteBy\":$NEW_MEMBER_ID}" \
  $H/api/auth/login)
SAME_INVITE=$($DB_CMD -N -e "SELECT IFNULL(invite_by,0) FROM biz_member WHERE member_id=$NEW_MEMBER_ID;" 2>/dev/null)
# 已存在会员 + invite_by 不为空 (line 130 短路) → 不会改 invite_by, 仍是 C 阶段写入的 $DIST_MEMBER_ID
[ "$SAME_INVITE" = "$DIST_MEMBER_ID" ] && echo "  ✅ F) 防自邀: 二次登录传自己 memberId 不会覆盖 invite_by=$SAME_INVITE (仍=$DIST_MEMBER_ID)" && PASS=$((PASS+1)) || { echo "  ❌ F) invite_by=$SAME_INVITE want $DIST_MEMBER_ID (不变)"; FAIL=$((FAIL+1)); }

echo "C6 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
