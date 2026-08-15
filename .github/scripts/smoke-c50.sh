#!/usr/bin/env bash
# V6-3 员工待审核工作流 smoke
set -u
H=http://127.0.0.1:8080
MYSQL="/usr/local/mysql/bin/mysql --default-character-set=utf8mb4 -uroot -p133301 ry-vue"
PASS=0; FAIL=0

check() {
  local label="$1" expected="$2" got="$3"
  if [ "$got" = "$expected" ]; then echo "  ✅ $label  ($got)"; PASS=$((PASS+1))
  else echo "  ❌ $label  expect=$expected got=$got"; FAIL=$((FAIL+1)); fi
}

login() {
  curl -s -X POST $H/api/merchant/staff/login \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$1\",\"password\":\"admin123\"}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))"
}

TK_OWNER=$(login owner_c43)
TK_STAFF=$(login staff_c43)
TK_ADMIN=$(curl -s -X POST $H/login -H "Content-Type: application/json"   -d '{"username":"admin","password":"admin123"}' | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
[ -n "$TK_OWNER" ] || { echo "OWNER login failed"; exit 2; }
[ -n "$TK_ADMIN" ] || { echo "ADMIN login failed"; exit 2; }
echo "owner_token_len=${#TK_OWNER} admin_token_len=${#TK_ADMIN}"

# bcrypt('admin123')
HASH='$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2'

TS=$(date +%s)
USER="staff_v63_${TS}"

# 准备：插一条待审核 staff（直接 SQL，因为新建账号需密码）
$MYSQL <<SQL 2>/dev/null
INSERT INTO sys_user (user_name,nick_name,password,status,del_flag,user_type,merchant_id,create_by,create_time)
VALUES ('$USER','V63-$TS','$HASH','0','0','00',1,'smoke-v63',NOW());
SET @uid = LAST_INSERT_ID();
INSERT INTO sys_user_role (user_id, role_id) SELECT @uid, r.role_id FROM sys_role r WHERE r.role_key='common' LIMIT 1;
INSERT INTO biz_merchant_staff (merchant_id, store_id, user_id, role, status, create_by, create_time)
VALUES (1, 1, @uid, 'STAFF', '3', 'smoke-v63', NOW());
SQL

SID=$($MYSQL -N -e "SELECT id FROM biz_merchant_staff WHERE user_id=(SELECT user_id FROM sys_user WHERE user_name='$USER') ORDER BY id DESC LIMIT 1" 2>/dev/null)
UID_=$($MYSQL -N -e "SELECT user_id FROM sys_user WHERE user_name='$USER'" 2>/dev/null)
echo "created staff sid=$SID userId=$UID_ user=$USER"

# 3) OWNER 列出待审核
LIST=$(curl -s -H "Authorization: Bearer $TK_ADMIN" "$H/biz/staffInvite/staff/audit")
COUNT=$(echo "$LIST" | python3 -c "import sys,json; d=json.load(sys.stdin); rows=d.get('data') or []; print(sum(1 for r in rows if r.get('userId')==$UID_))" 2>/dev/null)
check "OWNER 看到待审核员工" "1" "$COUNT"

# 4) OWNER 审核通过
RES=$(curl -s -X POST -H "Authorization: Bearer $TK_ADMIN" -H "Content-Type: application/json" \
  -d "{\"id\":$SID,\"approve\":true}" "$H/biz/staffInvite/staff/audit")
APV=$(echo "$RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code'))" 2>/dev/null)
check "审核通过 200" "200" "$APV"
ST=$($MYSQL -N -e "SELECT status FROM biz_merchant_staff WHERE id=$SID" 2>/dev/null)
check "DB status=0" "0" "$ST"

# 5) 再次审核同一条（应失败）
RES2=$(curl -s -X POST -H "Authorization: Bearer $TK_ADMIN" -H "Content-Type: application/json" \
  -d "{\"id\":$SID,\"approve\":true}" "$H/biz/staffInvite/staff/audit")
MSG=$(echo "$RES2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('msg',''))" 2>/dev/null)
echo "$MSG" | grep -q "不在待审核状态" && check "重复审核拒绝" "yes" "yes" || check "重复审核拒绝" "yes" "no: $MSG"

# 6) 拒绝流程：再插一条
TS2=$(date +%s%N)
USER2="staff_v63r_${TS2}"
$MYSQL <<SQL 2>/dev/null
INSERT INTO sys_user (user_name,nick_name,password,status,del_flag,user_type,merchant_id,create_by,create_time)
VALUES ('$USER2','V63R','$HASH','0','0','00',1,'smoke-v63',NOW());
SET @uid = LAST_INSERT_ID();
INSERT INTO sys_user_role (user_id, role_id) SELECT @uid, r.role_id FROM sys_role r WHERE r.role_key='common' LIMIT 1;
INSERT INTO biz_merchant_staff (merchant_id, store_id, user_id, role, status, create_by, create_time)
VALUES (1, 1, @uid, 'STAFF', '3', 'smoke-v63', NOW());
SQL
SID2=$($MYSQL -N -e "SELECT id FROM biz_merchant_staff WHERE user_id=(SELECT user_id FROM sys_user WHERE user_name='$USER2') ORDER BY id DESC LIMIT 1" 2>/dev/null)
echo "reject-flow staff id=$SID2"
RES3=$(curl -s -X POST -H "Authorization: Bearer $TK_ADMIN" -H "Content-Type: application/json" \
  -d "{\"id\":$SID2,\"approve\":false}" "$H/biz/staffInvite/staff/audit")
REJ=$(echo "$RES3" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code'))" 2>/dev/null)
check "拒绝 200" "200" "$REJ"
EXISTS=$($MYSQL -N -e "SELECT COUNT(*) FROM biz_merchant_staff WHERE id=$SID2" 2>/dev/null)
check "拒绝后物理删除" "0" "$EXISTS"

# 7) STAFF 无权审核
RES4=$(curl -s -X POST -H "Authorization: Bearer $TK_STAFF" -H "Content-Type: application/json" \
  -d "{\"id\":$SID,\"approve\":true}" "$H/biz/staffInvite/staff/audit")
echo "$RES4" | grep -qE "权限|没有|denied|401|403" && check "STAFF 无权" "yes" "yes" || check "STAFF 无权" "yes" "no: $RES4"

# 8) DB 清理
$MYSQL <<SQL 2>/dev/null
DELETE FROM biz_merchant_staff WHERE id IN ($SID,$SID2);
DELETE FROM sys_user_role WHERE user_id IN (SELECT user_id FROM sys_user WHERE user_name IN ('$USER','$USER2'));
DELETE FROM sys_user WHERE user_name IN ('$USER','$USER2');
SQL

echo "============================="
echo "V6-3 smoke: $PASS pass / $FAIL fail"
[ $FAIL -eq 0 ] || exit 1
