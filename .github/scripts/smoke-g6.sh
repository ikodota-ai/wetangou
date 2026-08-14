#!/usr/bin/env bash
# G6 新会员自邀防御：ApiAuthController.memberId0 真正实现
# 验证:
#   A) 老会员登录：传 inviteBy=自己 memberId → invite_by 不变（防御）
#   B) 老会员登录：传 inviteBy=他人 memberId → invite_by 仍为原值（不覆盖）
#   C) 新会员登录：传 inviteBy=有效他人 → invite_by 写入
#   D) 新会员登录：传 inviteBy=0/不存在 → invite_by 留空
set -e
H=http://127.0.0.1:8080
APPID="${APPID:-wx9e147c4e2151b123}"
DB_CMD="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"

PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

# 用一个会复用的 code 派生稳定 openid
JS_OLD="g6old_$(date +%s)_$$"
JS_NEW="g6new_$(date +%s)_$$"
JS_OTHER="g6oth_$(date +%s)_$$"

OLD_MEMBER_ID=0
NEW_MEMBER_ID=0
OTHER_MEMBER_ID=0
OTHER_OLD_INVITER=0

cleanup() {
  [ "$NEW_MEMBER_ID" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_member WHERE member_id=$NEW_MEMBER_ID;" 2>/dev/null || true
  [ "$OLD_MEMBER_ID" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_member WHERE member_id=$OLD_MEMBER_ID;" 2>/dev/null || true
  [ "$OTHER_MEMBER_ID" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_member WHERE member_id=$OTHER_MEMBER_ID;" 2>/dev/null || true
}
trap cleanup EXIT

echo "G6 新会员自邀防御 smoke:"

# 0) 先建一个"他人"老会员，让新会员有合法邀请目标
LOGIN_OTHER=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JS_OTHER\",\"appid\":\"$APPID\",\"nickName\":\"g6other\"}" $H/api/auth/login)
OTHER_MEMBER_ID=$(echo "$LOGIN_OTHER" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ "$OTHER_MEMBER_ID" -gt 0 ] || { echo "FAIL: other member login"; exit 1; }
# 给 other 写一个原 invite_by 作为"基线"，验证老会员不被覆盖
OTHER_OLD_INVITER=$($DB_CMD -N -e "UPDATE biz_member SET invite_by=$OTHER_MEMBER_ID, invite_time=NOW() WHERE member_id=$OTHER_MEMBER_ID; SELECT invite_by FROM biz_member WHERE member_id=$OTHER_MEMBER_ID;")
echo "[0] other memberId=$OTHER_MEMBER_ID, self-inviter baseline=$OTHER_OLD_INVITER"

# A) 老会员登录 + 传 inviteBy=自己
LOGIN_OLD=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JS_OLD\",\"appid\":\"$APPID\",\"nickName\":\"g6old\",\"inviteBy\":$OTHER_MEMBER_ID}" $H/api/auth/login)
OLD_MEMBER_ID=$(echo "$LOGIN_OLD" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ "$OLD_MEMBER_ID" -gt 0 ] || { echo "FAIL: old member login"; exit 1; }
echo "[A1] old memberId=$OLD_MEMBER_ID created (invite_by should be $OTHER_MEMBER_ID)"
# 确认 old 拿到了合法邀请人（基线建立）
sleep 1
INV_AFTER_FIRST=$($DB_CMD -N -e "SELECT IFNULL(invite_by, 0) FROM biz_member WHERE member_id=$OLD_MEMBER_ID;")
chk "A1 老会员首次邀请人已写入 (=$OTHER_MEMBER_ID)" "$OTHER_MEMBER_ID" "$INV_AFTER_FIRST"

# A2) 老会员再次登录，inviteBy=自己（自邀） → 应被清空，不应写入自己
LOGIN_OLD2=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JS_OLD\",\"appid\":\"$APPID\",\"nickName\":\"g6old\",\"inviteBy\":$OLD_MEMBER_ID}" $H/api/auth/login)
chk "A2 老会员二次登录 HTTP 200" "登录成功" "$LOGIN_OLD2"
sleep 1
INV_AFTER_SELF=$($DB_CMD -N -e "SELECT IFNULL(invite_by, 0) FROM biz_member WHERE member_id=$OLD_MEMBER_ID;")
chk "A2 自邀被拒：invite_by 保持 $OTHER_MEMBER_ID" "$OTHER_MEMBER_ID" "$INV_AFTER_SELF"

# B) 新会员登录：合法 inviteBy=other → 写入
LOGIN_NEW=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JS_NEW\",\"appid\":\"$APPID\",\"nickName\":\"g6new\",\"inviteBy\":$OTHER_MEMBER_ID}" $H/api/auth/login)
NEW_MEMBER_ID=$(echo "$LOGIN_NEW" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ "$NEW_MEMBER_ID" -gt 0 ] || { echo "FAIL: new member login"; exit 1; }
echo "[B] new memberId=$NEW_MEMBER_ID (inviteBy=$OTHER_MEMBER_ID)"
sleep 1
INV_NEW=$($DB_CMD -N -e "SELECT IFNULL(invite_by, 0) FROM biz_member WHERE member_id=$NEW_MEMBER_ID;")
chk "B 新会员合法 invite_by 写入" "$OTHER_MEMBER_ID" "$INV_NEW"

# C) 再起一个全新会员，传 inviteBy=0/不存在 → invite_by 留空
JS_BAD="g6bad_$(date +%s)_$$"
LOGIN_BAD=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JS_BAD\",\"appid\":\"$APPID\",\"nickName\":\"g6bad\",\"inviteBy\":99999999}" $H/api/auth/login)
BAD_MEMBER_ID=$(echo "$LOGIN_BAD" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ "$BAD_MEMBER_ID" -gt 0 ] || { echo "FAIL: bad member login"; exit 1; }
sleep 1
INV_BAD=$($DB_CMD -N -e "SELECT IFNULL(invite_by, 0) FROM biz_member WHERE member_id=$BAD_MEMBER_ID;")
chk "C 不存在 inviteBy=99999999 被拒，invite_by=0" "0" "$INV_BAD"
# 清理 bad member
$DB_CMD -e "DELETE FROM biz_member WHERE member_id=$BAD_MEMBER_ID;" 2>/dev/null || true

echo ""
echo "G6 smoke: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
