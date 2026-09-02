#!/usr/bin/env bash
# 店长/老板在 PC 后台重置员工密码，重置出来的密码能真的登进商家版
#
# 为什么需要这个脚本：
#   员工进商家版靠的是「扫码入职时自动建的账号 + 已绑 openid 免密进」。一旦员工
#   换手机换微信，openid 失效，那个自动生成的随机密码谁都不知道 —— 唯一的补救
#   途径就是店长在后台点一下「重置密码」把新密码念给他。
#
#   实测这条路径原本整段是断的，而且是两个独立的原因叠在一起：
#     1) sys_role「商户管理员」角色一条 biz:staffInvite:* 权限都没绑（v12 已修）
#     2) 老板/店长的账号在 sys_user_role 里压根没有任何角色（v14 修）
#   两者缺一个都是 403，而 403 只说「没有权限」，看不出是角色没绑还是权限没给。
#
#   本脚本把「店长能重置店员密码、且新密码真能登商家版、且越权都被挡住」钉死，
#   任何一方回退（删了 v14 回填、把 role_key 查询改回写死 role_id、
#   或把 resetPwd 的 assertDataScope 拿掉）都会在这里红。
#
# 前置：后端跑在 $H，库里有 owner_c43 / manager_c43 / staff_c43（密码 admin123）
# 用法：bash .github/scripts/smoke-staff-resetpwd.sh [host]
# 退出码：0 全通 / 1 有失败

H="${1:-http://localhost:8080}"
APPID="wx9e147c4e2151b123"
MYSQL="/usr/local/mysql/bin/mysql -uroot -p133301 --default-character-set=utf8mb4 -N -B ry-vue"
STAFF_PWD_HASH='$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2'

PASS=0; FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
ck() { # $1 desc $2 got $3 want
  [ "$2" = "$3" ] && ok "$1 ($2)" || bad "$1 期望「$3」实得「$2」"
}
ckin() { # $1 desc $2 body $3 needle
  case "$2" in *"$3"*) ok "$1";; *) bad "$1 未含「$3」: $(echo "$2" | head -c 160)";; esac
}
jget() { python3 -c 'import sys,json
d=json.load(sys.stdin)
b=d.get("data") if isinstance(d.get("data"),dict) else {}
for k in sys.argv[1:]:
    v=b.get(k, d.get(k))
    print("" if v is None else v)' "$@" 2>/dev/null
}

STAFF_UID=""
cleanup() {
  # 无论中途在哪一步失败，都把店员密码复原成 admin123，否则后续 smoke 全登不进
  if [ -n "$STAFF_UID" ]; then
    # openid 也要复原：staff_c43 的 oTest_distributor_001 是别的 smoke 依赖的既有数据
    $MYSQL -e "update sys_user set password='$STAFF_PWD_HASH', openid='oTest_distributor_001' where user_id=$STAFF_UID;" 2>/dev/null | grep -v Warning || true
  fi
  # 清掉本次自建的「别家商户员工」fixture（跨租户用例用）
  $MYSQL -e "delete from biz_merchant_staff where real_name='ZZ跨租户员工';
             delete from sys_user_role where user_id in (select user_id from sys_user where user_name='zz_other_staff');
             delete from biz_merchant_user where user_id in (select user_id from sys_user where user_name='zz_other_staff');
             delete from sys_user where user_name='zz_other_staff';" 2>/dev/null | grep -v Warning || true
}
trap cleanup EXIT
cleanup   # 上一轮异常中断可能留下 fixture，先清一次再建

# PC 后台登录（不带 X-App-Id）
pclogin() {
  curl -s -X POST "$H/login" -H 'Content-Type: application/json' \
       -d "{\"username\":\"$1\",\"password\":\"${2:-admin123}\"}" | jget token
}
# 商家版登录（带 X-App-Id）
mplogin() {
  curl -s -X POST "$H/api/merchant/staff/login" -H 'Content-Type: application/json' \
       -H "X-App-Id: $APPID" \
       -d "{\"username\":\"$1\",\"password\":\"$2\"}"
}
pcput() { # $1 path $2 token
  if [ -n "$2" ]; then
    curl -s -X PUT "$H$1" -H 'Content-Type: application/json' -H "Authorization: Bearer $2"
  else
    curl -s -X PUT "$H$1" -H 'Content-Type: application/json'
  fi
}

echo "=== 店长重置员工密码 ($H) ==="

