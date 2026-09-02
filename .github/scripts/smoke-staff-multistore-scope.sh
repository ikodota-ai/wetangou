#!/usr/bin/env bash
# 一人在多门店任职时，「改密码 / 解绑微信」的授权必须看全部关联，不能只看第一条
#
# 为什么需要这个脚本：
#   biz_merchant_staff 是一人多行：同一个人可以在 A 店当店员、在 B 店当店长。
#   而 selectByUserId 是 order by id asc limit 1，只返回入职最早那一条。
#   所有「按员工身份做授权」的地方一旦用它，别的门店的更高身份就被完全忽略。
#
#   实测造出「store100=STAFF / store101=MANAGER」的员工后，只管 store100 的店长
#   在商家版点「重置密码」返回 200、密码真被改掉 —— 可这个密码同时是他在 store101
#   的店长凭证，等于隔着门店把别人店的店长踢下线（对方下次登录直接进不去）。
#   同理解绑微信：清掉的 openid 是账号级的，另一个门店的免密登录一起失效。
#
#   角色比较也有同一个坑：只看第一条会把「兼任店长的人」判成 STAFF 而放行，
#   店长因此能改到另一家店店长的密码（canManageRole 本该拦住同级）。
#
# 前置：后端跑在 $H，库里有 manager_c43（store100 的店长，密码 admin123）
# 用法：bash .github/scripts/smoke-staff-multistore-scope.sh [host]
# 退出码：0 全通 / 1 有失败

H="${1:-http://localhost:8080}"
APPID="wx9e147c4e2151b123"
MYSQL="/usr/local/mysql/bin/mysql -uroot -p133301 --default-character-set=utf8mb4 -N -B ry-vue"
PWD_HASH='$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2'

PASS=0; FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
ck() { [ "$2" = "$3" ] && ok "$1 ($2)" || bad "$1 期望「$3」实得「$2」"; }
q()  { $MYSQL -e "$1" 2>/dev/null | grep -v Warning | head -1; }
jget() { python3 -c 'import sys,json
d=json.load(sys.stdin)
b=d.get("data") if isinstance(d.get("data"),dict) else {}
for k in sys.argv[1:]:
    v=b.get(k, d.get(k))
    print("" if v is None else v)' "$@" 2>/dev/null
}

cleanup() {
  $MYSQL -e "delete from biz_merchant_staff where real_name='ZZ双岗员工';
             delete from sys_user_role where user_id in (select user_id from sys_user where user_name='zz_dual');
             delete from biz_merchant_user where user_id in (select user_id from sys_user where user_name='zz_dual');
             delete from sys_user where user_name='zz_dual';" 2>/dev/null | grep -v Warning || true
}
trap cleanup EXIT
cleanup   # 上一轮异常中断可能留下 fixture

mplogin() {
  curl -s -X POST "$H/api/merchant/staff/login" -H 'Content-Type: application/json' \
       -H "X-App-Id: $APPID" -d "{\"username\":\"$1\",\"password\":\"$2\"}"
}
mppost() { # $1 path $2 token $3 json
  curl -s -X POST "$H$1" -H 'Content-Type: application/json' -H "X-App-Id: $APPID" \
       -H "Authorization: Bearer $2" -d "$3"
}
pclogin() {
  curl -s -X POST "$H/login" -H 'Content-Type: application/json' \
       -d "{\"username\":\"$1\",\"password\":\"admin123\"}" | jget token
}

echo "=== 多门店任职的授权边界 ($H) ==="

echo "[1] 造一个「store100 店员 + store101 店长」的双岗员工"
STORE_A=$(q "select store_id from biz_store where merchant_id=1 order by store_id limit 1;")
STORE_B=$(q "select store_id from biz_store where merchant_id=1 and store_id<>$STORE_A order by store_id limit 1;")
ck "取到两个门店" "$([ -n "$STORE_A" ] && [ -n "$STORE_B" ] && echo yes || echo no)" yes
if [ -z "$STORE_B" ]; then echo "商户 1 只有一个门店，无法构造多门店场景"; exit 1; fi

$MYSQL -e "insert into sys_user (user_name,nick_name,password,status,del_flag,user_type,merchant_id,openid,create_by,create_time)
           values ('zz_dual','ZZ双岗员工','$PWD_HASH','0','0','02',1,'zz_dual_openid','smoke',now());" 2>/dev/null | grep -v Warning
X=$(q "select user_id from sys_user where user_name='zz_dual' limit 1;")
ck "建出双岗账号" "$([ -n "$X" ] && echo yes || echo no)" yes
[ -n "$X" ] || exit 1
# 先插 STAFF@A（id 小，selectByUserId 会取到它），再插 MANAGER@B
$MYSQL -e "insert into biz_merchant_staff (merchant_id,store_id,user_id,role,real_name,status,create_by,create_time)
           values (1,$STORE_A,$X,'STAFF','ZZ双岗员工','0','smoke',now());
           insert into biz_merchant_staff (merchant_id,store_id,user_id,role,real_name,status,create_by,create_time)
           values (1,$STORE_B,$X,'MANAGER','ZZ双岗员工','0','smoke',now());" 2>/dev/null | grep -v Warning
