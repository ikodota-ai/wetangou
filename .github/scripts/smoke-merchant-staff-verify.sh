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
#  5. 平台刚建完商户时该商户还没有门店，老板第一次进商家版 /home 直接 500
#     「未绑定门店」→ 整页白屏，看不到任何提示。只读端点改为返回空数据 +
#     noStore/needCreateStore 引导，写操作仍必须有门店（且文案按角色区分）。
#  6. 预约确认/拒绝比的是 token 里当前激活门店，多店老板不切店就审不了别店的报名
#     → 改用授权门店集合 hasStore()。
#  7. 招店员这条链路店长根本走不通：sys_role「商户管理员」(role_id=5，新建商户自动开通的
#     老板账号就用它) 绑了 125 条菜单却没有一条 biz:staffInvite:*，老板生成邀请码 /
#     看员工名单 / 审入职 / 重置密码全部 403，只能让平台管理员代劳每一家店的招人。
#     另外 add 从来没校验门店归属：选了别家门店同样返回「已生成邀请码」，落库却是
#     「自己商户 + 别家门店」，acceptInvite 校验 mid/sid 必须与库中记录一致，这个
#     组合永远过不去 —— 店长拿到一张扫了只报「邀请码不存在」的死码。
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
#   I) 老板不切店直接审别店预约报名 → 200（按授权集合判，不是只比激活门店）
#   J) 0 门店商户老板进 /home → 200 + noStore/needCreateStore 引导，只读列表返空数组，
#      写操作仍被拒；无门店店员拿到的是「联系店长」而不是「去建门店」
#   K) 招店员闭环：老板(自动开通账号) 能自己发码 / 看员工名单 / 看待审列表；
#      发码时带别家 merchantId 或别家门店都被拒；店员扫码入职落 status=3 待审，
#      老板审核通过后店员静默 wxLogin 免密进商家版并能核销
#   L) 商家端建商品：老板能建(落草稿)+上架+在商家端列表可见，租户字段被强制覆盖为
#      自己商户；店员(STAFF)、代理商、平台账号都不能建
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
NOSTORE_MID=""
SIGNUP_I=""
K_STAFF_UID=""
ORDER_K=""
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
  if [ -n "$NOSTORE_MID" ]; then
    sql "delete from biz_merchant_staff where merchant_id=$NOSTORE_MID;"
    sql "delete from sys_user_role where user_id in (select user_id from sys_user where merchant_id=$NOSTORE_MID);"
    sql "delete from biz_merchant_user where merchant_id=$NOSTORE_MID;"
    sql "delete from sys_user where merchant_id=$NOSTORE_MID;"
    sql "delete from biz_merchant where merchant_id=$NOSTORE_MID;"
  fi
  [ -n "$SIGNUP_I" ] && sql "update biz_booking_member set status='0', confirm_user=null, confirm_time=null, review_remark=null where id=$SIGNUP_I;"
  # K 组：扫码入职的店员 + 老板发的邀请码 + 被核销的订单
  [ -n "$ORDER_K" ] && sql "update biz_order set status='1', verify_time=null, verify_user=null where order_id=$ORDER_K;"
  if [ -n "$K_STAFF_UID" ]; then
    sql "delete from biz_merchant_staff where user_id=$K_STAFF_UID;"
    sql "delete from sys_user_role where user_id=$K_STAFF_UID;"
    sql "delete from sys_user where user_id=$K_STAFF_UID;"
  fi
  sql "delete from biz_merchant_staff_invite where remark like 'smokemsv%';"
  # L 组：商家端建出来的商品（含 biz_product_store 关联）
  sql "delete from biz_product_store where product_id in (select product_id from biz_product where product_name like 'smokemsv_prod%');"
  sql "delete from biz_product where product_name like 'smokemsv_prod%';"
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

