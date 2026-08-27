-- ============================================
-- biz_merchant_v2.sql 简化版（无 PREPARE）
-- 兼容所有 MySQL 客户端
-- 适用：sys_user 当前无 openid/openid_bound 列的场景
-- ============================================

-- 1) sys_user 加 openid（idempotent：已存在则跳过）
-- 改用 DEFAULT NULL：MySQL UNIQUE 允许多个 NULL

-- 1.1 加 openid 列
SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sys_user' AND COLUMN_NAME = 'openid') = 0,
  'ALTER TABLE sys_user ADD COLUMN openid varchar(64) DEFAULT NULL COMMENT "微信 openid（绑定后唯一）" AFTER avatar',
  'SELECT "openid 列已存在，跳过" AS msg'
) INTO @sql;
-- 如果是 ALTER 语句才执行
SET @sql = IF(@sql LIKE 'ALTER%', @sql, 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 1.2 加 openid_bound 列
SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sys_user' AND COLUMN_NAME = 'openid_bound') = 0,
  'ALTER TABLE sys_user ADD COLUMN openid_bound tinyint(1) DEFAULT 0 COMMENT "openid 绑定状态" AFTER openid',
  'SELECT "openid_bound 已存在" AS msg'
) INTO @sql;
SET @sql = IF(@sql LIKE 'ALTER%', @sql, 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 1.3 修默认值为 NULL（已存在 openid 但默认是 '' 的情况）
SELECT IF(
  (SELECT COLUMN_DEFAULT FROM INFORMATION_SCHEMA.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sys_user' AND COLUMN_NAME = 'openid') IS NULL,
  'SELECT "openid 默认值已 NULL，跳过" AS msg',
  'ALTER TABLE sys_user MODIFY COLUMN openid varchar(64) DEFAULT NULL COMMENT "微信 openid"'
) INTO @sql;
SET @sql = IF(@sql LIKE 'ALTER%', @sql, 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 1.4 加 UNIQUE KEY
SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sys_user' AND INDEX_NAME = 'uk_sys_user_openid') = 0,
  'ALTER TABLE sys_user ADD UNIQUE KEY uk_sys_user_openid (openid)',
  'SELECT "索引已存在" AS msg'
) INTO @sql;
SET @sql = IF(@sql LIKE 'ALTER%', @sql, 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
