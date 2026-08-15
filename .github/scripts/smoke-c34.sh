#!/usr/bin/env bash
# C34 acceptInvite 状态机 + scene 边界端到端
# 验证:
#   A) admin login
#   B) 创建邀请码 (mid=1, sid=100, role=STAFF, expire=1h) → inviteId
#   C) acceptInvite happy path → 200 + token + 邀请码 status=1
#   D) 同一邀请码再调 → status=1 拒绝 "已失效"
#   E) 创建过期邀请码 (expire=-1h) → acceptInvite 拒绝 "已过期" + 邀请码 status=2
#   F) scene 串号 (mid=999) → "邀请码与门店不匹配"
#   G) scene 格式错 (parts.length != 4) → "邀请码格式错误"
#   H) code+scene 都为空 → "缺少 code 或 scene"
#   I) 邀请码不存在 (code=NOTEXIST_999) → "邀请码不存在"
#   J) DB 状态机回归: used_by/used_at 已写
# 前置: 后端 8080 在跑; wxconfig mock 模式开启
set -e
H=http://127.0.0.1:8080
DB="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"

PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

echo "C34 acceptInvite 状态机 + scene 边界端到端:"

# A) admin token
ADMIN_TOK=$(curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' $H/login | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
[ ${#ADMIN_TOK} -gt 50 ] && echo "  ✅ A) admin login" && PASS=$((PASS+1)) || { echo "  ❌ A) login"; FAIL=$((FAIL+1)); exit 1; }

# B) 创建邀请码
TS=$(date +%s | tail -c 7)
CODE_OK="C${TS}A"
SCENE_OK="invite:1:100:${CODE_OK}"
EXP=$(python3 -c "from datetime import datetime, timedelta; print((datetime.now()+timedelta(hours=1)).strftime('%Y-%m-%d %H:%M:%S'))")
B=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $ADMIN_TOK" \
  -d "{\"merchantId\":1,\"storeId\":100,\"role\":\"STAFF\",\"inviteCode\":\"${CODE_OK}\",\"expireAt\":\"${EXP}\",\"scene\":\"${SCENE_OK}\"}" $H/biz/staffInvite)
INV_ID=$($DB -N -e "SELECT invite_id FROM biz_merchant_staff_invite WHERE invite_code='${CODE_OK}';" 2>/dev/null | head -1)
[ -n "$INV_ID" ] && [ "$INV_ID" -gt 0 ] && echo "  ✅ B) 创建邀请码 id=$INV_ID code=$CODE_OK" && PASS=$((PASS+1)) || { echo "  ❌ B) 创建失败: $B"; FAIL=$((FAIL+1)); exit 1; }

# 清理: 跑完删掉这个邀请码 + 可能创建出来的 staff 行
trap '{
  $DB -e "DELETE FROM biz_merchant_staff WHERE merchant_id=1 AND store_id=100 AND role=\"C34TEST\";" 2>/dev/null
  $DB -e "DELETE FROM sys_user WHERE user_name LIKE \"c34_%\";" 2>/dev/null
  $DB -e "DELETE FROM biz_merchant_staff_invite WHERE invite_code LIKE \"C%\";" 2>/dev/null
} 2>/dev/null || true' EXIT

# C) acceptInvite happy path
C=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"mock_${TS}_ok\",\"scene\":\"${SCENE_OK}\",\"nickName\":\"c34_happy\"}" $H/api/merchant/staff/acceptInvite)
chk "C) happy 200" "操作成功" "$C"
echo "$C" | grep -q '"token"' && echo "  ✅ C+) token 返回" && PASS=$((PASS+1)) || { echo "  ❌ C+) token: ${C:0:200}"; FAIL=$((FAIL+1)); }
# 状态机断言
ST=$($DB -N -e "SELECT status FROM biz_merchant_staff_invite WHERE invite_id=$INV_ID;" 2>/dev/null | head -1)
[ "$ST" = "1" ] && echo "  ✅ C++) status=1 已用" && PASS=$((PASS+1)) || { echo "  ❌ C++) status=$ST"; FAIL=$((FAIL+1)); }
USED_BY=$($DB -N -e "SELECT IFNULL(used_by,0) FROM biz_merchant_staff_invite WHERE invite_id=$INV_ID;" 2>/dev/null | head -1)
[ "$USED_BY" -gt 0 ] && echo "  ✅ C+++) used_by=$USED_BY" && PASS=$((PASS+1)) || { echo "  ❌ C+++) used_by=$USED_BY"; FAIL=$((FAIL+1)); }
USED_AT=$($DB -N -e "SELECT used_at FROM biz_merchant_staff_invite WHERE invite_id=$INV_ID;" 2>/dev/null | head -1)
[ -n "$USED_AT" ] && [ "$USED_AT" != "NULL" ] && echo "  ✅ C++++) used_at 已写" && PASS=$((PASS+1)) || { echo "  ❌ C++++) used_at=$USED_AT"; FAIL=$((FAIL+1)); }

# D) 同码再调 (status=1 应拒绝)
D=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"mock_${TS}_replay\",\"scene\":\"${SCENE_OK}\",\"nickName\":\"c34_replay\"}" $H/api/merchant/staff/acceptInvite)
chk "D) 已用拒绝" "已失效" "$D"

