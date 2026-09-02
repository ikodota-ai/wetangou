#!/usr/bin/env bash
# 平台新建商户时自动开通的老板账号，必须真的能进 PC 后台管员工
#
# 为什么需要这个脚本：
#   新建商户会自动建一个 OWNER 账号并返回初始密码，看起来「开通完成」了。
#   但老板拿这个账号进后台第一件事就是招人，而 PC 端权限只认 sys_user_role ——
#   建号时如果没绑对角色，老板登录是成功的（有 token）、菜单是空的、
#   /biz/staffInvite/** 全 403，平台侧完全看不出异常，只有老板本人卡住。
#
#   原实现把角色写死成 role_id=5L。而 sql/biz_tenant_menu.sql 建「商户管理员」
#   用的是「WHERE NOT EXISTS (role_key='merchant')」——在一个先有其它角色的库里
#   merchant 完全可能落到 6/7，那时写死的 5L 会把老板绑到另一个角色上：
#   轻则菜单错乱，重则误绑到高权角色。本地库 role_id 恰好=5，所以一直没暴露。
#
#   本脚本走真实的「平台建商户 → 老板登录 → 老板发邀请码」端到端链路，
#   并直接查 sys_user_role 断言绑的是 role_key='merchant' 那个角色（不看 id）。
#
# 前置：后端跑在 $H，admin/admin123 可登
# 用法：bash .github/scripts/smoke-merchant-owner-role.sh [host]
# 退出码：0 全通 / 1 有失败

H="${1:-http://localhost:8080}"
MYSQL="/usr/local/mysql/bin/mysql -uroot -p133301 --default-character-set=utf8mb4 -N -B ry-vue"
TAG="ZZOWNER$$"

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

MID=""
cleanup() {
  # 建出来的商户 + 老板账号 + 员工关联 + 邀请码全部清掉（测试数据不留库）
  if [ -n "$MID" ]; then
    $MYSQL -e "delete from biz_merchant_staff_invite where merchant_id=$MID;
               delete from biz_merchant_staff where merchant_id=$MID;
               delete from sys_user_role where user_id in (select user_id from sys_user where merchant_id=$MID and user_name like 'ZZOWNER%');
               delete from biz_merchant_user where user_id in (select user_id from sys_user where merchant_id=$MID and user_name like 'ZZOWNER%');
               delete from sys_user where merchant_id=$MID and nick_name like 'ZZOWNER%';
               delete from biz_merchant where merchant_id=$MID;" 2>/dev/null | grep -v Warning || true
  fi
}
trap cleanup EXIT

echo "=== 新建商户的老板账号能否真进后台 ($H) ==="

ADMIN_TK=$(curl -s -X POST "$H/login" -H 'Content-Type: application/json' \
           -d '{"username":"admin","password":"admin123"}' | jget token)
ck "平台管理员登录" "$([ -n "$ADMIN_TK" ] && echo yes || echo no)" yes
[ -n "$ADMIN_TK" ] || exit 1

echo "[1] 平台新建商户，响应里带回老板账号与初始密码"
R=$(curl -s -X POST "$H/biz/merchant" -H 'Content-Type: application/json' \
      -H "Authorization: Bearer $ADMIN_TK" \
      -d "{\"merchantName\":\"$TAG\",\"contact\":\"ZZ测试\",\"phone\":\"13900000000\"}")
ck "建商户成功 code" "$(echo "$R" | jget code)" 200
MID=$(echo "$R" | jget merchantId)
OWNER_USER=$(echo "$R" | jget ownerUserName)
OWNER_PWD=$(echo "$R" | jget ownerInitPassword)
ck "  → 返回 merchantId" "$([ -n "$MID" ] && echo yes || echo no)" yes
ck "  → 返回老板账号名" "$([ -n "$OWNER_USER" ] && echo yes || echo no)" yes
ck "  → 返回初始密码" "$([ -n "$OWNER_PWD" ] && echo yes || echo no)" yes
[ -n "$MID" ] || exit 1
ck "  → 初始密码没落库（库里存的是 hash）" "$(q "select count(*) from sys_user where password='$OWNER_PWD';")" 0

