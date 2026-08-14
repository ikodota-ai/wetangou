-- ============================================================
-- 洞天团购 v2 升级一致性诊断脚本
-- 用途: 一键诊断 v2 升级是否完整落地
-- 作者: dytuangou / audit by codex 2026-08-14
-- 执行: 在 Navicat 里选 ry-vue 库 -> Query -> New Query -> Run
-- 输出: 每条 SQL 都有 step 标签, 13 轮静态审计 130+ 事实交叉验证
-- ============================================================

-- ============== §1. biz_product_type 字典 ==============

-- §1.1 表是否存在 + 11 条种子完整性
SELECT "§1.1 biz_product_type 表行数" AS step, COUNT(*) AS rows FROM biz_product_type;
SELECT "§1.2 11 条种子全在" AS step,
       GROUP_CONCAT(type_code ORDER BY sort) AS codes
  FROM biz_product_type
  WHERE type_code IN ("GROUPON","VOUCHER","TIMECARD","STORED_CARD","PERIOD_CARD","HUIXIANG_CARD","PRESALE","PICKUP_VOUCHER","COMBO","BILL","BOOKING");

-- §1.3 是否有人改过 type_name
SELECT "§1.3 改过 type_name 的行" AS step, type_code, type_name
  FROM biz_product_type
  WHERE type_name NOT IN ("团购套餐","代金券","次卡","储值卡","周期卡","惠享卡","预售券","提货券","组合券包","到店买单","预约服务");

-- §1.4 field_config JSON 是否被填充
SELECT "§1.4 field_config 填充情况" AS step,
       SUM(IF(field_config IS NULL OR field_config="", 0, 1)) AS filled,
       SUM(IF(field_config IS NULL OR field_config="", 1, 0)) AS empty
  FROM biz_product_type;


-- ============== §2. biz_product_category 行业品类 ==============

SELECT "§2.1 一级行业 (level=1)" AS step, COUNT(*) AS n
  FROM biz_product_category WHERE level=1 AND merchant_id=0;

SELECT "§2.2 二级品类 (level=2)" AS step, COUNT(*) AS n
  FROM biz_product_category WHERE level=2 AND merchant_id=0;

SELECT "§2.3 8 大行业编码" AS step,
       GROUP_CONCAT(DISTINCT industry_code ORDER BY industry_code) AS industries
  FROM biz_product_category WHERE level=1 AND merchant_id=0;

SELECT "§2.4 行业保证金分布" AS step, industry_code, MAX(deposit_amount) AS max_deposit
  FROM biz_product_category WHERE level=1 AND merchant_id=0
  GROUP BY industry_code ORDER BY max_deposit DESC;

SELECT "§2.5 allowed_types 覆盖度" AS step,
       SUM(IF(allowed_types IS NULL OR allowed_types="", 0, 1)) AS filled,
       SUM(IF(allowed_types IS NULL OR allowed_types="", 1, 0)) AS empty
  FROM biz_product_category WHERE merchant_id=0;


-- ============== §3. sys_menu 菜单与权限 ==============

SELECT "§3.1 商品类型菜单 (组件 biz/productType/index)" AS step, menu_id, menu_name, perms
  FROM sys_menu WHERE component="biz/productType/index";

SELECT "§3.2 biz:productType:* 权限注册" AS step, GROUP_CONCAT(perms) AS perms
  FROM sys_menu WHERE perms LIKE "biz:productType:%";

SELECT "§3.3 商品管理菜单" AS step, menu_id, menu_name, perms
  FROM sys_menu WHERE component="biz/product/index";

SELECT "§3.4 商品分类菜单" AS step, menu_id, menu_name, perms
  FROM sys_menu WHERE component="biz/category/index";

SELECT "§3.5 biz:category:* 权限注册" AS step, GROUP_CONCAT(perms ORDER BY perms) AS perms
  FROM sys_menu WHERE perms LIKE "biz:category:%";

SELECT "§3.6 商品分类菜单角色绑定" AS step, GROUP_CONCAT(DISTINCT r.role_key) AS roles
  FROM sys_role r
  JOIN sys_role_menu rm ON r.role_id = rm.role_id
  JOIN sys_menu m ON rm.menu_id = m.menu_id
  WHERE m.component="biz/category/index";


-- ============== §4. sys_role 角色体系 ==============

SELECT "§4.1 3 角色注册" AS step, role_key, role_name, del_flag
  FROM sys_role WHERE role_key IN ("platform","agent","merchant");