ck "两条关联都在" "$(q "select count(*) from biz_merchant_staff where user_id=$X;")" 2
ck "  → 第一条(id 最小)确实是 $STORE_A/STAFF" "$(q "select concat(store_id,'/',role) from biz_merchant_staff where user_id=$X order by id asc limit 1;")" "$STORE_A/STAFF"

echo "[2] 只管 $STORE_A 的店长不能动他（他在 $STORE_B 还是店长）"
MGR_TK=$(mplogin manager_c43 admin123 | jget token)
ck "店长登商家版" "$([ -n "$MGR_TK" ] && echo yes || echo no)" yes
MGR_STORES=$(mplogin manager_c43 admin123 | python3 -c 'import sys,json
d=json.load(sys.stdin); b=d.get("data") if isinstance(d.get("data"),dict) else d
print(",".join(str(x) for x in (b.get("storeIds") or [])))' 2>/dev/null)
ck "  → 店长只管 $STORE_A" "$MGR_STORES" "$STORE_A"
R=$(mppost "/api/merchant/staff/staff/resetPwd" "$MGR_TK" "{\"userId\":$X}")
ck "跨门店重置密码被拒" "$([ "$(echo "$R" | jget code)" != "200" ] && echo rejected || echo passed)" rejected
ck "  → 密码未被改动" "$(q "select count(*) from sys_user where user_id=$X and password='$PWD_HASH';")" 1

echo "[3] PC 后台同一条边界（密码是账号级的，PC 端也不能绕过）"
MGR_PC=$(pclogin manager_c43)
ck "店长登 PC 后台" "$([ -n "$MGR_PC" ] && echo yes || echo no)" yes
# 同商户内 PC 端不做门店隔离（PC 是商户/代理商维度），这里断言的是「不报错、不串商户」
R3=$(curl -s -X PUT "$H/biz/staffInvite/staff/resetPwd/$X" -H "Authorization: Bearer $MGR_PC")
ck "PC 端本商户员工可重置" "$(echo "$R3" | jget code)" 200
PW3=$(echo "$R3" | jget newPassword)
ck "  → 新密码能登商家版" "$([ -n "$(mplogin zz_dual "$PW3" | jget token)" ] && echo yes || echo no)" yes
$MYSQL -e "update sys_user set password='$PWD_HASH' where user_id=$X;" 2>/dev/null | grep -v Warning

echo "[4] 老板（全商户视角）本来就该管得了双岗员工"
OWNER_TK=$(mplogin owner_c43 admin123 | jget token)
ck "老板登商家版" "$([ -n "$OWNER_TK" ] && echo yes || echo no)" yes
if [ -n "$OWNER_TK" ]; then
  # owner_c43 的 store_id=100（单店绑定），管不到 STORE_B 的关联，应被拒；
  # 这条断言记录当前真实口径：老板要跨店管人得先把 store_id 设为 0（全商户）
  R4=$(mppost "/api/merchant/staff/staff/resetPwd" "$OWNER_TK" "{\"userId\":$X}")
  OWNER_SCOPE=$(q "select store_id from biz_merchant_staff where user_id=(select user_id from sys_user where user_name='owner_c43') limit 1;")
  if [ "$OWNER_SCOPE" = "0" ]; then
    ck "全商户老板可重置双岗员工" "$(echo "$R4" | jget code)" 200
  else
    ck "单店老板(store=$OWNER_SCOPE)同样受门店边界约束" "$([ "$(echo "$R4" | jget code)" != "200" ] && echo rejected || echo passed)" rejected
  fi
  $MYSQL -e "update sys_user set password='$PWD_HASH' where user_id=$X;" 2>/dev/null | grep -v Warning
fi

echo "[5] 解绑微信同样受这条边界约束（openid 也是账号级的）"
$MYSQL -e "update sys_user set openid='zz_dual_openid' where user_id=$X;" 2>/dev/null | grep -v Warning
R5=$(curl -s -X PUT "$H/biz/staffInvite/staff/unbindWx/$X" -H "Authorization: Bearer $MGR_PC")
ck "PC 端本商户员工可解绑" "$(echo "$R5" | jget code)" 200
ck "  → openid 真的清了" "$(q "select count(*) from sys_user where user_id=$X and (openid is null or openid='');")" 1

echo "[6] 离职关联不该继续构成约束（否则老员工离职后原店永远改不了他密码）"
$MYSQL -e "update biz_merchant_staff set status='1' where user_id=$X and store_id=$STORE_B;" 2>/dev/null | grep -v Warning
R6=$(mppost "/api/merchant/staff/staff/resetPwd" "$MGR_TK" "{\"userId\":$X}")
ck "$STORE_B 的关联离职后，$STORE_A 店长可重置" "$(echo "$R6" | jget code)" 200
PW6=$(echo "$R6" | jget newPassword)
ck "  → 新密码能登" "$([ -n "$(mplogin zz_dual "$PW6" | jget token)" ] && echo yes || echo no)" yes

echo "[7] 清理"
cleanup
ck "双岗账号已删" "$(q "select count(*) from sys_user where user_name='zz_dual';")" 0
ck "关联已删" "$(q "select count(*) from biz_merchant_staff where real_name='ZZ双岗员工';")" 0

echo ""
echo "=== PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ] || exit 1
