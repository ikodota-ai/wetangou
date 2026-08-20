#!/usr/bin/env bash
# smoke 共享 fixture 库（source 引入，不单独执行）
#
# 背景（见 AGENTS.md「项目摸底 + 实测基线（2026-08-20）」）：
#   62 个 smoke 串行跑时曾有 22 个 FAIL，逐个定位后**全部是 fixture 漂移**，0 个产品缺陷：
#     - staff001 密码被历史脚本改过      → fx_reset_staff_pwd
#     - 商品 1000 库存被历史下单耗尽      → fx_ensure_product_stock
#     - c53 改了 member 1000197 的 openid → fx_pin_member_openid
#     - e13~e17 fixture 表数据被清掉      → fx_load_e13_e17_fixture
#     - 脚本用会员 token 调 OWNER 端点     → fx_login_owner / fx_login_staff_role
#
# 用法：
#   source "$(dirname "$0")/lib/smoke-fixture.sh"
#   fx_reset_staff_pwd
#   TOK=$(fx_login_owner)

FX_H="${FX_H:-http://127.0.0.1:8080}"
FX_MYSQL="${FX_MYSQL:-/usr/local/mysql/bin/mysql}"
FX_DB="${FX_DB:-$FX_MYSQL -h127.0.0.1 -uroot -p133301 ry-vue}"
FX_APPID="${FX_APPID:-wx9e147c4e2151b123}"
# admin123 的 BCrypt 哈希（与 sys_user user_id=1 admin 同）
FX_PWD_HASH='$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2'

fx_sql() { $FX_DB -N -B -e "$1" 2>/dev/null; }

# 把 staff 账号密码重置为 admin123（历史 smoke 会改密码，导致后续脚本登录 500）
# $1 = user_name（默认 staff001）
fx_reset_staff_pwd() {
  local u="${1:-staff001}"
  fx_sql "UPDATE sys_user SET password='$FX_PWD_HASH', status='0', del_flag='0' WHERE user_name='$u';"
}

# 商户员工必须是 sys_user.user_type='02'（见 BizRole 注释：OWNER/MANAGER/STAFF 都是 '02'）。
# 历史 fixture 把 staff001 写成 '00'（平台），buildStaffLoginMember 会把 userType 覆盖成
# platform，于是商家端点 requireMerchantLogin() 抛「非商家员工身份」。
# $1 = user_name（默认 staff001）
fx_fix_staff_user_type() {
  local u="${1:-staff001}"
  fx_sql "UPDATE sys_user SET user_type='02' WHERE user_name='$u';"
}

# 确保商品有库存 + 在售（历史下单会把 stock 耗成 0，1000 号商品还被逻辑删除过 del_flag=2）
# $1 = product_id  $2 = stock（默认 999）
fx_ensure_product_stock() {
  local pid="$1" stock="${2:-999}"
  [ -n "$pid" ] || return 1
  fx_sql "UPDATE biz_product SET stock=$stock, status='0', del_flag='0' WHERE product_id=$pid;"
}

# 把某 member 的 openid 钉回 mock 约定值（防止别的脚本改走后本脚本认不出归属人）
# mock 规则见 WxMaService:84 —— openid = "mock_" + jsCode
# $1 = member_id  $2 = jsCode（openid 写成 mock_<jsCode>）
# biz_member 有唯一键 uk_merchant_openid(merchant_id, openid)。历史 smoke 反复用同一个
# jsCode 登录会造出「openid 已被另一个 member 占用」的局面，直接 UPDATE 会 ERROR 1062。
# 所以先把占用者的 openid 腾空，再钉给目标 member。
fx_pin_member_openid() {
  local mid="$1" code="$2"
  [ -n "$mid" ] && [ -n "$code" ] || return 1
  fx_sql "UPDATE biz_member SET openid=CONCAT('freed_', member_id) WHERE openid='mock_${code}' AND member_id<>$mid;"
  fx_sql "UPDATE biz_member SET openid='mock_${code}' WHERE member_id=$mid;"
}