echo "[1] 老板 / 店长 / 店员都能登 PC 后台（拿到 token 才谈得上权限）"
TK_OWNER=$(pclogin owner_c43)
TK_MGR=$(pclogin manager_c43)
TK_STAFF=$(pclogin staff_c43)
ck "老板登 PC 后台" "$([ -n "$TK_OWNER" ] && echo yes || echo no)" yes
ck "店长登 PC 后台" "$([ -n "$TK_MGR" ] && echo yes || echo no)" yes
ck "店员登 PC 后台" "$([ -n "$TK_STAFF" ] && echo yes || echo no)" yes

STAFF_UID=$($MYSQL -e "select user_id from sys_user where user_name='staff_c43' and del_flag='0' limit 1;" 2>/dev/null | grep -v Warning | head -1)
ck "取到店员 user_id" "$([ -n "$STAFF_UID" ] && echo yes || echo no)" yes
if [ -z "$STAFF_UID" ]; then echo "缺 staff_c43，无法继续"; exit 1; fi
OLD_HASH=$($MYSQL -e "select password from sys_user where user_id=$STAFF_UID;" 2>/dev/null | grep -v Warning | head -1)

echo "[2] 店长点「重置密码」，新密码当场返回一次"
R=$(pcput "/biz/staffInvite/staff/resetPwd/$STAFF_UID" "$TK_MGR")
ck "店长重置成功 code" "$(echo "$R" | jget code)" 200
NEWPW=$(echo "$R" | jget newPassword)
ck "  → 返回了新密码" "$([ -n "$NEWPW" ] && echo yes || echo no)" yes
ck "  → 返回了账号名" "$(echo "$R" | jget userName)" staff_c43
ck "  → 新密码 8 位" "${#NEWPW}" 8
ck "  → 避开易混字符 0O1lI" "$(printf '%s' "$NEWPW" | tr -cd '0O1lI' | wc -c | tr -d ' ')" 0
NEW_HASH=$($MYSQL -e "select password from sys_user where user_id=$STAFF_UID;" 2>/dev/null | grep -v Warning | head -1)
ck "  → 库里密码已变" "$([ "$NEW_HASH" != "$OLD_HASH" ] && echo changed || echo same)" changed
ck "  → 明文没落库" "$($MYSQL -e "select count(*) from sys_user where password='$NEWPW';" 2>/dev/null | grep -v Warning | head -1)" 0

echo "[3] 新密码真能登进商家版（店长要的是这个结果，不是 200）"
D2=$(mplogin staff_c43 "$NEWPW")
T2=$(echo "$D2" | jget token)
ck "新密码登商家版" "$([ -n "$T2" ] && echo yes || echo no)" yes
ck "  → 角色仍是 STAFF（重置密码不该改角色）" "$(echo "$D2" | jget staffRole)" STAFF
if [ -n "$T2" ]; then
  HOME=$(curl -s "$H/api/merchant/staff/home" -H "X-App-Id: $APPID" -H "Authorization: Bearer $T2")
  ck "  → 商家版首页打得开" "$(echo "$HOME" | jget code)" 200
fi

echo "[4] 旧密码必须立刻失效"
T3=$(mplogin staff_c43 admin123 | jget token)
ck "旧密码登不进" "$([ -z "$T3" ] && echo rejected || echo passed)" rejected

echo "[5] 老板同样有这个能力（店长离职时老板得能接手）"
R5=$(pcput "/biz/staffInvite/staff/resetPwd/$STAFF_UID" "$TK_OWNER")
ck "老板重置成功 code" "$(echo "$R5" | jget code)" 200
PW5=$(echo "$R5" | jget newPassword)
ck "  → 老板重置出的密码能登" "$([ -n "$(mplogin staff_c43 "$PW5" | jget token)" ] && echo yes || echo no)" yes

