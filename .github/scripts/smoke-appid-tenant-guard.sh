#!/usr/bin/env bash
# 商家端/会员端登录的 appid 归属校验
#
# 背景（真实事故）：商户 1 的老板账号，在商户 200 的小程序里输账号密码
# 居然能登进商家版，还能切到会员端。原因是三处都没把 appid 当作先决条件：
#   1) /api/merchant/staff/login 不像 wxLogin 那样按 appid 收敛员工关联
#   2) token 里不记签发它的 appid，签发后带任意 X-App-Id 都能继续用
#   3) /api/auth/login 会员授权链路识别员工身份时也没按商户过滤
#
# 兼容口径：token 无 appid（老 token）或请求无 X-App-Id 时放行，只拦「两者都有且不等」。
set -u
BASE="${BASE:-http://localhost:8080}"
APP_M1="wx9e147c4e2151b123"        # 商户 1
APP_M200="wx-test-agent02-0001"    # 商户 200
OWNER_USER="owner_c43"; OWNER_PWD="admin123"

PASS=0; FAIL=0
ck() {
  local name="$1" got="$2" exp="$3"
  if [ "$got" = "$exp" ]; then echo "PASS | $name"; PASS=$((PASS+1));
  else echo "FAIL | $name | got=[$got] exp=[$exp]"; FAIL=$((FAIL+1)); fi
}
jget() { python3 -c "import sys,json
try: d=json.load(sys.stdin)
except Exception: print(''); raise SystemExit
v=d
for k in '$1'.split('.'):
    v = v.get(k) if isinstance(v,dict) else None
print('' if v is None else v)"; }

login_body() {  # $1=appid（空则不带）
  if [ -z "${1:-}" ]; then echo "{\"username\":\"$OWNER_USER\",\"password\":\"$OWNER_PWD\"}";
  else echo "{\"username\":\"$OWNER_USER\",\"password\":\"$OWNER_PWD\",\"appid\":\"$1\"}"; fi
}
do_login() {
  curl -s -X POST "$BASE/api/merchant/staff/login" -H 'Content-Type: application/json' -d "$(login_body "${1:-}")"
}

echo "=== appid 租户归属校验 ($BASE) ==="

# --- A) 密码登录必须按 appid 收敛员工关联 ---
R=$(do_login "$APP_M1")
ck "本商户 appid 可登录"            "$(echo "$R" | jget code)"       "200"
ck "本商户 appid 身份为 owner"      "$(echo "$R" | jget userType)"   "owner"
ck "本商户 appid 商户号正确"        "$(echo "$R" | jget merchantId)" "1"

R=$(do_login "$APP_M200")
ck "他家 appid 登录被拒"            "$(echo "$R" | jget code)"       "500"
ck "他家 appid 不下发身份"          "$(echo "$R" | jget userType)"   ""
ck "他家 appid 不下发 token"        "$(echo "$R" | jget token)"      ""

R=$(do_login "wxNOTEXIST0000000")
ck "未接入 appid 登录被拒"          "$(echo "$R" | jget code)"       "500"

R=$(do_login "")
ck "不带 appid 仍放行（存量兼容）"  "$(echo "$R" | jget code)"       "200"

# --- B) token 必须锚定签发它的 appid ---
TK=$(do_login "$APP_M1" | jget token)
ck "拿到商户1的 staff token"        "$([ -n "$TK" ] && echo yes || echo no)" "yes"

C=$(curl -s "$BASE/api/merchant/staff/me" -H "Authorization: Bearer $TK" -H "X-App-Id: $APP_M1" | jget code)
ck "同源 appid 调 /me 放行"         "$C" "200"

C=$(curl -s "$BASE/api/merchant/staff/me" -H "Authorization: Bearer $TK" -H "X-App-Id: $APP_M200" | jget code)
ck "跨 appid 调 /me 拒绝"           "$C" "401"

S=$(curl -s "$BASE/api/merchant/staff/me" -H "Authorization: Bearer $TK" -H "X-App-Id: $APP_M200" | jget authScope)
ck "跨 appid 返回 authScope=staff"  "$S" "staff"

C=$(curl -s "$BASE/api/merchant/staff/home" -H "Authorization: Bearer $TK" -H "X-App-Id: $APP_M200" | jget code)
ck "跨 appid 调 /home 拒绝"         "$C" "401"

C=$(curl -s "$BASE/api/merchant/staff/me" -H "Authorization: Bearer $TK" | jget code)
ck "不带 X-App-Id 放行（存量兼容）" "$C" "200"

# --- C) 会员授权链路识别员工身份同样要按商户收敛 ---
AUTH() { curl -s -X POST "$BASE/api/auth/login" -H 'Content-Type: application/json' \
         -H "X-App-Id: $1" -d "{\"code\":\"c53_owner\",\"appid\":\"$1\"}"; }
R=$(AUTH "$APP_M1")
ck "同源商户授权识别为员工"         "$(echo "$R" | jget loginType)" "staff"
ck "同源商户授权 userType=owner"    "$(echo "$R" | jget userType)"  "owner"

R=$(AUTH "$APP_M200")
ck "他家商户授权不识别为员工"       "$(echo "$R" | jget loginType)" "member"
ck "他家商户授权 isStaff=false"     "$(echo "$R" | jget isStaff)"   "False"

# body 带 appid 但 header 缺失：租户上下文须以 body 解析结果为准，
# 否则 selectMemberByOpenid 查商户1、insert 也落商户1，撞 uk_merchant_openid 报 500
C=$(curl -s -X POST "$BASE/api/auth/login" -H 'Content-Type: application/json' \
    -d "{\"code\":\"c53_owner\",\"appid\":\"$APP_M200\"}" | jget code)
ck "仅 body 带 appid 不再撞唯一键"  "$C" "200"

# --- 清理：C 段的跨商户授权会在商户 200 下建一条会员记录 ---
MYSQL="${MYSQL:-/usr/local/mysql/bin/mysql}"
if [ -x "$MYSQL" ]; then
  "$MYSQL" -uroot -p133301 ry-vue --default-character-set=utf8mb4 -N -B \
    -e "delete from biz_member where openid='mock_c53_owner' and merchant_id=200;" 2>/dev/null
  echo "[cleanup] 已清理商户200下的测试会员"
fi

echo "=== PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ]
