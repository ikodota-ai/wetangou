#!/usr/bin/env bash
# =============================================================================
# 全新环境一键初始化（2026-08-21 实测通过）
#
# 用法：
#   bash sql/deploy/init-all.sh <db_name> [mysql_client]
#   # 例：
#   bash sql/deploy/init-all.sh ry-vue
#   bash sql/deploy/init-all.sh ry-vue /usr/local/mysql/bin/mysql
#
# 环境变量：
#   DB_HOST（默认 127.0.0.1） DB_PORT（3306） DB_USER（root） DB_PASSWORD
#   WITH_DEMO=1  额外导入演示/测试数据（生产不要开）
#
# 说明：
#   - 顺序敏感，不要重排：建表 → v2 加列 → 依赖加列的脚本 → 菜单 → 种子
#   - 全部脚本幂等，可重复执行
#   - ⚠️ 会 drop 并重建业务表，只能对**空库/新库**执行
# =============================================================================
set -uo pipefail

DB="${1:-}"
MYSQL_BIN="${2:-}"
if [ -z "$DB" ]; then echo "用法: bash sql/deploy/init-all.sh <db_name> [mysql_client]" >&2; exit 2; fi
if [ -z "$MYSQL_BIN" ]; then
  if command -v mysql >/dev/null 2>&1; then MYSQL_BIN=mysql
  elif [ -x /usr/local/mysql/bin/mysql ]; then MYSQL_BIN=/usr/local/mysql/bin/mysql
  else echo "找不到 mysql 客户端，请作为第 2 个参数传入路径" >&2; exit 2; fi
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# 脚本按用途分了子目录：
#   sql/          全新库初始化用的建表 / 加列 / 菜单 / 种子
#   sql/upgrade/  存量库的增量迁移（历史上遗漏过接线，见下方 5.5 段）
#   sql/archive/  一次性调试产物，不参与任何部署
run() {
  local f="sql/$1.sql"
  [ -f "$f" ] || f="sql/upgrade/$1.sql"
  [ -f "$f" ] || { echo "SKIP $1 (文件不存在)"; return 0; }
  local out
  out=$("$MYSQL_BIN" --default-character-set=utf8mb4 \
        -h"${DB_HOST:-127.0.0.1}" -P"${DB_PORT:-3306}" \
        -u"${DB_USER:-root}" -p"${DB_PASSWORD:-}" "$DB" < "$f" 2>&1 \
        | grep -E '^ERROR' | head -3)
  if [ -z "$out" ]; then
    printf 'OK   %s\n' "$1"
  else
    printf 'FAIL %s\n     %s\n' "$1" "$out"
    FAILED=$((FAILED + 1))
  fi
}

FAILED=0
echo "=== 初始化 $DB（client=$MYSQL_BIN）==="

echo "--- 1/6 RuoYi 基础 + 定时任务 ---"
run ry_20260417
run quartz

echo "--- 2/6 业务建表 ---"
run biz_tables
run biz_tenant_tables
run biz_tenant_upgrade

echo "--- 3/6 v2 商品模型 / 员工 / sys_user 扩展列（顺序敏感）---"
run biz_product_model_v2        # 建 biz_product_category / _type / _subitem(_group)
run biz_product_model_v2_safe   # 加 sys_user.user_type/merchant_id + biz_product v2 列
run biz_merchant_v2             # sys_user.openid + biz_merchant_staff(_invite)
run biz_product_columns_v3
run biz_product_ext             # 1:1 扩展表，ProductMapper 会 left join，缺表 → 商品列表 500
run biz_product_stores
run biz_stored_card_v3
run biz_combo_subitem_v2
run biz_role_extension          # 依赖 biz_merchant_staff + sys_user.user_type

echo "--- 4/6 代理商 / 会员 / 预约 / 门店 ---"
run biz_agent_v25
run biz_agent_store_quota_hotfix
run biz_agent_role_permissions
run biz_member_agent_identity
run biz_distributor_invite
run biz_booking_upgrade
run biz_booking_slot_config
run biz_booking_staff_review
run biz_merchant_service_hours_upgrade
run biz_store_service
run migration-2026-08-14-f1-category-store-id

