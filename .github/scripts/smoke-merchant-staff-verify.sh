#!/usr/bin/env bash
# 商家端员工核销 / 切店 smoke test
#
# 锁住的行为：老板(OWNER)、店长(MANAGER)、扫码入职的店员(STAFF) 登录小程序商家版后
# 能核销、能确认买单、多店能切店；同时不能碰授权门店集合以外的资源。
#
# 为什么要这个 smoke（都是真实踩过的坑）：
#  1. @StoreStaffRequired 的拦截器判定原本是 `"store".equals(userType)`，只认旧门店端
#     登录链路。商家端登录发的是 owner/manager/staff，于是 POST /api/order/verify、
#     /api/bill/confirm/{id} 对商家端三种角色全部 403「此操作仅限门店端员工」——
#     老板/店长/店员进了商家版一张券都核销不了，这是商家端最核心功能的阻塞。
#  2. 方法内的二次校验比的是 token 里的单个 storeId，多店员工（以及 store_id=0
#     展开成全部门店的老板）切到别的店就核销不了 → 改成比整个授权门店集合。
#  3. 核销人标识原来取 memberId，商家端链路没有 memberId，核销记录全是 "store:null"
#     → 改取 staffUserId。
#  4. 切店端点：旧的 /api/store/staff/switch-store 第一行就要求 userType=store，
#     商家端任何角色都必然被拒，核销页那段切店代码是死代码 → 新增
#     /api/merchant/staff/switch-store。
#
# 验证：
#   A) 店员密码登录 → userType=staff / 带 staffUserId
#   B) 店员核销自己门店的券 → 200，且 verify_user 落 staff 的 userId（不是 null）
#   C) 店员核销授权集合外门店 → 拒
#   D) 会员 token 调核销 → 403（员工域校验没被放宽掉）
#   E) 多店老板(store_id=0)登录 → storeIds 展开为该商户全部门店
#   F) 老板切店到授权集合内门店 → 200，/me 的 storeId 真的变了
#   G) 老板切到别家商户门店 → 拒
#   H) 老板跨店确认买单（授权集合内）→ 200，confirmUser 带 userId
#
# 前置：后端在 8080 运行（druid profile），本地 mysql 可连
# 用法：bash .github/scripts/smoke-merchant-staff-verify.sh
set -e

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
APPID="${APPID:-wx9e147c4e2151b123}"
MYSQL="${MYSQL_BIN:-/usr/local/mysql/bin/mysql}"
MID=1
STORE_A=100
STORE_B=200
FAIL=0

ck() { # ck <描述> <实际> <期望>
  if [ "$2" = "$3" ]; then echo "  OK: $1 ($2)"; else echo "  FAIL: $1 期望 $3 实际 $2"; FAIL=1; fi
}
ckc() { # ckc <描述> <实际> <应包含>
  case "$2" in *"$3"*) echo "  OK: $1";; *) echo "  FAIL: $1 期望含「$3」实际「$2」"; FAIL=1;; esac
}