echo "[6] 越权必须被挡住"
R6=$(pcput "/biz/staffInvite/staff/resetPwd/$STAFF_UID" "$TK_STAFF")
ck "店员改不了任何人的密码（403）" "$(echo "$R6" | jget code)" 403
ck "无 token 被拒（401）" "$(pcput "/biz/staffInvite/staff/resetPwd/$STAFF_UID" "" | jget code)" 401
ADMIN_TK=$(pclogin admin)
ckin "重置非商家员工账号被拒（admin 自己）" "$(pcput '/biz/staffInvite/staff/resetPwd/1' "$ADMIN_TK")" "不是本商户的员工"
ckin "不存在的账号被拒" "$(pcput '/biz/staffInvite/staff/resetPwd/999999999' "$TK_MGR")" "不存在"
# 跨租户用例不能靠「库里刚好有别家商户员工」——本地库里只有商户 1 有员工，
# 一跳过这条就等于 assertDataScope 完全没被测到。自建 fixture 保证每次都跑。
OTHER_MID=$($MYSQL -e "select merchant_id from biz_merchant where merchant_id<>1 order by merchant_id limit 1;" 2>/dev/null | grep -v Warning | head -1)
if [ -n "$OTHER_MID" ]; then
  $MYSQL -e "insert into sys_user (user_name, nick_name, password, status, del_flag, user_type, merchant_id, create_by, create_time)
             values ('zz_other_staff', 'ZZ跨租户员工', '$STAFF_PWD_HASH', '0', '0', '02', $OTHER_MID, 'smoke', now());" 2>/dev/null | grep -v Warning
  OTHER=$($MYSQL -e "select user_id from sys_user where user_name='zz_other_staff' limit 1;" 2>/dev/null | grep -v Warning | head -1)
  $MYSQL -e "insert into biz_merchant_staff (merchant_id, store_id, user_id, role, real_name, status, create_by, create_time)
             values ($OTHER_MID, 0, $OTHER, 'STAFF', 'ZZ跨租户员工', '0', 'smoke', now());" 2>/dev/null | grep -v Warning
  R7=$(pcput "/biz/staffInvite/staff/resetPwd/$OTHER" "$TK_MGR")
  ck "别家商户员工不可重置（跨租户，merchant_id=$OTHER_MID）" "$([ "$(echo "$R7" | jget code)" != "200" ] && echo rejected || echo passed)" rejected
  ck "  → 别家员工密码未被改动" "$($MYSQL -e "select count(*) from sys_user where user_id=$OTHER and password='$STAFF_PWD_HASH';" 2>/dev/null | grep -v Warning | head -1)" 1
  # 话术必须让店长看懂是「没权限」而不是「我找错人了」：租户拦截器会把别家那行过滤掉，
  # link 为 null，原文案「该账号不是商家员工」会让店长反复重试同一个 userId。
  ckin "  → 拒绝话术说清是本商户/权限问题" "$R7" "本商户"

  # 同型越权：解绑微信端点原先只查 sys_user 就直接清 openid，实测店长能把别家
  # 商户员工的微信解绑掉（对方立刻失去免密登录）。userId 是自增数字，试错成本为零。
  $MYSQL -e "update sys_user set openid='zz_other_openid' where user_id=$OTHER;" 2>/dev/null | grep -v Warning
  R8=$(pcput "/biz/staffInvite/staff/unbindWx/$OTHER" "$TK_MGR")
  ck "别家商户员工微信不可解绑（跨租户）" "$([ "$(echo "$R8" | jget code)" != "200" ] && echo rejected || echo passed)" rejected
  ck "  → 别家员工 openid 仍在" "$($MYSQL -e "select count(*) from sys_user where user_id=$OTHER and openid='zz_other_openid';" 2>/dev/null | grep -v Warning | head -1)" 1
else
  bad "库里只有一个商户，跨租户用例无法构造（请检查 biz_merchant 种子）"
fi

echo "[6b] 本商户员工的微信解绑要能正常用（别把功能一起挡死）"
$MYSQL -e "update sys_user set openid='zz_smoke_openid' where user_id=$STAFF_UID;" 2>/dev/null | grep -v Warning
R9=$(pcput "/biz/staffInvite/staff/unbindWx/$STAFF_UID" "$TK_MGR")
ck "店长能解绑自家店员的微信" "$(echo "$R9" | jget code)" 200
ck "  → openid 真的清了" "$($MYSQL -e "select count(*) from sys_user where user_id=$STAFF_UID and (openid is null or openid='');" 2>/dev/null | grep -v Warning | head -1)" 1

echo "[7] 老板/店长在 sys_user_role 里必须有角色（v14 回填的就是这个）"
NOROLE=$($MYSQL -e "select count(*) from biz_merchant_staff ms join sys_user u on u.user_id=ms.user_id and u.del_flag='0' left join sys_user_role ur on ur.user_id=ms.user_id where ur.role_id is null and ms.role in ('OWNER','MANAGER') and ms.merchant_id>0;" 2>/dev/null | grep -v Warning | head -1)
ck "无 PC 角色的老板/店长数量" "$NOROLE" 0
STAFF_ROLE=$($MYSQL -e "select count(*) from sys_user_role where user_id=$STAFF_UID;" 2>/dev/null | grep -v Warning | head -1)
ck "店员仍然没有 PC 角色（设计如此，只在小程序核销）" "$STAFF_ROLE" 0

echo "[8] 复原店员密码"
cleanup
ck "复原后 admin123 可登" "$([ -n "$(mplogin staff_c43 admin123 | jget token)" ] && echo yes || echo no)" yes

echo ""
echo "=== PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ] || exit 1
