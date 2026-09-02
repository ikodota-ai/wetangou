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
#   M) 会员端识别店员身份：入职前 /api/auth/login 返 hasStaffAccount=false（会员端不显示
#      「切换到商家版」），扫码入职后转 true；待审时静默 wxLogin 返 601（前端弹「等待
#      店长审核」而不是「切换失败」），没绑过的返 600，审核通过后返 200 + token
#   N) 平台/代理商不得穿透商家端：RoleAuthInterceptor 原本「含 PLATFORM 就无条件放行」，
#      平台账号可穿透全部商家端 @RequireRole（/me 实测能拿 200 + 账号资料）。收口后
#      平台账号访问商家端一律 403，但平台/代理商各自的专属端点必须仍然可用。
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
  # 空实际值必须直接判失败：case 的 *"$3"* 对空串会命中任意模式，
  # 断言写法一旦取不到值（例如把跨行命令替换嵌进参数里）就会静默变成假绿。
  if [ -z "$2" ]; then echo "  FAIL: $1 实际值为空（断言取值失败）"; FAIL=1; return; fi
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
M_UID=""
O_MGR_UID=""
O_STF_UID=""
P_STF_UID=""
SB_ORDERS=""        # B2 段自建的核销订单（storeId 兜底用）
API_INV_IDS=""      # 商家端 /staff/invite 发出来的码：API 不打 smoke remark（生产代码不该埋测试标记），只能靠这里记 id
cleanup() {
  sql "delete from biz_order where order_no like 'SMKSB\\_%';"
  [ -n "$ORDER_A" ] && sql "update biz_order set status='1', verify_time=null, verify_user=null where order_id=$ORDER_A;"
  [ -n "$BILL_A" ]  && sql "delete from biz_pay_bill where bill_id=$BILL_A;"
  if [ -n "$STAFF_UID" ]; then
    sql "delete from biz_merchant_staff where user_id=$STAFF_UID;"
    sql "delete from sys_user_role where user_id=$STAFF_UID;"
    sql "delete from biz_merchant_user where user_id=$STAFF_UID;"
    sql "delete from sys_user where user_id=$STAFF_UID;"
  fi
  if [ -n "$OWNER_UID" ]; then
    sql "delete from biz_merchant_staff where user_id=$OWNER_UID;"
    sql "delete from sys_user_role where user_id=$OWNER_UID;"
    sql "delete from biz_merchant_user where user_id=$OWNER_UID;"
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
    sql "delete from biz_merchant_user where user_id=$K_STAFF_UID;"
    sql "delete from sys_user where user_id=$K_STAFF_UID;"
  fi
  sql "delete from biz_merchant_staff_invite where remark like 'smokemsv%';"
  # M 组：会员端身份识别用的扫码入职账号
  if [ -n "$M_UID" ]; then
    sql "delete from biz_merchant_staff where user_id=$M_UID;"
    sql "delete from sys_user_role where user_id=$M_UID;"
    sql "delete from biz_merchant_user where user_id=$M_UID;"
    sql "delete from sys_user where user_id=$M_UID;"
  fi
  sql "delete from biz_member where openid='mock_smokemsv_dual';"
  # O 组：扫码入职的店长 / 店员（含 PC 角色与租户归属两张附表）
  for U in "$O_MGR_UID" "$O_STF_UID"; do
    if [ -n "$U" ]; then
      sql "delete from biz_merchant_staff where user_id=$U;"
      sql "delete from sys_user_role where user_id=$U;"
      sql "delete from biz_merchant_user where user_id=$U;"
      sql "delete from sys_user where user_id=$U;"
    fi
  done
  # P 组：商家端小程序里招进来的店员 + 发出去的邀请码
  # 商家端 /staff/invite 生成的码没有 smokemsv remark（那是生产端点，不该为测试埋标记），
  # 所以既按记下的 id 删，又按 create_by=mstaff-<老板/店长 uid> 兜底 —— 否则每跑一次
  # 就在 biz_merchant_staff_invite 里漏几条脏码，跑上几十轮后「废码没落库」这类
  # count 断言会被历史残留污染。
  for I in $API_INV_IDS; do sql "delete from biz_merchant_staff_invite where invite_id=$I;"; done
  [ -n "$OWNER_UID" ] && sql "delete from biz_merchant_staff_invite where create_by='mstaff-$OWNER_UID';"
  MGR_SELF_UID=$(sqlv "select user_id from sys_user where user_name='manager_c43' and del_flag='0' limit 1;")
  [ -n "$MGR_SELF_UID" ] && sql "delete from biz_merchant_staff_invite where create_by='mstaff-$MGR_SELF_UID';"
  if [ -n "$P_STF_UID" ]; then
    sql "delete from biz_merchant_staff where user_id=$P_STF_UID;"
    sql "delete from sys_user_role where user_id=$P_STF_UID;"
    sql "delete from biz_merchant_user where user_id=$P_STF_UID;"
    sql "delete from sys_user where user_id=$P_STF_UID;"
  fi
  # 老板给自己重置过密码，必须还原成 admin123，否则后续跑批登不进来
  [ -n "$OWNER_UID" ] && sql "update sys_user set password='$PWD_HASH' where user_id=$OWNER_UID;"
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

# ---- B2) storeId 由员工 token 兜底 ----
# 核销页原来传的是 `storeId || 0`：页面刚进来还没 syncStaff、或缓存里 staffUser
# 没 storeId 时就传 0。后端先过 storeId==null 检查（0 不是 null），再撞上
# hasStore(0) 不匹配 → 抛「无权操作其他门店」。店员扫了客人的码只看到这句，
# 完全不知道是自己这边门店没同步上，一线只能反复退出重进。
# 门店本来就在员工 token 里，让前端传一遍再校验一遍纯属多余 → 员工态下
# storeId 缺失/为 0 时从 token 补。这段锁住三种入参都能核销，且越权仍被拒。
sql "insert into biz_order (order_no, store_id, member_id, merchant_id, product_id, product_name, pay_amount, status, verify_code, create_time) values
 ('SMKSB_N',$STORE_A,1,$MID,1000,'smoke兜底-不传store',9.90,'1','SMKSBCODEN',now()),
 ('SMKSB_Z',$STORE_A,1,$MID,1000,'smoke兜底-传0',9.90,'1','SMKSBCODEZ',now()),
 ('SMKSB_X',$STORE_A,1,$MID,1000,'smoke兜底-越权',9.90,'1','SMKSBCODEX',now());"
SB_ORDERS=1
vfs() { # vfs <body> → 打印 code
  curl -s -X POST "$BASE_URL/api/order/verify" -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $STK" -H "X-App-Id: $APPID" -d "$1"
}
echo "[B2] storeId 由员工 token 兜底"
ck "不传 storeId 也能核销"  "$(vfs '{"verifyCode":"SMKSBCODEN"}' | jtop code)" "200"
ck "  → 订单转已核销"       "$(sqlv "select status from biz_order where order_no='SMKSB_N';")" "2"
ck "  → 核销人落 userId"    "$(sqlv "select verify_user from biz_order where order_no='SMKSB_N';")" "store:$STAFF_UID"
ck "storeId=0 也能核销"     "$(vfs '{"verifyCode":"SMKSBCODEZ","storeId":0}' | jtop code)" "200"
ck "  → 订单转已核销"       "$(sqlv "select status from biz_order where order_no='SMKSB_Z';")" "2"
# 兜底只对「缺失/0」生效，显式传别家门店必须照旧拒 —— 否则等于把越权校验废了
ckc "显式传别店仍被拒"      "$(vfs '{"verifyCode":"SMKSBCODEX","storeId":'"$STORE_B"'}')" "无权操作其他门店"
ck "  → 越权单保持未核销"   "$(sqlv "select status from biz_order where order_no='SMKSB_X';")" "1"
# 用 orderNo（不带 verifyCode）走的是另一条解析分支，兜底同样要生效
ck "orderNo 入参也兜底"     "$(vfs '{"orderNo":"SMKSB_X"}' | jtop code)" "200"
ckc "核销码和订单号都空则拒" "$(vfs '{}')" "核销码或订单编号至少填一个"

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

# ---- M) 会员端识别店员身份 → 免密进商家版 ----
# 已定设计：店员不走小程序登录页扫码，入职只用微信「扫一扫」；已绑 openid 的店员
# 从会员端「我的」→「切换到商家版」静默 wx.login 免密进。
# 「我的」页那个入口的唯一依据就是 hasStaffAccount，所以这个字段必须在
# 「入职前 false / 入职后 true」两个时刻都准确。
if [ -n "$ATK" ]; then
  # M1 同一个微信入职前：会员端不应显示商家版入口
  # 断言不要把跨行的命令替换直接嵌进参数里：那样取到的是空串，
  # 而 ckc 是子串匹配（空串命中任意模式）→ 静默假绿。先存变量再断言。
  MRESP1=$(curl -s -X POST "$BASE_URL/api/auth/login" -H "X-App-Id: $APPID" \
    -H 'Content-Type: application/json' \
    -d "{\"code\":\"smokemsv_dual\",\"appid\":\"$APPID\"}")
  ck "入职前 hasStaffAccount=false" "$(echo "$MRESP1" | jtop hasStaffAccount)" "False"

  # M2 没绑过员工的微信静默切商家版 → 600 NOT_BOUND（前端据此提示「去登录绑定」）
  RESP=$(curl -s -X POST "$BASE_URL/api/merchant/staff/wxLogin" -H "X-App-Id: $APPID" \
    -H 'Content-Type: application/json' -d '{"code":"smokemsv_dual"}')
  ck "未绑员工返 600" "$(echo "$RESP" | jtop code)" "600"

  # M3 用同一个微信扫码入职
  RESP=$(curl -s -X POST "$BASE_URL/biz/staffInvite" -H "Authorization: Bearer $ATK" \
    -H 'Content-Type: application/json' \
    -d "{\"merchantId\":$MID,\"storeId\":$STORE_A,\"role\":\"STAFF\",\"remark\":\"smokemsv_dual\"}")
  M_CODE=$(sqlv "select invite_code from biz_merchant_staff_invite where remark='smokemsv_dual' order by invite_id desc limit 1;")
  RESP=$(curl -s -X POST "$BASE_URL/api/merchant/staff/acceptInvite" -H "X-App-Id: $APPID" \
    -H 'Content-Type: application/json' \
    -d "{\"code\":\"smokemsv_dual\",\"scene\":\"invite:$MID:$STORE_A:$M_CODE\"}")
  echo "[M] 会员端身份识别"
  ckc "入职提交成功" "$RESP" "等待店长审核"
  M_UID=$(sqlv "select user_id from sys_user where openid='mock_smokemsv_dual' and del_flag='0' order by user_id desc limit 1;")

  # M4 入职后会员端就该出现商家版入口
  MRESP2=$(curl -s -X POST "$BASE_URL/api/auth/login" -H "X-App-Id: $APPID" \
    -H 'Content-Type: application/json' \
    -d "{\"code\":\"smokemsv_dual\",\"appid\":\"$APPID\"}")
  ck "入职后 hasStaffAccount=true" "$(echo "$MRESP2" | jtop hasStaffAccount)" "True"

  # M5 待审期间点进去必须是「等待店长审核」（601），不能是含糊的切换失败
  RESP=$(curl -s -X POST "$BASE_URL/api/merchant/staff/wxLogin" -H "X-App-Id: $APPID" \
    -H 'Content-Type: application/json' -d '{"code":"smokemsv_dual"}')
  ck "待审静默登录返 601" "$(echo "$RESP" | jtop code)" "601"
  ck "待审不发 token"    "$(echo "$RESP" | jtop token)"  ""

  # M6 审核通过后免密进商家版
  M_LINK=$(sqlv "select id from biz_merchant_staff where user_id=$M_UID and merchant_id=$MID order by id desc limit 1;")
  if [ -n "$M_LINK" ]; then
    curl -s -X POST "$BASE_URL/biz/staffInvite/staff/audit" -H "Authorization: Bearer $ATK" \
      -H 'Content-Type: application/json' -d "{\"id\":$M_LINK,\"approve\":true}" > /dev/null
    RESP=$(curl -s -X POST "$BASE_URL/api/merchant/staff/wxLogin" -H "X-App-Id: $APPID" \
      -H 'Content-Type: application/json' -d '{"code":"smokemsv_dual"}')
    ck "审核后免密登录成功" "$(echo "$RESP" | jtop code)"      "200"
    ck "拿到 staff token"   "$([ -n "$(echo "$RESP" | jtop token)" ] && echo yes || echo no)" "yes"
    ck "角色是 STAFF"       "$(echo "$RESP" | jtop staffRole)"  "STAFF"
    ck "userType=staff"     "$(echo "$RESP" | jtop userType)"   "staff"
  fi
else
  echo "  SKIP: admin 登录失败，跳过 M"
fi

# ---- N) 平台/代理商不得穿透商家端 @RequireRole ----
# 已定决策：平台账号和代理商不允许登录商家版。原来 RoleAuthInterceptor 里
# 「myRoles 含 PLATFORM 就 ok=true」会放平台账号进任何商家端端点；当时挡住它的
# 只是各端点内部「merchantId 为空」的巧合，而 /me 不依赖 merchantId，实测返 200
# 并吐出账号资料。哪天有平台账号被顺手填上 merchant_id，整片商家端就全敞开。
PLAT_TK=$(mlogin platform_c43 | jtop token)
AGENT_TK=$(mlogin agent_c43   | jtop token)
if [ -n "$PLAT_TK" ]; then
  echo "[N] 平台账号穿透防护"
  # N1 商家端端点一律 403（覆盖 STAFF 级、OWNER/MANAGER 级两种声明）
  for E in me home today/orders today/bills today/bookings finance/summary; do
    ck "平台账号访问 $E 被拒" \
       "$(curl -s "$BASE_URL/api/merchant/staff/$E" -H "X-App-Id: $APPID" \
          -H "Authorization: Bearer $PLAT_TK" | jtop code)" "403"
  done
  # N2 商品写操作同样不能穿透
  PRESP=$(curl -s -X POST "$BASE_URL/api/product/add" -H "X-App-Id: $APPID" \
    -H "Authorization: Bearer $PLAT_TK" -H 'Content-Type: application/json' \
    -d "{\"productName\":\"smokemsv_prod_plat\",\"typeCode\":\"GROUPON\",\"storeIds\":\"$STORE_A\",\"price\":1,\"maxPerOrder\":1}")
  ck "平台账号建商品被拒" "$(echo "$PRESP" | jtop code)" "403"
  ck "平台账号的商品没落库" "$(sqlv "select count(*) from biz_product where product_name='smokemsv_prod_plat';")" "0"
  # N3 平台自己的专属端点必须还能用（收口不能把正常功能一起砍掉）
  ck "平台专属端点仍可用" \
     "$(curl -s "$BASE_URL/api/merchant/staff/platform/finance/summary" -H "X-App-Id: $APPID" \
        -H "Authorization: Bearer $PLAT_TK" | jtop code)" "200"
  # N4 平台账号也不能借放行去访问代理商端点
  ck "平台账号访问代理商端点被拒" \
     "$(curl -s "$BASE_URL/api/agent/info" -H "X-App-Id: $APPID" \
        -H "Authorization: Bearer $PLAT_TK" | jtop code)" "403"
fi
if [ -n "$AGENT_TK" ]; then
  # N5 代理商专属端点不能被这次收口打断
  for E in info stats; do
    ck "代理商专属 $E 仍可用" \
       "$(curl -s "$BASE_URL/api/agent/$E" -H "X-App-Id: $APPID" \
          -H "Authorization: Bearer $AGENT_TK" | jtop code)" "200"
  done
  # N6 代理商同样不得进商家端
  ck "代理商访问商家端被拒" \
     "$(curl -s "$BASE_URL/api/merchant/staff/home" -H "X-App-Id: $APPID" \
        -H "Authorization: Bearer $AGENT_TK" | jtop code)" "403"
fi

# ---- O) 扫码入职的店长要能在 PC 后台接着招下一个店员 ----
# 为什么锁这组：createStaffByOpenid 建账号时只写 sys_user.merchant_id，
# 既没绑 PC 角色、也没往 biz_merchant_user 落租户归属。造成两个实测缺陷：
#   1) 店长登 PC 后台 permissions 为空集，/biz/staffInvite/** 四个端点全 403，
#      「老板招店长 → 店长再招店员」这条链在第二环直接断掉；
#   2) PC 端租户身份只认 biz_merchant_user（TenantServiceImpl.buildContextByUserId），
#      查不到记录会兜底成「平台账号」—— 实测 /getInfo 返 userType=0，
#      /biz/store/list 返回 merchant_id=2/200 的别家门店，属跨商户泄漏。
# STAFF 只在小程序核销，不该拿到 PC 权限，但租户归属仍必须落库（否则同样兜底成平台）。
if [ -n "$ATK" ]; then
  echo "[O] 扫码入职店长的后台权限与租户归属"

  # O1 发一张 MANAGER 码，走真实扫码入职
  curl -s -X POST "$BASE_URL/biz/staffInvite" -H "Authorization: Bearer $ATK" \
    -H 'Content-Type: application/json' \
    -d "{\"merchantId\":$MID,\"storeId\":$STORE_A,\"role\":\"MANAGER\",\"remark\":\"smokemsv_omgr\"}" >/dev/null
  O_CODE=$(sqlv "select invite_code from biz_merchant_staff_invite where remark='smokemsv_omgr' order by invite_id desc limit 1;")
  RESP=$(curl -s -X POST "$BASE_URL/api/merchant/staff/acceptInvite" -H "X-App-Id: $APPID" \
    -H 'Content-Type: application/json' \
    -d "{\"code\":\"smokemsv_omgr_wx\",\"scene\":\"invite:$MID:$STORE_A:$O_CODE\",\"nickName\":\"smokemsv_omgr\"}")
  ckc "店长扫码入职成功" "$RESP" "等待店长审核"
  O_MGR_UID=$(sqlv "select user_id from sys_user where openid='mock_smokemsv_omgr_wx' and del_flag='0' order by user_id desc limit 1;")
  ck "店长账号已建" "$([ -n "$O_MGR_UID" ] && echo yes || echo no)" "yes"

  if [ -n "$O_MGR_UID" ]; then
    # O2 两张附表必须落：PC 角色（merchant）+ 租户归属（userType=2/本商户）
    ck "店长绑到 PC 商户管理员角色" \
       "$(sqlv "select count(*) from sys_user_role ur join sys_role r on r.role_id=ur.role_id where ur.user_id=$O_MGR_UID and r.role_key='merchant';")" "1"
    ck "店长租户归属已落库" \
       "$(sqlv "select concat(user_type,'/',merchant_id) from biz_merchant_user where user_id=$O_MGR_UID;")" "2/$MID"

    # O3 审核在职 + 重置密码后登 PC 后台
    O_SID=$(sqlv "select id from biz_merchant_staff where user_id=$O_MGR_UID limit 1;")
    curl -s -X POST "$BASE_URL/biz/staffInvite/staff/audit" -H "Authorization: Bearer $ATK" \
      -H 'Content-Type: application/json' -d "{\"id\":$O_SID,\"approve\":true}" >/dev/null
    O_PWD=$(curl -s -X PUT "$BASE_URL/biz/staffInvite/staff/resetPwd/$O_MGR_UID" -H "Authorization: Bearer $ATK" \
      -H 'Content-Type: application/json' -d '{}' | jtop newPassword)
    O_USER=$(sqlv "select user_name from sys_user where user_id=$O_MGR_UID;")
    O_TK=$(curl -s -X POST "$BASE_URL/login" -H 'Content-Type: application/json' \
      -d "{\"username\":\"$O_USER\",\"password\":\"$O_PWD\"}" | jtop token)
    ck "店长能登 PC 后台" "$([ -n "$O_TK" ] && echo yes || echo no)" "yes"

    if [ -n "$O_TK" ]; then
      # O4 身份不能兜底成平台（兜底会看到别家商户数据）
      INFO=$(curl -s "$BASE_URL/getInfo" -H "Authorization: Bearer $O_TK")
      ck "店长身份是商户而非平台" "$(echo "$INFO" | jtop userType)"   "2"
      ck "店长身份带本商户ID"    "$(echo "$INFO" | jtop merchantId)" "$MID"

      # O5 招下一个店员的四个端点必须通（原来全 403）
      ck "店长看待审列表"  "$(curl -s "$BASE_URL/biz/staffInvite/staff/audit" -H "Authorization: Bearer $O_TK" | jtop code)" "200"
      ck "店长看员工名单"  "$(curl -s "$BASE_URL/biz/staffInvite/staff/list"  -H "Authorization: Bearer $O_TK" | jtop code)" "200"
      RESP=$(curl -s -X POST "$BASE_URL/biz/staffInvite" -H "Authorization: Bearer $O_TK" \
        -H 'Content-Type: application/json' \
        -d "{\"merchantId\":$MID,\"storeId\":$STORE_A,\"role\":\"STAFF\",\"remark\":\"smokemsv_obymgr\"}")
      ckc "店长能自己发店员邀请码" "$RESP" "已生成邀请码"

      # O6 门店列表只能是本商户（兜底成平台时实测会多出 merchant_id=2/200）
      OTHER=$(curl -s "$BASE_URL/biz/store/list?pageSize=100" -H "Authorization: Bearer $O_TK" \
        | python3 -c "
import sys,json
rows=(json.load(sys.stdin).get('rows') or [])
print(sum(1 for r in rows if r.get('merchantId') not in (None, $MID)))")
      ck "店长看不到别家门店" "$OTHER" "0"
    fi
  fi

  # O7 店员只在小程序核销，不该拿 PC 角色；但租户归属仍必须落
  curl -s -X POST "$BASE_URL/biz/staffInvite" -H "Authorization: Bearer $ATK" \
    -H 'Content-Type: application/json' \
    -d "{\"merchantId\":$MID,\"storeId\":$STORE_A,\"role\":\"STAFF\",\"remark\":\"smokemsv_ostf\"}" >/dev/null
  O_SCODE=$(sqlv "select invite_code from biz_merchant_staff_invite where remark='smokemsv_ostf' order by invite_id desc limit 1;")
  curl -s -X POST "$BASE_URL/api/merchant/staff/acceptInvite" -H "X-App-Id: $APPID" \
    -H 'Content-Type: application/json' \
    -d "{\"code\":\"smokemsv_ostf_wx\",\"scene\":\"invite:$MID:$STORE_A:$O_SCODE\",\"nickName\":\"smokemsv_ostf\"}" >/dev/null
  O_STF_UID=$(sqlv "select user_id from sys_user where openid='mock_smokemsv_ostf_wx' and del_flag='0' order by user_id desc limit 1;")
  if [ -n "$O_STF_UID" ]; then
    ck "店员没拿到任何 PC 角色" "$(sqlv "select count(*) from sys_user_role where user_id=$O_STF_UID;")" "0"
    ck "店员租户归属仍已落库"   "$(sqlv "select concat(user_type,'/',merchant_id) from biz_merchant_user where user_id=$O_STF_UID;")" "2/$MID"
  fi
fi

# ---- P) 商家端「店员管理」：店长在店里用手机就地招人/审核/重置密码 ----
# 为什么锁这组：招店员的四个动作原本只有 PC 后台有。店长的工作场景在店里、
# 手上只有手机 —— 新人站柜台前扫码入职，店长得跑去开电脑登后台才能点通过，
# 真实门店没人会走这个流程。这组锁住整条链在小程序端可用，且权限不能松：
#   · 店员(STAFF)一个管人端点都不能碰（否则能给自己发 OWNER 码提权）
#   · 角色管理是「严格高于」：店长不能审/改/重置另一个店长，更不能碰老板
#   · 门店归属必须校验，否则发出去的是「自己商户 + 别家门店」的死码
mapi() { # mapi <method> <path> <token> [body]
  if [ "$1" = "GET" ]; then
    curl -s "$BASE_URL/api/merchant/staff/$2" -H "X-App-Id: $APPID" -H "Authorization: Bearer $3"
  else
    curl -s -X "$1" "$BASE_URL/api/merchant/staff/$2" -H "X-App-Id: $APPID" \
      -H "Authorization: Bearer $3" -H 'Content-Type: application/json' -d "${4:-\{\}}"
  fi
}

if [ -n "$OTK" ]; then
  echo "[P] 商家端店员管理"

  # P1 三个只读端点在小程序端可用
  ck "老板看员工名单(小程序)"   "$(mapi GET staff/list "$OTK"        | jtop code)" "200"
  ck "老板看待审列表(小程序)"   "$(mapi GET staff/audit/list "$OTK"  | jtop code)" "200"
  ck "老板看邀请码列表(小程序)" "$(mapi GET staff/invite/list "$OTK" | jtop code)" "200"

  # P2 发码：默认当前门店，落库 scene 必须与门店一致（否则是永远扫不动的死码）
  RESP=$(mapi POST staff/invite "$OTK" '{"role":"STAFF","storeId":'"$STORE_A"'}')
  ckc "老板在小程序发店员码" "$RESP" "已生成邀请码"
  P_CODE=$(echo "$RESP" | jtop inviteCode)
  P_IID=$(echo "$RESP" | jtop inviteId)
  APII=$(echo "$RESP" | jtop inviteId); [ -n "$APII" ] && API_INV_IDS="$API_INV_IDS $APII"
  ck "发码返回短码" "$([ -n "$P_CODE" ] && echo yes || echo no)" "yes"
  ck "落库 scene 与门店一致" \
     "$(sqlv "select scene from biz_merchant_staff_invite where invite_code='$P_CODE';")" \
     "invite:$MID:$STORE_A:AUTO"
  ck "落库门店与请求一致" \
     "$(sqlv "select store_id from biz_merchant_staff_invite where invite_code='$P_CODE';")" "$STORE_A"

  # P3 越权发码必须拒
  ckc "不能邀请 OWNER"      "$(mapi POST staff/invite "$OTK" '{"role":"OWNER"}')"  "只能邀请店长或店员"
  ckc "不能给别家门店招人"  "$(mapi POST staff/invite "$OTK" '{"role":"STAFF","storeId":999999}')" "无权为该门店招人"
  ck  "废码没落库" "$(sqlv "select count(*) from biz_merchant_staff_invite where store_id=999999;")" "0"

  # P4 小程序码复用：第二次取必须命中缓存，不重复烧微信 wxacode 配额
  if [ -n "$P_IID" ]; then
    Q1=$(mapi GET "staff/invite/qrcode/$P_IID" "$OTK")
    ck "取小程序码成功"   "$(echo "$Q1" | jtop code)"   "200"
    U1=$(echo "$Q1" | jtop url)
    Q2=$(mapi GET "staff/invite/qrcode/$P_IID" "$OTK")
    ck "二次取命中缓存"   "$(echo "$Q2" | jtop cached)" "True"
    ck "两次 URL 完全一致" "$(echo "$Q2" | jtop url)"   "$U1"
  fi

  # P5 完整闭环：新人扫码入职 → 老板在小程序审核 → 新人能登商家版
  if [ -n "$P_CODE" ]; then
    RESP=$(curl -s -X POST "$BASE_URL/api/merchant/staff/acceptInvite" -H "X-App-Id: $APPID" \
      -H 'Content-Type: application/json' \
      -d "{\"code\":\"smokemsv_pteam\",\"scene\":\"invite:$MID:$STORE_A:$P_CODE\",\"nickName\":\"smokemsv_pteam\"}")
    ckc "新人扫码入职" "$RESP" "等待店长审核"
    P_STF_UID=$(sqlv "select user_id from sys_user where openid='mock_smokemsv_pteam' and del_flag='0' order by user_id desc limit 1;")
    P_SID=$(sqlv "select id from biz_merchant_staff where user_id=$P_STF_UID limit 1;")
    ck "入职后是待审核态" "$(sqlv "select status from biz_merchant_staff where id=$P_SID;")" "3"
    # 待审核的人必须出现在小程序待审列表里，否则店长根本看不到要审谁
    ck "待审列表含该新人" \
       "$(mapi GET staff/audit/list "$OTK" | python3 -c "
import sys,json
d=json.load(sys.stdin); rows=d.get('data') or []
print(sum(1 for r in rows if str(r.get('id'))=='$P_SID'))")" "1"

    ckc "老板在小程序审核通过" "$(mapi POST staff/audit "$OTK" '{"id":'"$P_SID"',"approve":true}')" "已通过"
    ck  "审核后转在职" "$(sqlv "select status from biz_merchant_staff where id=$P_SID;")" "0"
    ckc "重复审核被拒"  "$(mapi POST staff/audit "$OTK" '{"id":'"$P_SID"',"approve":true}')" "不在待审核状态"

    # P6 重置密码：新密码必须真能登进商家版（这是店员丢密码后唯一的补救途径）
    RESP=$(mapi POST staff/resetPwd "$OTK" '{"userId":'"$P_STF_UID"'}')
    ckc "老板在小程序重置店员密码" "$RESP" "已重置密码"
    P_NEWPWD=$(echo "$RESP" | jtop newPassword)
    P_UNAME=$(echo "$RESP" | jtop userName)
    LOGIN=$(curl -s -X POST "$BASE_URL/api/merchant/staff/login" -H "X-App-Id: $APPID" \
      -H 'Content-Type: application/json' -d "{\"username\":\"$P_UNAME\",\"password\":\"$P_NEWPWD\"}")
    ck "新密码能登商家版" "$(echo "$LOGIN" | jtop code)"     "200"
    ck "登录角色是 STAFF"  "$(echo "$LOGIN" | jget staffRole)" "STAFF"

    # P7 离职：登录必须被挡住，历史核销记录不受影响（用离职态而不是删账号）
    ckc "老板办店员离职" "$(mapi POST staff/dismiss "$OTK" '{"id":'"$P_SID"'}')" "已办理离职"
    ck  "离职后 status=1" "$(sqlv "select status from biz_merchant_staff where id=$P_SID;")" "1"
    LOGIN=$(curl -s -X POST "$BASE_URL/api/merchant/staff/login" -H "X-App-Id: $APPID" \
      -H 'Content-Type: application/json' -d "{\"username\":\"$P_UNAME\",\"password\":\"$P_NEWPWD\"}")
    ckc "离职后登不进商家版" "$LOGIN" "未关联商家"
    ck  "员工账号仍保留(不是物理删)" "$(sqlv "select count(*) from sys_user where user_id=$P_STF_UID and del_flag='0';")" "1"
    ckc "重复离职被拒" "$(mapi POST staff/dismiss "$OTK" '{"id":'"$P_SID"'}')" "已离职"
    ckc "复职成功"     "$(mapi POST staff/restore "$OTK" '{"id":'"$P_SID"'}')" "已复职"
    ck  "复职后 status=0" "$(sqlv "select status from biz_merchant_staff where id=$P_SID;")" "0"
  fi

  # P8 自我保护：不能办自己离职，但可以给自己换密码
  # canManageRole 是「严格大于」，自己对自己必然不满足 —— 自我保护分支必须排在它前面，
  # 否则老板看到的是「无权操作该角色的员工」，会以为权限配错了去找平台。
  O_SELF_SID=$(sqlv "select id from biz_merchant_staff where user_id=$OWNER_UID limit 1;")
  ckc "不能办自己离职(提示要准确)" "$(mapi POST staff/dismiss "$OTK" '{"id":'"$O_SELF_SID"'}')" "不能对自己办理离职"
  RESP=$(mapi POST staff/resetPwd "$OTK" '{"userId":'"$OWNER_UID"'}')
  ckc "可以给自己换密码" "$RESP" "已重置密码"
  O_SELF_PWD=$(echo "$RESP" | jtop newPassword)
  # 必须先存变量：把跨行命令替换直接嵌进 ck 参数里，shell 解析后参数会错位，
  # 实际值落到期望值那一位上，于是「500 = 500」判成 OK —— 假绿。
  SELF_LOGIN=$(curl -s -X POST "$BASE_URL/api/merchant/staff/login" -H "X-App-Id: $APPID" \
    -H 'Content-Type: application/json' \
    -d "{\"username\":\"smokemsv_owner\",\"password\":\"$O_SELF_PWD\"}")
  ck "自己的新密码能登录" "$(echo "$SELF_LOGIN" | jtop code)" "200"
fi

# P9 店员一个管人端点都不能碰（否则店员能给自己发 OWNER 码提权）
if [ -n "$STK" ]; then
  for E in staff/list staff/audit/list staff/invite/list; do
    ck "店员访问 $E 被拒" "$(mapi GET "$E" "$STK" | jtop code)" "403"
  done
  for E in staff/invite staff/audit staff/resetPwd staff/dismiss staff/restore; do
    ck "店员调 $E 被拒" "$(mapi POST "$E" "$STK" '{}' | jtop code)" "403"
  done
  # 收口不能把店员本职功能一起砍掉
  ck "店员核销工作台仍可用" "$(mapi GET home "$STK" | jtop code)" "200"
fi

# P10 店长只能管店员，不能碰另一个店长/老板（rank 严格大于）
MGR_TK=$(mlogin manager_c43 | jget token)
if [ -n "$MGR_TK" ]; then
  ckc "店长不能邀请店长" "$(mapi POST staff/invite "$MGR_TK" '{"role":"MANAGER"}')" "无权邀请该角色"
  if [ -n "$OWNER_UID" ]; then
    # 只断言「被拒」而不锁具体文案：smokemsv_owner 是 store_id=0（全商户）老板，
    # 门店 100 的店长会先被 isStaffVisible 的 store_id=0 分支挡住（提示「无权重置该员工密码」），
    # 走不到 canManageRole 那句。两道都是必须的拦截，文案取决于哪道先命中。
    ck "店长不能重置老板密码" "$(mapi POST staff/resetPwd "$MGR_TK" '{"userId":'"$OWNER_UID"'}' | jtop code)" "500"
    O_SELF_SID2=$(sqlv "select id from biz_merchant_staff where user_id=$OWNER_UID limit 1;")
    ck "店长不能办老板离职" "$(mapi POST staff/dismiss "$MGR_TK" '{"id":'"$O_SELF_SID2"'}' | jtop code)" "500"
    # 用 P8 那次自助重置后的密码验证，不能用 admin123 —— P8 已经把它换掉了。
    # 这条锁的是「店长那两次尝试真的没改到老板密码」，而不是密码本身是什么。
    OWNER_STILL=$(curl -s -X POST "$BASE_URL/api/merchant/staff/login" -H "X-App-Id: $APPID" \
      -H 'Content-Type: application/json' \
      -d "{\"username\":\"smokemsv_owner\",\"password\":\"$O_SELF_PWD\"}")
    ck "老板密码没被店长改掉" "$(echo "$OWNER_STILL" | jtop code)" "200"
  fi
  # 同门店场景：店长与老板同在门店 100 时，必须由 canManageRole 挡住（rank 严格大于）
  SAME_STORE_OWNER=$(sqlv "select ms.user_id from biz_merchant_staff ms join sys_user u on u.user_id=ms.user_id where ms.merchant_id=$MID and ms.store_id=$STORE_A and ms.role='OWNER' and u.del_flag='0' limit 1;")
  if [ -n "$SAME_STORE_OWNER" ]; then
    ckc "同门店店长仍不能重置老板密码" \
       "$(mapi POST staff/resetPwd "$MGR_TK" '{"userId":'"$SAME_STORE_OWNER"'}')" "无权重置该角色"
  fi
  MGR_INV=$(mapi POST staff/invite "$MGR_TK" '{"role":"STAFF","storeId":'"$STORE_A"'}')
  ckc "店长可以邀请店员" "$MGR_INV" "已生成邀请码"
  MGR_IID=$(echo "$MGR_INV" | jtop inviteId); [ -n "$MGR_IID" ] && API_INV_IDS="$API_INV_IDS $MGR_IID"
fi

# P11 平台/代理商账号不得借店员管理穿透进商家端
if [ -n "$PLAT_TK" ]; then
  for E in staff/list staff/audit/list; do
    ck "平台账号访问 $E 被拒" "$(mapi GET "$E" "$PLAT_TK" | jtop code)" "403"
  done
  ck "平台账号发邀请码被拒" "$(mapi POST staff/invite "$PLAT_TK" '{"role":"STAFF"}' | jtop code)" "403"
fi
if [ -n "$AGENT_TK" ]; then
  ck "代理商访问店员名单被拒" "$(mapi GET staff/list "$AGENT_TK" | jtop code)" "403"
fi

echo
if [ $FAIL -eq 0 ]; then echo "smoke-merchant-staff-verify: ALL PASSED"; else echo "smoke-merchant-staff-verify: FAILED"; exit 1; fi