# ---- I) 老板不切店直接审别店预约报名（按授权集合判，不是只比激活门店）----
# 当前激活门店已在 F 切成 STORE_B，故意找一个「不是 STORE_B」的门店的待审报名
SIGNUP_I=$(sqlv "select bm.id from biz_booking_member bm join biz_booking b on b.booking_id=bm.booking_id
                 where bm.status='0' and b.store_id<>$STORE_B and b.store_id in (select store_id from biz_store where merchant_id=$MID) limit 1;")
if [ -n "$SIGNUP_I" ]; then
  RESP=$(curl -s -X POST "$BASE_URL/api/merchant/staff/booking/confirm/$SIGNUP_I" -H 'Content-Type: application/json'     -H "Authorization: Bearer $OTK" -H "X-App-Id: $APPID" -d '{"remark":"smoke"}')
  echo "[I] 老板不切店审别店报名 signup=$SIGNUP_I（激活店=$STORE_B）"
  ckc "确认成功" "$RESP" "已确认"
  ck "报名转已确认" "$(sqlv "select status from biz_booking_member where id=$SIGNUP_I;")" "2"
  ck "审核人落 userId" "$(sqlv "select confirm_user from biz_booking_member where id=$SIGNUP_I;")" "mstaff-$OWNER_UID"
else
  echo "  SKIP: 找不到别店的待审报名，跳过 I"
fi

# ---- J) 0 门店商户：老板进商家版应拿到引导态而不是 500 ----
ATK=$(curl -s -X POST "$BASE_URL/login" -H 'Content-Type: application/json'   -d '{"username":"admin","password":"admin123"}' | jtop token)
if [ -n "$ATK" ]; then
  MRESP=$(curl -s -X POST "$BASE_URL/biz/merchant" -H "Authorization: Bearer $ATK"     -H 'Content-Type: application/json'     -d '{"merchantName":"smoke零门店商户","phone":"13800000000","status":"0"}')
  NOSTORE_MID=$(echo "$MRESP" | jtop merchantId)
  NS_USER=$(echo "$MRESP" | jtop ownerUserName)
  NS_PWD=$(echo "$MRESP" | jtop ownerInitPassword)
  echo "[J] 0 门店商户 merchantId=$NOSTORE_MID"
  # 建商户必须成功：uk_appid 是唯一索引且历史默认值 ''，空 appid 不落 NULL 时
  # 第二个不填 appid 的商户会报 Duplicate entry '' for key 'uk_appid'
  ck "建商户返回老板账号" "$([ -n "$NS_USER" ] && echo yes || echo no)" "yes"

  if [ -n "$NS_USER" ]; then
    NTK=$(curl -s -X POST "$BASE_URL/api/merchant/staff/login" -H 'Content-Type: application/json'       -H "X-App-Id: $APPID" -d "{\"username\":\"$NS_USER\",\"password\":\"$NS_PWD\"}" | jtop token)
    HOME=$(curl -s "$BASE_URL/api/merchant/staff/home" -H "Authorization: Bearer $NTK" -H "X-App-Id: $APPID")
    ck "首页不再 500"        "$(echo "$HOME" | jtop code)"           "200"
    ck "返回 noStore 标记"    "$(echo "$HOME" | jget noStore)"        "True"
    ck "老板可建店引导"       "$(echo "$HOME" | jget needCreateStore)" "True"
    # 只读列表应返空数组而不是报错
    for E in today/orders today/bills today/bookings booking/signup/list; do
      ck "只读 $E 返 200" "$(curl -s "$BASE_URL/api/merchant/staff/$E"         -H "Authorization: Bearer $NTK" -H "X-App-Id: $APPID" | jtop code)" "200"
    done
    # 写操作仍必须有门店
    RESP=$(curl -s -X POST "$BASE_URL/api/merchant/staff/booking/confirm/1" -H 'Content-Type: application/json'       -H "Authorization: Bearer $NTK" -H "X-App-Id: $APPID" -d '{}')
    ckc "写操作仍被拒且提示建门店" "$RESP" "请先创建门店"
  fi
else
  echo "  SKIP: admin 登录失败，跳过 J"
fi

# ---- K) 招店员闭环：老板发码 → 店员扫码入职 → 老板审核 → 店员静默登录核销 ----
# 用 J 组建出来的商户（自动开通的老板账号，绑的是 role_id=5 商户管理员）验权限，
# 用商户 1 的门店 100 走完整入职（acceptInvite 的 scene 查询受租户过滤，
# 必须用与 APPID 对应的商户）。
if [ -n "$NOSTORE_MID" ] && [ -n "$NS_USER" ]; then
  # 老板在 PC 后台的 token（走 /login，不是小程序端）
  OPTK=$(curl -s -X POST "$BASE_URL/login" -H 'Content-Type: application/json' \
    -d "{\"username\":\"$NS_USER\",\"password\":\"$NS_PWD\"}" | jtop token)
  echo "[K] 老板 PC token len=${#OPTK}"
  ck "老板能登 PC 后台" "$([ -n "$OPTK" ] && echo yes || echo no)" "yes"

  # K1 老板自己就能看员工名单 / 待审列表 / 邀请码列表（原来这三个全 403）
  ck "老板看员工名单"  "$(curl -s "$BASE_URL/biz/staffInvite/staff/list"  -H "Authorization: Bearer $OPTK" | jtop code)" "200"
  ck "老板看待审列表"  "$(curl -s "$BASE_URL/biz/staffInvite/staff/audit" -H "Authorization: Bearer $OPTK" | jtop code)" "200"
  ck "老板看邀请码列表" "$(curl -s "$BASE_URL/biz/staffInvite/list"       -H "Authorization: Bearer $OPTK" | jtop code)" "200"

  # K2 越权：带别家 merchantId 发码必须拒（不能静默改写成自己商户后落一张 scene 错乱的码）
  RESP=$(curl -s -X POST "$BASE_URL/biz/staffInvite" -H "Authorization: Bearer $OPTK" \
    -H 'Content-Type: application/json' \
    -d "{\"merchantId\":$MID,\"storeId\":$STORE_A,\"role\":\"STAFF\",\"remark\":\"smokemsv_bypass\"}")
  ckc "带别家 merchantId 发码被拒" "$RESP" "没有权限"

  # K3 越权：自己商户 + 别家门店必须拒（否则生成的是永远扫不动的死码）
  RESP=$(curl -s -X POST "$BASE_URL/biz/staffInvite" -H "Authorization: Bearer $OPTK" \
    -H 'Content-Type: application/json' \
    -d "{\"merchantId\":$NOSTORE_MID,\"storeId\":$STORE_A,\"role\":\"STAFF\",\"remark\":\"smokemsv_wrongstore\"}")
  ckc "自己商户配别家门店被拒" "$RESP" "不属于该商户"
  ck "废码没落库" "$(sqlv "select count(*) from biz_merchant_staff_invite where remark='smokemsv_wrongstore';")" "0"
fi

# K4 完整入职闭环：用 admin 给商户 1 门店 100 发码（APPID 对应商户 1）
if [ -n "$ATK" ]; then
  RESP=$(curl -s -X POST "$BASE_URL/biz/staffInvite" -H "Authorization: Bearer $ATK" \
    -H 'Content-Type: application/json' \
    -d "{\"merchantId\":$MID,\"storeId\":$STORE_A,\"role\":\"STAFF\",\"remark\":\"smokemsv_loop\"}")
  ckc "发码成功" "$RESP" "已生成邀请码"
  K_CODE=$(sqlv "select invite_code from biz_merchant_staff_invite where remark='smokemsv_loop' order by invite_id desc limit 1;")
  ck "邀请码 scene 与门店一致" \
     "$(sqlv "select scene from biz_merchant_staff_invite where invite_code='$K_CODE';")" \
     "invite:$MID:$STORE_A:AUTO"

  # 店员微信扫一扫入职（scene 由小程序码带入）
  RESP=$(curl -s -X POST "$BASE_URL/api/merchant/staff/acceptInvite" -H "X-App-Id: $APPID" \
    -H 'Content-Type: application/json' \
    -d "{\"code\":\"smokemsv_newstaff\",\"scene\":\"invite:$MID:$STORE_A:$K_CODE\"}")
  ckc "入职提交成功" "$RESP" "等待店长审核"
  ck "待审不发 token"  "$(echo "$RESP" | jtop token)"        ""
  ck "pendingAudit"    "$(echo "$RESP" | jtop pendingAudit)" "True"
  # sys_user 是逻辑删除（del_flag=2），历史同 openid 账号会让这里取到多行
  K_STAFF_UID=$(sqlv "select user_id from sys_user where openid='mock_smokemsv_newstaff' and del_flag='0' order by user_id desc limit 1;")
  ck "扫码入职建出账号" "$([ -n "$K_STAFF_UID" ] && echo yes || echo no)" "yes"
  K_LINK=$(sqlv "select id from biz_merchant_staff where user_id='$K_STAFF_UID' and merchant_id=$MID and store_id=$STORE_A order by id desc limit 1;")
  ck "员工关联已建" "$([ -n "$K_LINK" ] && echo yes || echo no)" "yes"
  ck "入职落待审 status=3" "$(sqlv "select status from biz_merchant_staff where id=$K_LINK;")" "3"

  # 审核前不能静默登录（否则审核形同虚设，扫到码就能核销）
  RESP=$(curl -s -X POST "$BASE_URL/api/merchant/staff/wxLogin" -H "X-App-Id: $APPID" \
    -H 'Content-Type: application/json' -d '{"code":"smokemsv_newstaff"}')
  ck "审核前静默登录拿不到 token" "$(echo "$RESP" | jtop token)" ""

  # 老板审核通过
  RESP=$(curl -s -X POST "$BASE_URL/biz/staffInvite/staff/audit" -H "Authorization: Bearer $ATK" \
    -H 'Content-Type: application/json' -d "{\"id\":$K_LINK,\"approve\":true}")
  ck "审核通过" "$(echo "$RESP" | jtop code)" "200"
  ck "审核后转在职" "$(sqlv "select status from biz_merchant_staff where id=$K_LINK;")" "0"

  # 审核后店员静默 wxLogin 免密进商家版
  RESP=$(curl -s -X POST "$BASE_URL/api/merchant/staff/wxLogin" -H "X-App-Id: $APPID" \
    -H 'Content-Type: application/json' -d '{"code":"smokemsv_newstaff"}')
  KTK=$(echo "$RESP" | jtop token)
  ck "审核后能静默登录"  "$([ -n "$KTK" ] && echo yes || echo no)" "yes"
  ck "角色是 STAFF"      "$(echo "$RESP" | jtop staffRole)"        "STAFF"
  ck "店员不是老板"      "$(echo "$RESP" | jtop isOwner)"          "False"

  # 新店员真的能核销
  ORDER_K=$(sqlv "select order_id from biz_order where store_id=$STORE_A and status='1' and verify_code is not null limit 1;")
  if [ -n "$ORDER_K" ] && [ -n "$KTK" ]; then
    KVC=$(sqlv "select verify_code from biz_order where order_id=$ORDER_K;")
    RESP=$(curl -s -X POST "$BASE_URL/api/order/verify" -H "X-App-Id: $APPID" \
      -H "Authorization: Bearer $KTK" -H 'Content-Type: application/json' \
      -d "{\"storeId\":$STORE_A,\"verifyCode\":\"$KVC\"}")
    ck "新店员核销成功" "$(echo "$RESP" | jtop code)" "200"
    ck "核销人落真实 userId" "$(sqlv "select verify_user from biz_order where order_id=$ORDER_K;")" "store:$K_STAFF_UID"
  else
    echo "  SKIP: 找不到可核销订单，跳过 K 核销"
  fi
else
  echo "  SKIP: admin 登录失败，跳过 K"
fi

# ---- L) 商家端建商品：老板能建能上架，店员/代理商/平台都不能 ----
# 用户的核心诉求就是「老板、店长能进商家版添加商品和核销」，核销由 A~C 覆盖，
# 建商品这条链路在这里锁住。
OWNER_MTK=$(mlogin smokemsv_owner | jtop token)
if [ -n "$OWNER_MTK" ]; then
  # 老板建商品：租户字段不可由前端指定，服务端强制覆盖为自己商户
  RESP=$(curl -s -X POST "$BASE_URL/api/product/add" -H "X-App-Id: $APPID" \
    -H "Authorization: Bearer $OWNER_MTK" -H 'Content-Type: application/json' \
    -d "{\"productName\":\"smokemsv_prod\",\"typeCode\":\"GROUPON\",\"storeIds\":\"$STORE_A\",\"merchantId\":99999,\"price\":9.9,\"originalPrice\":19.9,\"maxPerOrder\":1,\"stock\":100}")
  echo "[L] 老板建商品"
  ck "建商品成功" "$(echo "$RESP" | jtop code)" "200"
  # 必须限定 merchant_id：同名商品若存在历史残留或别家商户的行，这里会取错行，
  # 后面上架就报「无权操作该商品」500（首次编写时真踩到）
  L_PID=$(sqlv "select product_id from biz_product where product_name='smokemsv_prod' and merchant_id=$MID order by product_id desc limit 1;")
  ck "商品已落库" "$([ -n "$L_PID" ] && echo yes || echo no)" "yes"
  if [ -n "$L_PID" ]; then
    # 前端传了 merchantId=99999，必须被覆盖成老板自己的商户，否则商品跨租户
    ck "merchantId 被强制覆盖" "$(sqlv "select merchant_id from biz_product where product_id=$L_PID;")" "$MID"
    ck "主门店取 storeIds 首个" "$(sqlv "select store_id from biz_product where product_id=$L_PID;")" "$STORE_A"
    # 新建一律按草稿收（status=1 下架），避免没填全的商品直接对顾客可见
    ck "新建落草稿(下架)" "$(sqlv "select status from biz_product where product_id=$L_PID;")" "1"

    # 上架
    UPRESP=$(curl -s -X PUT "$BASE_URL/api/product/status" -H "X-App-Id: $APPID" \
      -H "Authorization: Bearer $OWNER_MTK" -H 'Content-Type: application/json' \
      -d "{\"productId\":$L_PID,\"status\":\"0\"}")
    ck "上架返回 200" "$(echo "$UPRESP" | jtop code)" "200"
    ck "上架后 status=0" "$(sqlv "select status from biz_product where product_id=$L_PID;")" "0"

    # 商家端列表要能看到自己刚建的（顾客端 /api/product/list 写死 status=0，
    # 草稿看不见，所以商家端必须用 /api/product/merchant/list）
    ck "商家端列表含新商品" "$(curl -s "$BASE_URL/api/product/merchant/list?pageSize=200" \
      -H "X-App-Id: $APPID" -H "Authorization: Bearer $OWNER_MTK" \
      | python3 -c "
import sys,json
d=json.load(sys.stdin)
rows=d.get('rows') or (d.get('data') or {}).get('rows') or []
print('yes' if any(str(r.get('productId'))=='$L_PID' for r in rows) else 'no')
")" "yes"
  fi

  # 店员不能建商品（核销员改价上架等于绕过老板）
  RESP=$(curl -s -X POST "$BASE_URL/api/product/add" -H "X-App-Id: $APPID" \
    -H "Authorization: Bearer $STK" -H 'Content-Type: application/json' \
    -d "{\"productName\":\"smokemsv_prod_staff\",\"typeCode\":\"GROUPON\",\"storeIds\":\"$STORE_A\",\"price\":1,\"maxPerOrder\":1}")
  ckc "店员建商品被拒" "$RESP" "无权限访问该接口"
  ck "店员的商品没落库" "$(sqlv "select count(*) from biz_product where product_name='smokemsv_prod_staff';")" "0"
else
  echo "  SKIP: 老板小程序端登录失败，跳过 L"
fi

echo
if [ $FAIL -eq 0 ]; then echo "smoke-merchant-staff-verify: ALL PASSED"; else echo "smoke-merchant-staff-verify: FAILED"; exit 1; fi
