#!/usr/bin/env bash
# 员工扫码入职 + 店长审核 全链路 smoke
# 覆盖：邀请码生成 → 扫码建号(openid 落库/user_type=02/status=3 待审核)
#      → 待审核不得登录(601) → 待审核清单 → 审核通过 → 可登录(staff)
#      → 无 PLATFORM 越权(平台端点 403) → 离职后不得登录
# 前置：后端 8080 在跑；wxconfig mock 模式开启：邀请码 -> 扫码建号(待审核) -> 不得登录 -> 审核通过 -> 可登录 -> 无平台越权
MYSQL="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 --default-character-set=utf8mb4 ry-vue"
BASE=http://localhost:8080
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
ng(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

TOKEN=$(curl -s -X POST $BASE/login -H 'Content-Type: application/json' -d '{"username":"admin","password":"admin123"}' | python3 -c "import sys,json;print(json.load(sys.stdin).get('token',''))")
if [ -n "$TOKEN" ]; then ok "admin 登录"; else ng "admin 登录"; exit 1; fi

WXCODE="joinE2E$$"
# 清理可能的残留
$MYSQL -e "delete from biz_merchant_staff where user_id in (select user_id from sys_user where openid='mock_$WXCODE'); delete from sys_user where openid='mock_$WXCODE';" 2>/dev/null

echo "[1] 生成邀请码"
RESP=$(curl -s -X POST $BASE/biz/staffInvite -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"merchantId":1,"storeId":100,"role":"STAFF","remark":"e2e"}')
CODE=$(echo "$RESP" | python3 -c "import sys,json,re;m=re.search(r'：(\w+)',json.load(sys.stdin).get('msg',''));print(m.group(1) if m else '')")
if [ -n "$CODE" ]; then ok "邀请码=$CODE"; else ng "生成邀请码: $RESP"; exit 1; fi

echo "[2] 扫码入职（应返回 pendingAudit=true 且无 token）"
AC=$(curl -s -X POST $BASE/api/merchant/staff/acceptInvite -H 'Content-Type: application/json' -d "{\"code\":\"$WXCODE\",\"scene\":\"invite:1:100:$CODE\",\"nickName\":\"E2E新人\"}")
echo "    $AC" | head -c 300; echo
PEND=$(echo "$AC" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('pendingAudit'))")
TK=$(echo "$AC" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('token') or '')")
if [ "$PEND" = "True" ]; then ok "pendingAudit=true"; else ng "pendingAudit 应为 true，实际 $PEND"; fi
if [ -z "$TK" ]; then ok "待审核不发 token"; else ng "待审核仍发了 token"; fi

echo "[3] DB 校验：账号已建、openid 已绑、user_type=02、staff status=3"
ROW=$($MYSQL -N -e "select u.user_id,u.user_type,u.openid_bound,s.status from sys_user u join biz_merchant_staff s on s.user_id=u.user_id where u.openid='mock_$WXCODE';" 2>/dev/null)
echo "    $ROW"
UID_=$(echo "$ROW" | awk '{print $1}'); UT=$(echo "$ROW" | awk '{print $2}'); OB=$(echo "$ROW" | awk '{print $3}'); ST=$(echo "$ROW" | awk '{print $4}')
if [ -n "$UID_" ]; then ok "账号已建 user_id=$UID_"; else ng "账号未建"; exit 1; fi
if [ "$UT" = "02" ]; then ok "user_type=02"; else ng "user_type=$UT 应为 02"; fi
if [ "$OB" = "1" ]; then ok "openid 已绑定"; else ng "openid_bound=$OB"; fi
if [ "$ST" = "3" ]; then ok "员工 status=3 待审核"; else ng "员工 status=$ST 应为 3"; fi

echo "[4] 待审核期间 wxLogin 应被拒（code 601）"
WL=$(curl -s -X POST $BASE/api/merchant/staff/wxLogin -H 'Content-Type: application/json' -d "{\"code\":\"$WXCODE\",\"merchantId\":1}")
echo "    $WL" | head -c 200; echo
C=$(echo "$WL" | python3 -c "import sys,json;print(json.load(sys.stdin).get('code'))")
if [ "$C" = "601" ]; then ok "待审核登录被拒 601"; else ng "期望 601 实际 $C"; fi

echo "[5] 待审核清单应含该员工"
AL=$(curl -s "$BASE/biz/staffInvite/staff/audit" -H "Authorization: Bearer $TOKEN")
if echo "$AL" | grep -q "\"userId\":$UID_"; then ok "待审核清单含 user $UID_"; else ng "待审核清单缺 user $UID_"; fi
SID=$($MYSQL -N -e "select id from biz_merchant_staff where user_id=$UID_ limit 1;" 2>/dev/null)

echo "[6] 审核通过"
AU=$(curl -s -X POST "$BASE/biz/staffInvite/staff/audit" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d "{\"id\":$SID,\"approve\":true}")
echo "    $AU" | head -c 150; echo
NST=$($MYSQL -N -e "select status from biz_merchant_staff where id=$SID;" 2>/dev/null)
if [ "$NST" = "0" ]; then ok "审核后 status=0 在职"; else ng "审核后 status=$NST"; fi

echo "[7] 审核后 wxLogin 应成功且身份为 staff"
WL2=$(curl -s -X POST $BASE/api/merchant/staff/wxLogin -H 'Content-Type: application/json' -d "{\"code\":\"$WXCODE\",\"merchantId\":1}")
UTYPE=$(echo "$WL2" | python3 -c "import sys,json;print(json.load(sys.stdin).get('userType'))")
ROLES=$(echo "$WL2" | python3 -c "import sys,json;print(','.join(json.load(sys.stdin).get('roles') or []))")
TK2=$(echo "$WL2" | python3 -c "import sys,json;print(json.load(sys.stdin).get('token') or '')")
echo "    userType=$UTYPE roles=$ROLES"
if [ -n "$TK2" ]; then ok "审核后可登录"; else ng "审核后仍无法登录: $WL2"; fi
if [ "$UTYPE" = "staff" ]; then ok "userType=staff"; else ng "userType=$UTYPE 应为 staff"; fi
if echo "$ROLES" | grep -q PLATFORM; then ng "越权：仍带 PLATFORM 角色"; else ok "无 PLATFORM 越权"; fi

echo "[8] 平台端点应被拒"
for ep in "/api/platform/merchant/list?pageNum=1&pageSize=2" "/api/platform/order/list?pageNum=1&pageSize=2" "/api/platform/staff/list?pageNum=1&pageSize=2"; do
  R=$(curl -s "$BASE$ep" -H "Authorization: Bearer $TK2")
  CC=$(echo "$R" | python3 -c "import sys,json;print(json.load(sys.stdin).get('code'))" 2>/dev/null)
  if [ "$CC" = "200" ]; then ng "越权可读 $ep"; else ok "已拦截 $ep (code=$CC)"; fi
done

echo "[9] 离职后不得登录"
$MYSQL -e "update biz_merchant_staff set status='1' where id=$SID;" 2>/dev/null
WL3=$(curl -s -X POST $BASE/api/merchant/staff/wxLogin -H 'Content-Type: application/json' -d "{\"code\":\"$WXCODE\",\"merchantId\":1}")
C3=$(echo "$WL3" | python3 -c "import sys,json;print(json.load(sys.stdin).get('code'))")
if [ "$C3" = "600" ] || [ "$C3" = "601" ]; then ok "离职登录被拒 code=$C3"; else ng "离职仍可登录 code=$C3"; fi

echo "[cleanup]"
$MYSQL -e "delete from biz_merchant_staff where id=$SID; delete from sys_user where user_id=$UID_; delete from biz_merchant_staff_invite where invite_code='$CODE';" 2>/dev/null
echo "smoke-staff-audit result: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
