-- ============================================
-- 第 1 步：sys_user 加 openid/openid_bound + 唯一索引
-- 无 PREPARE 无动态 SQL，任何 MySQL 客户端都能跑
-- 适用场景：sys_user 还没 openid 列（你当前场景）
-- ============================================

-- 加 openid 列（DEFAULT NULL，MySQL UNIQUE 允许多个 NULL）
ALTER TABLE sys_user
  ADD COLUMN openid varchar(64) DEFAULT NULL COMMENT '微信 openid（绑定后唯一）' AFTER avatar;

-- 加 openid_bound 列
ALTER TABLE sys_user
  ADD COLUMN openid_bound tinyint(1) DEFAULT 0 COMMENT 'openid 绑定状态 0未绑 1已绑' AFTER openid;

-- 加唯一索引（允许多个 NULL）
ALTER TABLE sys_user
  ADD UNIQUE KEY uk_sys_user_openid (openid);

-- 验证
SELECT
  COLUMN_NAME, COLUMN_DEFAULT, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'sys_user'
  AND COLUMN_NAME IN ('openid', 'openid_bound');

SELECT INDEX_NAME, COLUMN_NAME, NON_UNIQUE
FROM INFORMATION_SCHEMA.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'sys_user'
  AND INDEX_NAME = 'uk_sys_user_openid';
