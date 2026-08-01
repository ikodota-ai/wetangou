-- =============================================
-- 修复：biz_order.verify_code 默认空串与唯一索引冲突
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_order_verifycode_fix.sql
-- 现象：核销码在支付成功后才生成，未支付订单该列为 ''，
--       而 uk_verify_code 是唯一索引，导致同商户第二笔未支付订单必然
--       报 Duplicate entry '' for key 'uk_verify_code' 而无法下单。
-- 方案：列改为可空且默认 NULL（MySQL 唯一索引允许多个 NULL），并把存量空串刷成 NULL。
-- 幂等：可重复执行。
-- =============================================

UPDATE biz_order SET verify_code = NULL WHERE verify_code = '';

ALTER TABLE biz_order
  MODIFY COLUMN verify_code VARCHAR(32) DEFAULT NULL COMMENT '核销码（支付后生成，未支付为NULL以避开唯一索引）';

-- 验证：应为 0 行空串
SELECT COUNT(*) AS 空串核销码 FROM biz_order WHERE verify_code = '';
