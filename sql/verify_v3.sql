-- 验证 v3 商品模型 SQL 是否已执行
-- 期望结果：每条 SELECT 都返回 1 行（不为空）

-- 1. v2 字段
SELECT 'type_code' AS col, COUNT(*) AS cnt FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_product' AND COLUMN_NAME = 'type_code';
SELECT 'face_value' AS col, COUNT(*) AS cnt FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_product' AND COLUMN_NAME = 'face_value';
SELECT 'total_times' AS col, COUNT(*) AS cnt FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_product' AND COLUMN_NAME = 'total_times';
SELECT 'period_type' AS col, COUNT(*) AS cnt FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_product' AND COLUMN_NAME = 'period_type';
SELECT 'subitem_pick_rule' AS col, COUNT(*) AS cnt FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_product' AND COLUMN_NAME = 'subitem_pick_rule';

-- 2. v2 表（子品）
SELECT 'biz_product_subitem_group' AS tbl, COUNT(*) AS cnt FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_product_subitem_group';
SELECT 'biz_product_subitem' AS tbl, COUNT(*) AS cnt FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_product_subitem';

-- 3. v2 商家字段
SELECT 'sys_user.openid' AS col, COUNT(*) AS cnt FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sys_user' AND COLUMN_NAME = 'openid';
SELECT 'biz_merchant_staff' AS tbl, COUNT(*) AS cnt FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_merchant_staff';
SELECT 'biz_merchant_staff_invite' AS tbl, COUNT(*) AS cnt FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_merchant_staff_invite';

-- 4. 期望输出：所有 cnt 都是 1
