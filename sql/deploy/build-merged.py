#!/usr/bin/env python3
"""把 init-all.sh 的执行顺序合并成一个 wetuangou.sql。

关键处理：
 1. 6 个文件各自 DELIMITER 定义「幂等加列/加索引」助手过程 → 统一成开头一次定义，
    文件里其余 DELIMITER 段全部剥掉（Navicat 不支持 DELIMITER）。
 2. 各文件末尾的 drop procedure 一并剥掉，改成整个脚本最后统一 drop。
 3. USE xxx 一律剔除（库名由连接决定）。
"""
import re, os, sys

ROOT = '/Users/mac/dev/dytuangou'
os.chdir(ROOT)

BUSINESS = """
biz_tables
biz_tenant_tables
biz_tenant_upgrade
biz_product_model_v2
biz_product_model_v2_safe
biz_merchant_v2
biz_product_columns_v3
biz_product_ext
biz_product_stores
biz_stored_card_v3
biz_combo_subitem_v2
biz_role_extension
biz_agent_v25
biz_agent_store_quota_hotfix
biz_agent_role_permissions
biz_member_agent_identity
biz_distributor_invite
biz_booking_upgrade
biz_booking_slot_config
biz_booking_staff_review
biz_merchant_service_hours_upgrade
biz_store_service
migration-2026-08-14-f1-category-store-id
biz_menu_reorganization
biz_menu_business_pages
biz_menu_flatten
biz_tenant_menu
biz_mpconfig_menu
biz_wxconfig_menu
biz_wxconfig_init
biz_banner
biz_commission_settle_job
biz_commission_settle_link
biz_phone_decrypt
biz_order_verify_bill_confirm
biz_order_verifycode_fix
biz_agent_commission_c1
biz_booking_member_menu
v2_admin_menus
v3_p2_menus_routes
migration-2026-08-14-f2-mpauth-menu
biz_menu_business_pages
biz_product_dict_charset_fix
biz_product_industry_sync_safe
biz_product_seed
biz_product_field_gap_v4
biz_mpauth_menu_fix
biz_category_menu_rename
biz_product_detail_menu_fix_v5
biz_product_category_join_fix
biz_staff_usertype_hotfix
biz_collect_method_semantic_v6
biz_bill_auto_confirm_v7
biz_store_rating_booking_type_v8
biz_member_avatar_relative_v9
biz_store_booking_rule_v10
biz_merchant_appid_null_v11
biz_merchant_staff_perms_v12
biz_staff_tenant_backfill_v13
biz_staff_pc_role_backfill_v14
biz_merchant_promoter_enabled_20260903
""".split()

DEMO = """
biz_seed
biz_demo_data
biz_banner_home_seed
biz_product_subitem_seed
biz_fee_staffinvite_seed
biz_mpauth_settle_seed
""".split()

# 名字不同但语义相同的助手过程，全部映射到统一的 biz_add_column / biz_add_index
# 注意两种签名不同，不能混：
#   biz_add_column(表, 列, "列名 类型 ...")        ← 第3参含列名
#   add_column_if_missing(表, 列, "类型 ...")      ← 第3参不含列名
# 只归一签名相同的那个。
PROC_ALIASES = {
    'biz_add_col_tmp': 'biz_add_column',
}

def strip_delimiter_blocks(text):
    """剥掉所有 DELIMITER ... DELIMITER ; 段落（里面是助手过程定义）。"""
    # DELIMITER $$ / // 开始，到 DELIMITER ; 结束
    pattern = re.compile(
        r'^[ \t]*DELIMITER[ \t]+(\$\$|//|;;).*?^[ \t]*DELIMITER[ \t]*;[ \t]*$',
        re.IGNORECASE | re.DOTALL | re.MULTILINE)
    return pattern.sub('', text)

def resolve(name):
    """脚本按用途分了子目录：sql/（全新库初始化）、sql/upgrade/（存量库增量迁移）。
    这里按名字找文件，调用方不用关心它在哪个目录。"""
    for cand in (f'sql/{name}.sql', f'sql/upgrade/{name}.sql'):
        if os.path.exists(cand):
            return cand
    raise FileNotFoundError(f'找不到 {name}.sql（已查 sql/ 和 sql/upgrade/）')

def clean(name):
    path = resolve(name)
    s = open(path, encoding='utf-8').read()

    # 特例：industry_sync 的游标过程等价改写成一条 UPDATE
    if name == 'biz_product_industry_sync_safe':
        s = strip_delimiter_blocks(s)
        s = re.sub(r'^[ \t]*DROP PROCEDURE IF EXISTS sync_industry_code;[ \t]*$', '', s,
                   flags=re.IGNORECASE | re.MULTILINE)
        s = re.sub(r'^[ \t]*CALL sync_industry_code\(\);[ \t]*$',
                   '-- 原游标过程等价改写为一条 UPDATE（避免 DELIMITER，Navicat 友好）\n'
                   'UPDATE biz_product p\n'
                   'JOIN tmp_cat_industry m ON m.legacy_category_id = p.category_id\n'
                   'SET p.industry_code = m.industry_code\n'
                   "WHERE p.industry_code IS NULL OR p.industry_code = '';",
                   s, flags=re.IGNORECASE | re.MULTILINE)
        s = re.sub(r'^[ \t]*DROP PROCEDURE sync_industry_code;[ \t]*$', '', s,
                   flags=re.IGNORECASE | re.MULTILINE)
    else:
        s = strip_delimiter_blocks(s)

    # 剥掉各文件自己的 drop procedure（统一到脚本末尾）
    s = re.sub(r'^[ \t]*drop\s+procedure\s+(if\s+exists\s+)?'
               r'(biz_add_column|biz_add_index|biz_drop_index|add_column_if_missing|biz_add_col_tmp|n)\s*;[ \t]*$',
               '', s, flags=re.IGNORECASE | re.MULTILINE)

    # 过程名归一
    for old, new in PROC_ALIASES.items():
        s = re.sub(r'\b%s\b' % re.escape(old), new, s)

    # USE / SOURCE 指令剔除
    s = re.sub(r'^[ \t]*USE[ \t]+[`\w\-]+[ \t]*;[ \t]*$',
               '-- （已移除 USE 语句：库名由连接决定）', s,
               flags=re.IGNORECASE | re.MULTILINE)

    # 压掉连续空行
    s = re.sub(r'\n{4,}', '\n\n\n', s)
    return s.strip()

