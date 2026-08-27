-- ============================================
-- 第 2 步 a：建 add_column_if_missing 存储过程
-- 注意：DELIMITER 在 Navicat 不可用，需在 mysql CLI 跑
-- 或用 Navicat 的"运行存储过程"功能
-- ============================================

DROP PROCEDURE IF EXISTS add_column_if_missing;
CREATE PROCEDURE add_column_if_missing(
  IN p_table VARCHAR(64),
  IN p_column VARCHAR(64),
  IN p_definition VARCHAR(500)
)
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = p_table
      AND COLUMN_NAME = p_column
  ) THEN
    SET @sql = CONCAT('ALTER TABLE ', p_table, ' ADD COLUMN ', p_column, ' ', p_definition);
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SELECT CONCAT('ADD ', p_table, '.', p_column) AS applied;
  ELSE
    SELECT CONCAT('SKIP ', p_table, '.', p_column, ' (exists)') AS applied;
  END IF;
END;