# E) 过期邀请码
CODE_EXP="C${TS}E"
SCENE_EXP="invite:1:100:${CODE_EXP}"
EXP_PAST=$(python3 -c "from datetime import datetime, timedelta; print((datetime.now()-timedelta(hours=1)).strftime('%Y-%m-%d %H:%M:%S'))")
curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $ADMIN_TOK" \
  -d "{\"merchantId\":1,\"storeId\":100,\"role\":\"STAFF\",\"inviteCode\":\"${CODE_EXP}\",\"expireAt\":\"${EXP_PAST}\",\"scene\":\"${SCENE_EXP}\"}" $H/biz/staffInvite > /dev/null
INV_ID_EXP=$($DB -N -e "SELECT invite_id FROM biz_merchant_staff_invite WHERE invite_code='${CODE_EXP}';" 2>/dev/null | head -1)
E=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"mock_${TS}_exp\",\"scene\":\"${SCENE_EXP}\",\"nickName\":\"c34_exp\"}" $H/api/merchant/staff/acceptInvite)
chk "E) 过期拒绝" "已过期" "$E"
ST_EXP=$($DB -N -e "SELECT status FROM biz_merchant_staff_invite WHERE invite_id=$INV_ID_EXP;" 2>/dev/null | head -1)
[ "$ST_EXP" = "2" ] && echo "  ✅ E+) 过期自动 status=2" && PASS=$((PASS+1)) || { echo "  ❌ E+) status=$ST_EXP"; FAIL=$((FAIL+1)); }

# F) scene 串号 (mid=999) — 建一个干净的未过期未用邀请码专测 scene 串号分支
CODE_FX="F${TS}A"
SCENE_FX="invite:1:100:${CODE_FX}"
curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $ADMIN_TOK" \
  -d "{\"merchantId\":1,\"storeId\":100,\"role\":\"STAFF\",\"inviteCode\":\"${CODE_FX}\",\"expireAt\":\"${EXP}\",\"scene\":\"${SCENE_FX}\"}" $H/biz/staffInvite > /dev/null
# 串号: mid=999 (与邀请码 mid=1 不一致)
F=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"mock_${TS}_bad\",\"scene\":\"invite:999:100:${CODE_FX}\",\"nickName\":\"x\"}" $H/api/merchant/staff/acceptInvite)
chk "F) scene 串号拒绝" "邀请码与门店不匹配" "$F"

# G) scene 格式错
G=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"mock_x\",\"scene\":\"badformat\",\"nickName\":\"x\"}" $H/api/merchant/staff/acceptInvite)
chk "G) scene 格式错" "邀请码格式错误" "$G"

# H) code+scene 都为空
H_R=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"nickName\":\"x\"}" $H/api/merchant/staff/acceptInvite)
chk "H) 缺参" "缺少 code 或 scene" "$H_R"

# I) 邀请码不存在
I=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"mock_${TS}_nf\",\"scene\":\"invite:1:100:NOTEXIST_999\",\"nickName\":\"x\"}" $H/api/merchant/staff/acceptInvite)
chk "I) 邀请码不存在" "邀请码不存在" "$I"

echo "C34 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