jget() { python3 -c "
import sys,json
d=json.load(sys.stdin); b=d.get('data') or d
v=b
for k in '$1'.split('.'):
    v=(v or {}).get(k)
print('' if v is None else v)
"; }

# 顶层字段（code/msg）专用：jget 会先钻进 data，取不到顶层 code
jtop() { python3 -c "
import sys,json
d=json.load(sys.stdin)
v=d.get('$1')
print('' if v is None else v)
"; }

sql()  { "$MYSQL" -h127.0.0.1 -uroot -p133301 ry-vue -e "$1" 2>/dev/null || true; }
sqlv() { "$MYSQL" -h127.0.0.1 -uroot -p133301 -N -B ry-vue -e "$1" 2>/dev/null || true; }

STAFF_UID=""
OWNER_UID=""
ORDER_A=""
BILL_A=""
cleanup() {
  [ -n "$ORDER_A" ] && sql "update biz_order set status='1', verify_time=null, verify_user=null where order_id=$ORDER_A;"
  [ -n "$BILL_A" ]  && sql "delete from biz_pay_bill where bill_id=$BILL_A;"
  if [ -n "$STAFF_UID" ]; then
    sql "delete from biz_merchant_staff where user_id=$STAFF_UID;"
    sql "delete from sys_user_role where user_id=$STAFF_UID;"
    sql "delete from sys_user where user_id=$STAFF_UID;"
  fi
  if [ -n "$OWNER_UID" ]; then
    sql "delete from biz_merchant_staff where user_id=$OWNER_UID;"
    sql "delete from sys_user_role where user_id=$OWNER_UID;"
    sql "delete from sys_user where user_id=$OWNER_UID;"
  fi
  sql "delete from biz_member where openid='mock_smokemsv_member';"
}
trap cleanup EXIT

# ---- 前置：造一个仅授权 STORE_A 的店员 + 一个 store_id=0 的老板 ----
PWD_HASH='$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2'   # admin123
sql "insert into sys_user(user_name,nick_name,password,status,del_flag,user_type,merchant_id,openid,openid_bound,create_time)
     values('smokemsv_staff','冒烟店员','$PWD_HASH','0','0','02',$MID,'mock_smokemsv_staff',1,now());"
STAFF_UID=$(sqlv "select user_id from sys_user where user_name='smokemsv_staff';")
sql "insert into biz_merchant_staff(merchant_id,store_id,user_id,role,status,create_time)
     values($MID,$STORE_A,$STAFF_UID,'STAFF','0',now());"

sql "insert into sys_user(user_name,nick_name,password,status,del_flag,user_type,merchant_id,create_time)
     values('smokemsv_owner','冒烟老板','$PWD_HASH','0','0','02',$MID,now());"
OWNER_UID=$(sqlv "select user_id from sys_user where user_name='smokemsv_owner';")
# store_id=0 = 全商户门店，登录时应被展开成真实门店列表
sql "insert into biz_merchant_staff(merchant_id,store_id,user_id,role,status,create_time)
     values($MID,0,$OWNER_UID,'OWNER','0',now());"

mlogin() { # mlogin <username>
  curl -s -X POST "$BASE_URL/api/merchant/staff/login" -H 'Content-Type: application/json' \
    -H "X-App-Id: $APPID" -d "{\"username\":\"$1\",\"password\":\"admin123\"}"
}

# ---- A) 店员登录 ----
RESP=$(mlogin smokemsv_staff)
STK=$(echo "$RESP" | jget token)
echo "[A] 店员商家端密码登录"
ck "userType"      "$(echo "$RESP" | jget userType)"    "staff"
ck "staffRole"     "$(echo "$RESP" | jget staffRole)"   "STAFF"
ck "staffUserId"   "$(echo "$RESP" | jget staffUserId)" "$STAFF_UID"
[ -n "$STK" ] || { echo "FAIL: 店员登录拿不到 token"; exit 1; }

# ---- B) 店员核销自己门店的券 ----
ORDER_A=$(sqlv "select order_id from biz_order where store_id=$STORE_A and status='1' and verify_code is not null limit 1;")
if [ -z "$ORDER_A" ]; then
  echo "  SKIP: 门店 $STORE_A 没有待使用且有核销码的订单，跳过 B/C"
else
  VCODE=$(sqlv "select verify_code from biz_order where order_id=$ORDER_A;")
  RESP=$(curl -s -X POST "$BASE_URL/api/order/verify" -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $STK" -H "X-App-Id: $APPID" \
    -d "{\"verifyCode\":\"$VCODE\",\"storeId\":$STORE_A}")
  echo "[B] 店员核销本店券 order=$ORDER_A"
  ck "核销返回 code" "$(echo "$RESP" | jtop code)" "200"
  ck "订单转已完成"  "$(sqlv "select status from biz_order where order_id=$ORDER_A;")" "2"
  # 关键：核销人必须是 staff 的 userId，不能是 store:null
  ck "核销人落 userId" "$(sqlv "select verify_user from biz_order where order_id=$ORDER_A;")" "store:$STAFF_UID"

  # ---- C) 店员越权核销别的门店 ----
  RESP=$(curl -s -X POST "$BASE_URL/api/order/verify" -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $STK" -H "X-App-Id: $APPID" \
    -d "{\"verifyCode\":\"$VCODE\",\"storeId\":$STORE_B}")
  echo "[C] 店员核销授权集合外门店"
  ckc "被拒" "$RESP" "无权操作其他门店"
fi

# ---- D) 会员 token 调核销 → 403 ----
MTK=$(curl -s -X POST "$BASE_URL/api/auth/login" -H 'Content-Type: application/json' \
  -H "X-App-Id: $APPID" -d "{\"code\":\"smokemsv_member\",\"appid\":\"$APPID\"}" | jget token)
if [ -n "$MTK" ]; then
  RESP=$(curl -s -X POST "$BASE_URL/api/order/verify" -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID" \
    -d "{\"verifyCode\":\"NOSUCHCODE\",\"storeId\":$STORE_A}")
  echo "[D] 会员 token 调核销"
  ck "403 拒绝" "$(echo "$RESP" | jtop code)" "403"
else
  echo "  SKIP: 会员 mock 登录不可用，跳过 D"
fi

# ---- E) 老板登录：store_id=0 应展开 ----
RESP=$(mlogin smokemsv_owner)
OTK=$(echo "$RESP" | jget token)
ALL_STORES=$(sqlv "select count(*) from biz_store where merchant_id=$MID;")
GOT_STORES=$(echo "$RESP" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('storeIds') or []))")
echo "[E] 老板登录（store_id=0 展开为全商户门店）"
ck "userType"          "$(echo "$RESP" | jget userType)" "owner"
ck "storeIds 门店数"    "$GOT_STORES" "$ALL_STORES"
[ -n "$OTK" ] || { echo "FAIL: 老板登录拿不到 token"; exit 1; }

# ---- F) 老板切店 ----
RESP=$(curl -s -X POST "$BASE_URL/api/merchant/staff/switch-store" -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $OTK" -H "X-App-Id: $APPID" -d "{\"storeId\":$STORE_B}")
echo "[F] 老板切店到 $STORE_B"
ck "切店返回 code"  "$(echo "$RESP" | jtop code)"    "200"
ck "响应 storeId"   "$(echo "$RESP" | jget storeId)" "$STORE_B"
ME=$(curl -s "$BASE_URL/api/merchant/staff/me" -H "Authorization: Bearer $OTK" -H "X-App-Id: $APPID")
ck "/me 里 storeId 真的变了" "$(echo "$ME" | jget storeId)" "$STORE_B"

# ---- G) 老板切到别家商户门店 → 拒 ----
OTHER_STORE=$(sqlv "select store_id from biz_store where merchant_id<>$MID limit 1;")
if [ -n "$OTHER_STORE" ]; then
  RESP=$(curl -s -X POST "$BASE_URL/api/merchant/staff/switch-store" -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $OTK" -H "X-App-Id: $APPID" -d "{\"storeId\":$OTHER_STORE}")
  echo "[G] 老板切到别家商户门店 $OTHER_STORE"
  ckc "被拒" "$RESP" "无权切换到该门店"
else
  echo "  SKIP: 没有别家商户门店，跳过 G"
fi

# ---- H) 老板跨店确认买单 ----
BILL_NO="SMKMSV$(date +%s)"
sql "insert into biz_pay_bill(merchant_id,bill_no,store_id,member_id,amount,pay_amount,status,create_time)
     values($MID,'$BILL_NO',$STORE_B,1001,66.00,66.00,'0',now());"
BILL_A=$(sqlv "select bill_id from biz_pay_bill where bill_no='$BILL_NO';")
if [ -n "$BILL_A" ]; then
  RESP=$(curl -s -X POST "$BASE_URL/api/bill/confirm/$BILL_A" \
    -H "Authorization: Bearer $OTK" -H "X-App-Id: $APPID")
  echo "[H] 老板确认 $STORE_B 的买单 bill=$BILL_A"
  ck "确认返回 code" "$(echo "$RESP" | jtop code)" "200"
  ck "买单转待支付"  "$(sqlv "select status from biz_pay_bill where bill_id=$BILL_A;")" "1"
  ck "确认人落 userId" "$(sqlv "select confirm_user from biz_pay_bill where bill_id=$BILL_A;")" "store:$OWNER_UID"
else
  echo "  SKIP: 买单造数失败，跳过 H"
fi

echo
if [ $FAIL -eq 0 ]; then echo "smoke-merchant-staff-verify: ALL PASSED"; else echo "smoke-merchant-staff-verify: FAILED"; exit 1; fi