echo "[2] 老板账号必须绑到 role_key='merchant' 那个角色（不看 role_id）"
OWNER_UID=$(q "select user_id from sys_user where user_name='$OWNER_USER' and del_flag='0' limit 1;")
ck "取到老板 user_id" "$([ -n "$OWNER_UID" ] && echo yes || echo no)" yes
ck "老板绑定的角色数" "$(q "select count(*) from sys_user_role where user_id=$OWNER_UID;")" 1
ck "  → 绑的正是 role_key=merchant" "$(q "select count(*) from sys_user_role ur join sys_role r on r.role_id=ur.role_id where ur.user_id=$OWNER_UID and r.role_key='merchant';")" 1
ck "  → user_type=02（商户侧，00 会被判成平台身份而越权）" "$(q "select user_type from sys_user where user_id=$OWNER_UID;")" 02
ck "  → 租户归属已落 biz_merchant_user" "$(q "select count(*) from biz_merchant_user where user_id=$OWNER_UID and merchant_id=$MID;")" 1
ck "  → biz_merchant_staff 有在职 OWNER（否则登不进商家版）" "$(q "select count(*) from biz_merchant_staff where merchant_id=$MID and user_id=$OWNER_UID and role='OWNER' and status='0';")" 1
ck "  → store_id=0 表示全商户门店（后续加门店不必补关联）" "$(q "select store_id from biz_merchant_staff where merchant_id=$MID and user_id=$OWNER_UID limit 1;")" 0

echo "[3] 老板用初始密码登 PC 后台，并真的能招人（这才是绑角色的目的）"
OWNER_TK=$(curl -s -X POST "$H/login" -H 'Content-Type: application/json' \
           -d "{\"username\":\"$OWNER_USER\",\"password\":\"$OWNER_PWD\"}" | jget token)
ck "老板登 PC 后台" "$([ -n "$OWNER_TK" ] && echo yes || echo no)" yes
if [ -n "$OWNER_TK" ]; then
  INFO=$(curl -s "$H/getInfo" -H "Authorization: Bearer $OWNER_TK")
  ck "  → getInfo 认出是商户身份(2)" "$(echo "$INFO" | jget userType)" 2
  ck "  → getInfo 带出 merchantId" "$(echo "$INFO" | jget merchantId)" "$MID"
  LIST=$(curl -s "$H/biz/staffInvite/staff/list" -H "Authorization: Bearer $OWNER_TK")
  ck "  → 看得到员工名单（没角色时这里 403）" "$(echo "$LIST" | jget code)" 200
  ROUTERS=$(curl -s "$H/getRouters" -H "Authorization: Bearer $OWNER_TK")
  ck "  → 菜单树非空（没角色时是空数组，后台一片白）" \
     "$(echo "$ROUTERS" | python3 -c 'import sys,json;print(1 if (json.load(sys.stdin).get("data") or []) else 0)' 2>/dev/null)" 1
fi

echo "[4] 老板发店员邀请码（新建商户后的第一个动作）"
if [ -n "$OWNER_TK" ]; then
  STORE=$(q "select store_id from biz_store where merchant_id=$MID limit 1;")
  if [ -z "$STORE" ]; then
    # 新商户还没门店：直接建一个，否则邀请码没有门店可挂
    $MYSQL -e "insert into biz_store (merchant_id, store_name, status, create_by, create_time)
               values ($MID, '$TAG-店', '0', 'smoke', now());" 2>/dev/null | grep -v Warning
    STORE=$(q "select store_id from biz_store where merchant_id=$MID limit 1;")
  fi
  INV=$(curl -s -X POST "$H/biz/staffInvite" -H 'Content-Type: application/json' \
         -H "Authorization: Bearer $OWNER_TK" \
         -d "{\"merchantId\":$MID,\"storeId\":$STORE,\"role\":\"STAFF\"}")
  ck "老板发店员邀请码成功" "$(echo "$INV" | jget code)" 200
  ck "  → 邀请码真落库" "$(q "select count(*) from biz_merchant_staff_invite where merchant_id=$MID;")" 1
  $MYSQL -e "delete from biz_store where merchant_id=$MID;" 2>/dev/null | grep -v Warning
fi

echo "[5] 清理：商户/老板账号/邀请码全部删除"
cleanup
ck "商户已删" "$(q "select count(*) from biz_merchant where merchant_id=$MID;")" 0
ck "老板账号已删" "$(q "select count(*) from sys_user where user_name='$OWNER_USER';")" 0
MID=""

echo ""
echo "=== PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ] || exit 1