echo "--- 5/6 菜单 / 权限 / 配置 ---"
run biz_menu_reorganization      # 先建 5 个分组目录（门店商品/交易订单/...）
run biz_menu_business_pages     # 再挂 19 个业务菜单页 + 按钮权限（代码生成器产物，从无 SQL）
run biz_menu_flatten
run biz_tenant_menu
run biz_mpconfig_menu
run biz_wxconfig_menu
run biz_wxconfig_init
run biz_banner
run biz_commission_settle_job
run biz_commission_settle_link
run biz_phone_decrypt
run biz_order_verify_bill_confirm
run biz_order_verifycode_fix
run biz_agent_commission_c1
run biz_booking_member_menu
run v2_admin_menus
run v3_p2_menus_routes
run migration-2026-08-14-f2-mpauth-menu

# 再跑一遍菜单补齐：部分按钮的父菜单（预约明细 / 提现申请）由上面的脚本创建，
# 第一遍时 @pid 为空挂不上，这里补挂。脚本幂等，重复执行安全。
run biz_menu_business_pages

# 这 6 个是历史增量迁移，长期只在存量库手工跑过、从没接进初始化链 ——
# 于是全新库缺渠道字典表、菜单名还是旧的、2292/2293 死菜单还在。
# 它们都幂等，放在菜单段之后统一补上。
echo "--- 5.5/6 增量迁移（sql/upgrade，存量库同样要跑）---"
run biz_product_field_gap_v4        # biz_sale_channel 表 + ext 9 列 + 渠道字典菜单
run biz_mpauth_menu_fix             # 小程序授权菜单补齐 + 越权按钮回收
run biz_category_menu_rename        # 菜单「商品分类」→「行业品类」
run biz_product_detail_menu_fix_v5  # 删 2292/2293 两条从不下发的死菜单
run biz_product_category_join_fix   # 商品/佣金规则的分类 join 指向 biz_product_category
run biz_staff_usertype_hotfix       # 修扫码入职店员拿到平台权限（P0 越权）
run biz_collect_method_semantic_v6  # collect_method 语义归一为收款方式
run biz_bill_auto_confirm_v7        # 门店级买单自动确认开关（默认开，买单免店员确认）
run biz_store_rating_booking_type_v8 # 门店评分列 + 预约类型字典 + biz_booking.booking_type
run biz_member_avatar_relative_v9    # 会员头像洗成相对路径（去掉内网 host 前缀）
run biz_store_booking_rule_v10       # 门店级预约可约范围（提前天数/时段粒度/歇业日）
run biz_merchant_appid_null_v11      # 空 appid 洗成 NULL（uk_appid 不容多个空串，否则第二个不填 appid 的商户建不出来）
run biz_merchant_staff_perms_v12     # 商户管理员/代理商补店员邀请权限（老板原本招不了店员，全 403）
run biz_staff_tenant_backfill_v13    # 回填扫码入职员工的租户归属（缺记录会兜底成平台身份、看到别家商户数据）
run biz_staff_pc_role_backfill_v14   # 回填老板/店长缺失的 PC 角色（无角色 = 后台全 403，重置不了员工密码）
run biz_merchant_promoter_enabled_20260903  # 商户级推客总开关（关掉后小程序不显示「推客中心」入口）
run wx_miniapp_env_version_20260903        # 小程序码指向版本（未发布必须 trial，否则邀请码报 40066 invalid url）
run biz_withdraw_rule_20260903       # 提现规则（起提额/每日次数/受理时段/到账时效，微信审核要求提现页展示）

echo "--- 6/6 字典 / 种子 ---"
run biz_product_dict_charset_fix
run biz_product_industry_sync_safe
run biz_product_seed

if [ "${WITH_DEMO:-0}" = "1" ]; then
  echo "--- 附加：演示 / 测试数据（生产勿用）---"
  run biz_seed
  run biz_demo_data
  run biz_banner_home_seed
  run biz_product_subitem_seed
  run biz_fee_staffinvite_seed
  run biz_mpauth_settle_seed
  run smoke-e13-e17-fixture
  run smoke_v25_distributor_setup
  run biz_方案C身份路由测试账号
fi

echo
echo "=============================="
if [ "$FAILED" -eq 0 ]; then
  echo "全部执行成功（FAILED=0）"
  echo "默认管理员：admin / admin123"
  echo "生产别忘了：mysql ... < sql/deploy/sys_config_production.sql"
else
  echo "有 $FAILED 个脚本失败，请查看上面的 FAIL 行"
fi
exit "$FAILED"