SELECT "§4.2 角色菜单数" AS step, r.role_key, COUNT(rm.menu_id) AS menu_count
  FROM sys_role r
  LEFT JOIN sys_role_menu rm ON r.role_id = rm.role_id
  WHERE r.role_key IN ("platform","agent","merchant") AND r.del_flag="0"
  GROUP BY r.role_key;


-- ============== §5. biz_product 表 v2 增列落地 ==============

SELECT "§5.1 biz_product v2 增列" AS step,
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema="ry-vue" AND table_name="biz_product" AND column_name="type_code") AS type_code,
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema="ry-vue" AND table_name="biz_product" AND column_name="industry_code") AS industry_code,
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema="ry-vue" AND table_name="biz_product" AND column_name="face_value") AS face_value,
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema="ry-vue" AND table_name="biz_product" AND column_name="min_consume") AS min_consume,
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema="ry-vue" AND table_name="biz_product" AND column_name="total_times") AS total_times,
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema="ry-vue" AND table_name="biz_product" AND column_name="period_type") AS period_type,
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema="ry-vue" AND table_name="biz_product" AND column_name="sale_start_date") AS sale_start_date,
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema="ry-vue" AND table_name="biz_product" AND column_name="limit_per_user") AS limit_per_user,
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema="ry-vue" AND table_name="biz_product" AND column_name="require_xiaoxin") AS require_xiaoxin,
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema="ry-vue" AND table_name="biz_product" AND column_name="subitem_pick_rule") AS subitem_pick_rule,
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema="ry-vue" AND table_name="biz_product" AND column_name="commission_rate") AS commission_rate;

SELECT "§5.2 biz_product 数据行" AS step, COUNT(*) AS rows, COUNT(type_code) AS type_code_filled
  FROM biz_product;

SELECT "§5.3 type_code 分布" AS step, IFNULL(type_code,"NULL") AS type_code, COUNT(*) AS n
  FROM biz_product GROUP BY type_code ORDER BY n DESC;

SELECT "§5.4 老 product_type 分布" AS step, IFNULL(product_type,"NULL") AS product_type, COUNT(*) AS n
  FROM biz_product GROUP BY product_type ORDER BY n DESC;


-- ============== §6. biz_subitem 子品体系 ==============

SELECT "§6.1 biz_product_subitem_group" AS step, COUNT(*) AS rows FROM biz_product_subitem_group;
SELECT "§6.2 biz_product_subitem" AS step, COUNT(*) AS rows FROM biz_product_subitem;

SELECT "§6.3 有子品的商品 type_code 分布" AS step, p.type_code, COUNT(DISTINCT g.product_id) AS product_count
  FROM biz_product_subitem_group g
  JOIN biz_product p ON g.product_id = p.product_id
  GROUP BY p.type_code ORDER BY product_count DESC;


-- ============== §7. biz_banner banner 体系 ==============

SELECT "§7.1 biz_banner" AS step, COUNT(*) AS rows, COUNT(DISTINCT position) AS positions
  FROM biz_banner;

SELECT "§7.2 banner 位置分布" AS step, IFNULL(position,"NULL") AS position, COUNT(*) AS n
  FROM biz_banner GROUP BY position;


-- ============== §8. biz_booking 预约体系 ==============

SELECT "§8.1 biz_booking" AS step, COUNT(*) AS rows FROM biz_booking;
SELECT "§8.2 biz_booking_member" AS step, COUNT(*) AS rows FROM biz_booking_member;


-- ============== §9. sys_job 业务定时任务 ==============

SELECT "§9.1 sys_job 总数" AS step, COUNT(*) AS total, SUM(IF(status="0",1,0)) AS running
  FROM sys_job;

SELECT "§9.2 业务 job invoke_target 列表" AS step, job_name, invoke_target, cron_expression, status
  FROM sys_job ORDER BY job_id;


-- ============== §10. 一致性总结 ==============

SELECT "§10 v2 升级一致性总结" AS step,
       (SELECT COUNT(*) FROM biz_product_type) AS type_rows,
       (SELECT COUNT(*) FROM biz_product_category) AS cat_rows,
       (SELECT COUNT(*) FROM sys_menu WHERE component="biz/productType/index") AS type_menu,
       (SELECT COUNT(*) FROM sys_menu WHERE perms LIKE "biz:productType:%") AS type_perms,
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema="ry-vue" AND table_name="biz_product" AND column_name="type_code") AS product_type_code_col,
       (SELECT COUNT(*) FROM biz_product) AS product_rows,
       (SELECT COUNT(*) FROM biz_product WHERE type_code IS NOT NULL AND type_code <> "") AS product_with_type_code;