# 载入 e13~e17 跨租户越权 fixture（banner/booking/store/album/category/agreement 的 999301/999302）
# 缺这批数据时 getInfo 拿到 null 会直接 success()，assertDataScope 根本没机会跑 → 假 FAIL
fx_load_e13_e17_fixture() {
  local f="${1:-sql/smoke-e13-e17-fixture.sql}"
  [ -f "$f" ] || return 0
  $FX_MYSQL --default-character-set=utf8mb4 -h127.0.0.1 -uroot -p133301 ry-vue < "$f" >/dev/null 2>&1
  return 0
}

# 用账号密码登录一个带真实 staff 角色的账号，返回 token
# fixture 账号：owner_c43=OWNER / manager_c43=MANAGER / staff_c43=STAFF
# $1 = user_name（默认 owner_c43）
fx_login_staff_role() {
  local u="${1:-owner_c43}"
  fx_reset_staff_pwd "$u"
  curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"username\":\"$u\",\"password\":\"admin123\"}" \
    "$FX_H/api/merchant/staff/login" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null
}

# 语义化别名：拿 OWNER token（@RequireRole({OWNER,MANAGER}) 端点用）
fx_login_owner() { fx_login_staff_role owner_c43; }

# 拿 admin（平台）token，用于 PC 后台 /biz/** 端点
fx_login_admin() {
  curl -s -X POST -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"admin123"}' "$FX_H/login" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null
}

# 小程序会员登录（mock），输出 "token memberId"
# $1 = jsCode（openid 会是 mock_<jsCode>）  $2 = nickName
fx_login_member() {
  local code="$1" nick="${2:-fx_member}"
  curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"code\":\"$code\",\"appid\":\"$FX_APPID\",\"nickName\":\"$nick\"}" \
    "$FX_H/api/auth/login" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('token',''), d.get('memberId',0))" 2>/dev/null
}

# 确保 mock 登录/支付开关开着（本地 smoke 依赖；prod profile 下代码层强制关，不受影响）
fx_ensure_mock_on() {
  fx_sql "UPDATE sys_config SET config_value='true' WHERE config_key IN ('wx.miniapp.mockEnabled','wx.pay.mockEnabled');"
  fx_sql "UPDATE biz_merchant SET mock_enabled='0' WHERE merchant_id=1;"
  command -v redis-cli >/dev/null 2>&1 && \
    redis-cli -h 127.0.0.1 -p 6379 DEL 'sys_config:wx.miniapp.mockEnabled' 'sys_config:wx.pay.mockEnabled' 'merchant:id:1' "merchant:appid:$FX_APPID" >/dev/null 2>&1
  return 0
}

# 让某 member「在业务上视为无 openid」。
# 注意：biz_member.openid 是 NOT NULL，且有唯一键 uk_merchant_openid(merchant_id, openid)，
# 所以既不能置 NULL（ERROR 1048），也不能统一置 ''（第二个会 ERROR 1062）。
# 后端判定是 openid == null || openid.isEmpty()（ApiOrderController:318），
# 这里给一个唯一的 noopenid_<memberId> 占位：不为空但也不是真 openid，
# 需要「无 openid 分支」的用例请改断言为「该 openid 不是有效微信 openid」。
# 若用例必须走 isEmpty() 分支，则先腾空同商户内已有的 '' 占用者再置空。
fx_clear_member_openid() {
  local mid="$1"
  [ -n "$mid" ] || return 1
  # 腾空同商户里已经占着 '' 的那条（历史脚本留下的）
  fx_sql "UPDATE biz_member SET openid=CONCAT('freed_', member_id) WHERE openid='' AND member_id<>$mid;"
  fx_sql "UPDATE biz_member SET openid='' WHERE member_id=$mid;"
}
