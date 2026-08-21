-- F1 修复 biz_product_category 表缺 store_id 列
-- 现象: CategoryController.getInfo 报 SQL 错 (Unknown column 'c.store_id' in 'field list')
-- 根因: v2 升级 (8-14) 表结构变更后, XML/Domain 引用 store_id 但 schema 未加列
-- 修法: ALTER TABLE biz_product_category ADD COLUMN store_id BIGINT(20) DEFAULT NULL
--       DEFAULT NULL 保证现有数据不受影响 (NULL=平台级/全门店)
-- 验证: E16 smoke Category 段 6/6 PASS (agent 别人 500 / 自己 200 / admin 200)
-- 注（2026-08-21）：原本这里是 `USE ry-vue;`。
-- `use` 是 mysql 客户端指令，会无视命令行上指定的库直接切到 ry-vue，
-- 导致「对着测试库执行、却写进生产库」。库名请在命令行给：
--   mysql --default-character-set=utf8mb4 -uroot -p <目标库> < 本文件
-- USE ry-vue;
-- 幂等：新版建表脚本已含 store_id，存量库才需要 ALTER
SET @sql := (
  SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_schema = DATABASE() AND table_name = 'biz_product_category' AND column_name = 'store_id'),
    'SELECT ''biz_product_category.store_id already exists'' AS msg',
    'ALTER TABLE biz_product_category ADD COLUMN store_id BIGINT(20) DEFAULT NULL COMMENT ''门店ID（NULL=平台级/全门店）'''
  )
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