HELPERS = """
-- ============================================================
-- 助手过程（整个脚本只在这里定义一次）
--
-- 原本 6 个业务 SQL 各自用 DELIMITER 定义一份同名/近名的「幂等加列」过程，
-- 而 Navicat / 部分 GUI 客户端不支持 DELIMITER。这里统一定义一次，
-- 后续 80+ 处 CALL 共用，脚本末尾统一清理。
-- ============================================================
DROP PROCEDURE IF EXISTS biz_add_column;
DROP PROCEDURE IF EXISTS biz_add_index;
DROP PROCEDURE IF EXISTS biz_drop_index;
DROP PROCEDURE IF EXISTS add_column_if_missing;

DELIMITER $$

CREATE PROCEDURE biz_add_column(IN p_table VARCHAR(64), IN p_column VARCHAR(64), IN p_ddl VARCHAR(500))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = p_table AND column_name = p_column) THEN
    SET @sql = CONCAT('alter table `', p_table, '` add column ', p_ddl);
    PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
  END IF;
END $$

CREATE PROCEDURE biz_add_index(IN p_table VARCHAR(64), IN p_index VARCHAR(64), IN p_ddl VARCHAR(500))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.statistics
                 WHERE table_schema = DATABASE() AND table_name = p_table AND index_name = p_index) THEN
    SET @sql = CONCAT('alter table `', p_table, '` add ', p_ddl);
    PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
  END IF;
END $$

CREATE PROCEDURE biz_drop_index(IN p_table VARCHAR(64), IN p_index VARCHAR(64))
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.statistics
             WHERE table_schema = DATABASE() AND table_name = p_table AND index_name = p_index) THEN
    SET @sql = CONCAT('alter table `', p_table, '` drop index `', p_index, '`');
    PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
  END IF;
END $$

-- 与 biz_add_column 的区别：第 3 个参数**不含列名**（只有类型和属性）
CREATE PROCEDURE add_column_if_missing(IN p_table VARCHAR(64), IN p_column VARCHAR(64), IN p_definition VARCHAR(500))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = p_table AND column_name = p_column) THEN
    SET @sql = CONCAT('alter table `', p_table, '` add column `', p_column, '` ', p_definition);
    PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
  END IF;
END $$

DELIMITER ;
""".strip()

def build(out_path, names, title, note, with_helpers=True):
    parts = [f"""-- ============================================================
-- {title}
--
{note}
--
-- 生成方式：由 sql/deploy/build-merged.py 从 sql/*.sql 按实测顺序合并
--            （不要手改本文件，改源脚本后重新生成）
-- 生成时间：2026-08-22
-- ============================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

{HELPERS if with_helpers else '-- （本文件不含助手过程，全文无 DELIMITER）'}
"""]
    for n in names:
        body = clean(n)
        parts.append(f"""
-- ############################################################
-- 源文件：sql/{n}.sql
-- ############################################################

{body}
""")
    cleanup = ("""
-- ============================================================
-- 清理助手过程
-- ============================================================
DROP PROCEDURE IF EXISTS biz_add_column;
DROP PROCEDURE IF EXISTS biz_add_index;
DROP PROCEDURE IF EXISTS biz_drop_index;
DROP PROCEDURE IF EXISTS add_column_if_missing;
""" if with_helpers else '')
    parts.append(cleanup + """
SET FOREIGN_KEY_CHECKS = 1;

SELECT '导入完成' AS msg,
       (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE()) AS tables,
       (SELECT COUNT(*) FROM sys_menu) AS menus,
       (SELECT COUNT(*) FROM sys_menu WHERE parent_id IS NULL) AS bad_parent_should_be_0;
""")
    open(out_path, 'w', encoding='utf-8').write('\n'.join(parts))
    print(f'{out_path}: {len(open(out_path,encoding="utf-8").read().splitlines())} 行')

build('sql/deploy/wetuangou.sql', BUSINESS,
      'Wetangou 业务库初始化（合并版）',
      """-- 用法（在 ry_20260417.sql + quartz.sql 之后执行）：
--   mysql --default-character-set=utf8mb4 -uroot -p 库名 < sql/deploy/wetuangou.sql
--   或 Navicat：右键库 → 运行 SQL 文件 → 选本文件（编码选 utf8mb4）
--
-- 幂等：可重复执行
-- 内容：业务建表 + v2 商品模型 + 代理商/会员/预约 + 261 个菜单 + 字典种子""")

build('sql/deploy/wetuangou-demo.sql', DEMO,
      'Wetangou 演示数据（可选，生产不要执行）',
      """-- 用法（在 wetuangou.sql 之后，仅演示/测试环境）：
--   mysql --default-character-set=utf8mb4 -uroot -p 库名 < sql/deploy/wetuangou-demo.sql
--
-- 内容：示例商户/门店/商品/会员/订单/轮播图等演示数据""", with_helpers=False)
