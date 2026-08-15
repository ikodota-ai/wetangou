#!/usr/bin/env bash
# V6-6 PC 后台 RBAC 矩阵 smoke（3 角色 × 5 端点）
# 期望：
#  - admin (role_id=1) → 全 200
#  - 平台/代理商/商户/普通 角色 → 跨域 403，自己的 200
#  - 未登录 → 401
set -e
H=http://127.0.0.1:8080
MYSQL="/usr/local/mysql/bin/mysql --default-character-set=utf8mb4 -uroot -p133301 ry-vue"
PASS=0; FAIL=0

# 准备测试账号（4 个带不同 role 的临时用户）
HASH='$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2'
TS=$(date +%s)
PFX="c44${TS:5:5}"
USERS=("${PFX}_admin" "${PFX}_merchant" "${PFX}_agent" "${PFX}_common")
# admin 复用现有账号
USERS[0]="admin"

# 给每个 user 临时绑 1 个角色
for i in 0 1 2 3; do
  U="${USERS[$i]}"
  if [ "$U" = "admin" ]; then continue; fi
  $MYSQL <<SQL 2>/dev/null
INSERT INTO sys_user (user_name,nick_name,password,status,del_flag,user_type,merchant_id,create_by,create_time)
VALUES ('$U','C44-${U}','$HASH','0','0','00',1,'smoke-c44',NOW());
SET @uid = LAST_INSERT_ID();
SQL
done
# 绑角色：merchant→role_id=5(merchant), agent→role_id=4(agent), common→role_id=2(common)
$MYSQL -N -e "SELECT user_id FROM sys_user WHERE user_name='${PFX}_merchant'" 2>/dev/null > /tmp/c44_m_uid
$MYSQL -N -e "SELECT user_id FROM sys_user WHERE user_name='${PFX}_agent'" 2>/dev/null > /tmp/c44_a_uid
$MYSQL -N -e "SELECT user_id FROM sys_user WHERE user_name='${PFX}_common'" 2>/dev/null > /tmp/c44_c_uid
M_UID=$(cat /tmp/c44_m_uid); A_UID=$(cat /tmp/c44_a_uid); C_UID=$(cat /tmp/c44_c_uid)
$MYSQL -e "INSERT INTO sys_user_role (user_id, role_id) VALUES ($M_UID, 5), ($A_UID, 4), ($C_UID, 2)" 2>/dev/null
echo "test users created: admin + ${PFX}_merchant/agent/common"

# 登录拿 token
login() {
  curl -s -X POST $H/login -H "Content-Type: application/json" \
    -d "{\"username\":\"$1\",\"password\":\"admin123\"}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))"
}
TK_ADMIN=$(login admin)
TK_MER=$(login "${PFX}_merchant")
TK_AGT=$(login "${PFX}_agent")
TK_COM=$(login "${PFX}_common")
echo "tokens: admin=${#TK_ADMIN} mer=${#TK_MER} agt=${#TK_AGT} com=${#TK_COM}"

# 5 端点（admin 后台 + biz 模块）
# 1) GET /getInfo（RuoYi 标准）— 任何登录用户 200
# 2) GET /system/user/list?pageNum=1&pageSize=5 — admin 有 perm sys:user:list，merchant 没有
# 3) GET /biz/staffInvite/list?pageNum=1&pageSize=5 — admin 有 perm biz:staffInvite:list，merchant 没有
# 4) GET /system/menu/list — admin 有
# 5) POST /logout — 任何登录 200

probe() {
  local label="$1" tk="$2" method="$3" path="$4" body="$5" expect_code="$6"
  local auth=()
  if [ -n "$tk" ]; then auth=(-H "Authorization: Bearer $tk"); fi
  local out
  if [ "$method" = "POST" ]; then
    if [ ${#auth[@]} -gt 0 ]; then
      out=$(curl -s -X POST "${auth[@]}" -H "Content-Type: application/json" -d "$body" "$H$path")
    else
      out=$(curl -s -X POST -H "Content-Type: application/json" -d "$body" "$H$path")
    fi
  else
    if [ ${#auth[@]} -gt 0 ]; then
      out=$(curl -s "${auth[@]}" "$H$path")
    else
      out=$(curl -s "$H$path")
    fi
  fi
  local got
  got=$(echo "$out" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('code'))" 2>/dev/null)
  if [ "$got" = "$expect_code" ]; then
    echo "  ✅ $label → $got"
    PASS=$((PASS+1))
  else
    echo "  ❌ $label expect=$expect_code got=$got body=$(echo $out | head -c 150)"
    FAIL=$((FAIL+1))
  fi
}

echo "--- 1) /getInfo (RuoYi 标准鉴权) ---"
probe "admin /getInfo 200"     "$TK_ADMIN" GET "/getInfo" "" "200"
probe "merchant /getInfo 200"  "$TK_MER"   GET "/getInfo" "" "200"
probe "agent /getInfo 200"     "$TK_AGT"   GET "/getInfo" "" "200"
probe "common /getInfo 200"    "$TK_COM"   GET "/getInfo" "" "200"
probe "未登录 /getInfo 401"    ""          GET "/getInfo" "" "401"

echo "--- 2) /system/user/list (admin 域) ---"
probe "admin sys:user 200"     "$TK_ADMIN" GET "/system/user/list?pageNum=1&pageSize=5" "" "200"
probe "merchant sys:user 403"  "$TK_MER"   GET "/system/user/list?pageNum=1&pageSize=5" "" "403"
probe "agent sys:user 403"     "$TK_AGT"   GET "/system/user/list?pageNum=1&pageSize=5" "" "403"
probe "common sys:user 200"    "$TK_COM"   GET "/system/user/list?pageNum=1&pageSize=5" "" "200"

echo "--- 3) /biz/staffInvite/list (biz 域) ---"
probe "admin biz 200"          "$TK_ADMIN" GET "/biz/staffInvite/list?pageNum=1&pageSize=5" "" "200"
probe "merchant biz 403"       "$TK_MER"   GET "/biz/staffInvite/list?pageNum=1&pageSize=5" "" "403"
probe "agent biz 403"          "$TK_AGT"   GET "/biz/staffInvite/list?pageNum=1&pageSize=5" "" "403"
probe "common biz 403"         "$TK_COM"   GET "/biz/staffInvite/list?pageNum=1&pageSize=5" "" "403"

echo "--- 4) /system/menu/list ---"
probe "admin menu 200"         "$TK_ADMIN" GET "/system/menu/list" "" "200"
probe "merchant menu 403"      "$TK_MER"   GET "/system/menu/list" "" "403"

echo "--- 5) POST /logout (无 perms 限制) ---"
probe "merchant logout 200"    "$TK_MER"   POST "/logout" "{}" "200"
probe "common logout 200"      "$TK_COM"   POST "/logout" "{}" "200"

# 清理
$MYSQL <<SQL 2>/dev/null
DELETE FROM sys_user_role WHERE user_id IN ($M_UID, $A_UID, $C_UID);
DELETE FROM sys_user WHERE user_name IN ('${PFX}_merchant','${PFX}_agent','${PFX}_common');
SQL

echo "============================="
echo "V6-6 smoke: $PASS pass / $FAIL fail"
[ $FAIL -eq 0 ] || exit 1
