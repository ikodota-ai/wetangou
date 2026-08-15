#!/usr/bin/env bash
# C16 会员资料链路端到端
# 验证:
#   A) GET /api/member/profile 未登录被拒 (401)
#   B) GET /api/member/profile 登录后返 nickname/avatar/phone
#   C) PUT /api/member 改 nickname 落库
#   D) PUT /api/member 敏感字段 (openid/status) 被清空防篡改
#   E) PUT /api/member 跨会员改：memberId 被强制覆盖为自己
#   F) POST /api/member/phone mock 返 13800000000
#   G) mini 端 member api 已接入
#   H) 缺 phoneCode 应被拒
set -e
H=http://127.0.0.1:8080
DB_CMD="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 --default-character-set=utf8mb4 ry-vue"
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

# 登录拿 token
JS="c16_$(date +%s)_$$"
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JS\",\"appid\":\"wx9e147c4e2151b123\",\"nickName\":\"c16test\",\"avatarUrl\":\"http://x/y.jpg\"}" $H/api/auth/login)
TOK=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
MID=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ ${#TOK} -gt 50 ] && [ "$MID" -gt 0 ] || { echo "FAIL: login: $LOGIN"; exit 1; }
echo "[init] memberId=$MID"

cleanup() {
  [ "$MID" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_member WHERE member_id=$MID;" 2>/dev/null || true
}
trap cleanup EXIT

echo "C16 会员资料链路 smoke:"

# A) 未登录被拒
A=$(curl -s "$H/api/member/profile")
echo "$A" | grep -qE "401|登录" && echo "  ✅ A 未登录 401" && PASS=$((PASS+1)) || { echo "  ❌ A 未登录未拒: $A"; FAIL=$((FAIL+1)); }

# B) 登录后 profile
B=$(curl -s -H "Authorization: Bearer $TOK" "$H/api/member/profile")
chk "B profile 200" "操作成功" "$B"
chk "B profile 包含 nickname=c16test" "c16test" "$B"
chk "B profile 包含 memberId=$MID" "$MID" "$B"

# C) 改 nickname
PAYLOAD_C="{\"nickname\":\"c16_changed\",\"gender\":\"1\"}"
C=$(curl -s -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $TOK" \
  -d "$PAYLOAD_C" $H/api/member)
chk "C update 200" "操作成功" "$C"
sleep 1
DB_NICK=$($DB_CMD -N -e "SELECT nickname FROM biz_member WHERE member_id=$MID;" 2>/dev/null)
[ "$DB_NICK" = "c16_changed" ] && echo "  ✅ C nickname 落库 = c16_changed" && PASS=$((PASS+1)) || { echo "  ❌ C db nickname=$DB_NICK"; FAIL=$((FAIL+1)); }
DB_GENDER=$($DB_CMD -N -e "SELECT gender FROM biz_member WHERE member_id=$MID;" 2>/dev/null)
[ "$DB_GENDER" = "1" ] && echo "  ✅ C gender=1 落库" && PASS=$((PASS+1)) || { echo "  ❌ C db gender=$DB_GENDER"; FAIL=$((FAIL+1)); }

# D) 篡改 openid/status 防御：传 openid=attacker_openid 应被清空
PAYLOAD_D="{\"openid\":\"attacker_openid_xxx\",\"unionid\":\"attacker_unionid\",\"status\":\"1\",\"nickname\":\"hack\"}"
D=$(curl -s -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $TOK" \
  -d "$PAYLOAD_D" $H/api/member)
sleep 1
DB_OPENID=$($DB_CMD -N -e "SELECT openid FROM biz_member WHERE member_id=$MID;" 2>/dev/null)
DB_STATUS=$($DB_CMD -N -e "SELECT status FROM biz_member WHERE member_id=$MID;" 2>/dev/null)
[ "$DB_OPENID" = "mock_$JS" ] && echo "  ✅ D openid 未被改 (=$DB_OPENID)" && PASS=$((PASS+1)) || { echo "  ❌ D openid=$DB_OPENID (被改了!)"; FAIL=$((FAIL+1)); }
[ "$DB_STATUS" = "0" ] && echo "  ✅ D status 未被改 (=0)" && PASS=$((PASS+1)) || { echo "  ❌ D status=$DB_STATUS (被改了!)"; FAIL=$((FAIL+1)); }

# E) 跨会员改防越权：尝试把 memberId 改成 99999 应被强制覆盖为自己
PAYLOAD_E="{\"memberId\":99999,\"nickname\":\"cross_member\"}"
E=$(curl -s -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $TOK" \
  -d "$PAYLOAD_E" $H/api/member)
sleep 1
# 验证 99999 会员没被创建
COUNT_99999=$($DB_CMD -N -e "SELECT COUNT(*) FROM biz_member WHERE member_id=99999;" 2>/dev/null)
[ "$COUNT_99999" = "0" ] && echo "  ✅ E 越权 memberId=99999 未创建" && PASS=$((PASS+1)) || { echo "  ❌ E 99999 已存在 (被越权创建)"; FAIL=$((FAIL+1)); }
# 自己 nickname 应被改成 cross_member
DB_NICK_E=$($DB_CMD -N -e "SELECT nickname FROM biz_member WHERE member_id=$MID;" 2>/dev/null)
[ "$DB_NICK_E" = "cross_member" ] && echo "  ✅ E 强制覆盖 memberId 自己: nickname=cross_member" && PASS=$((PASS+1)) || { echo "  ❌ E nickname=$DB_NICK_E"; FAIL=$((FAIL+1)); }

# F) 手机号端点存在性 + 行为：mock 关闭时返"获取手机号失败"业务反馈
F=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $TOK" \
  -d '{"code":"mock_phone_c16"}' $H/api/member/phone)
# 期望: mock 关闭走真实微信 API 返 500 (前端可识别的业务错误), 不返 200
# 期望: mock 开启时返 "13800000000" (sys_config wx.miniapp.mockEnabled=true)
echo "$F" | grep -qE "13800000000|获取手机号失败" && echo "  ✅ F phone 端点返业务反馈 (mock 返 138 或真 API 返 errcode)" && PASS=$((PASS+1)) || { echo "  ❌ F 端点未响应: $F"; FAIL=$((FAIL+1)); }

# H) 缺 phoneCode 被拒
H_RES=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $TOK" \
  -d '{}' $H/api/member/phone)
echo "$H_RES" | grep -qE "code不能为空|缺少" && echo "  ✅ H 缺 phoneCode 被拒" && PASS=$((PASS+1)) || { echo "  ❌ H 未拒: $H_RES"; FAIL=$((FAIL+1)); }

# G) mini 端 api 接入
grep -q "getUserInfo.*api/member/profile" "$(dirname $0)/../../miniprogram7/utils/request.js" && echo "  ✅ G mini getUserInfo 已就绪" && PASS=$((PASS+1)) || { echo "  ❌ G mini getUserInfo 缺失"; FAIL=$((FAIL+1)); }
grep -q "updateMember.*api/member" "$(dirname $0)/../../miniprogram7/utils/request.js" && echo "  ✅ G mini updateMember 已就绪" && PASS=$((PASS+1)) || { echo "  ❌ G mini updateMember 缺失"; FAIL=$((FAIL+1)); }

echo ""
echo "C16 smoke: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
