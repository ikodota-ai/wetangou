-- ============================================
-- biz_product_model_v2.sql 安全版（无 PREPARE）
-- 26 段 v2 字段 IF 检测 + 只在缺失时 ADD
-- 适用任何 MySQL 客户端 / 重复跑安全
-- ============================================

-- 0) 创建通用"加列助手"存储过程（永久，反复可用）
DROP PROCEDURE IF EXISTS add_column_if_missing;
DELIMITER //
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
END //
DELIMITER ;

-- 1) sys_user 加 v2 字段（缺失才加）
CALL add_column_if_missing('sys_user', 'user_type', "varchar(20) DEFAULT '00' COMMENT '00系统 10代理 20商户 30会员 40员工' AFTER avatar");
CALL add_column_if_missing('sys_user', 'merchant_id', "bigint(20) DEFAULT 0 COMMENT '所属商户ID' AFTER user_type");

-- 2) biz_product 加 26 个 v2 字段
CALL add_column_if_missing('biz_product', 'type_code', "varchar(30) DEFAULT 'GROUPON' COMMENT '类型代码' AFTER product_type");
CALL add_column_if_missing('biz_product', 'industry_code', "varchar(50) DEFAULT '' COMMENT '行业编码' AFTER type_code");
CALL add_column_if_missing('biz_product', 'face_value', "decimal(10,2) DEFAULT 0.00 COMMENT '面值/划线价' AFTER market_price");
CALL add_column_if_missing('biz_product', 'min_consume', "decimal(10,2) DEFAULT 0.00 COMMENT '最低消费门槛' AFTER face_value");
CALL add_column_if_missing('biz_product', 'total_times', "int(11) DEFAULT 0 COMMENT '总次数（次卡）' AFTER min_consume");
CALL add_column_if_missing('biz_product', 'period_type', "varchar(20) DEFAULT '' COMMENT '周期类型' AFTER total_times");
CALL add_column_if_missing('biz_product', 'period_count', "int(11) DEFAULT 0 COMMENT '周期数' AFTER period_type");
CALL add_column_if_missing('biz_product', 'sale_start_date', "datetime DEFAULT NULL COMMENT '售卖开始' AFTER period_count");
CALL add_column_if_missing('biz_product', 'sale_end_date', "datetime DEFAULT NULL COMMENT '售卖结束' AFTER sale_start_date");
CALL add_column_if_missing('biz_product', 'consume_start_days', "int(4) DEFAULT 1 COMMENT '可消费起始天数' AFTER sale_end_date");
CALL add_column_if_missing('biz_product', 'consume_valid_days', "int(4) DEFAULT 360 COMMENT '可消费有效天数' AFTER consume_start_days");
CALL add_column_if_missing('biz_product', 'consume_start_today', "tinyint(1) DEFAULT 1 COMMENT '购买当天是否可用' AFTER consume_valid_days");
CALL add_column_if_missing('biz_product', 'limit_per_user', "int(11) DEFAULT 0 COMMENT '每人限购' AFTER consume_start_today");
CALL add_column_if_missing('biz_product', 'max_per_order', "int(11) DEFAULT 1 COMMENT '单次最多使用张数' AFTER limit_per_user");
CALL add_column_if_missing('biz_product', 'max_persons', "int(11) DEFAULT 0 COMMENT '每张最多使用人数' AFTER max_per_order");
CALL add_column_if_missing('biz_product', 'refund_policy', "varchar(500) DEFAULT '' COMMENT '售后政策' AFTER max_persons");
CALL add_column_if_missing('biz_product', 'booking_required', "tinyint(1) DEFAULT 0 COMMENT '需要预约' AFTER refund_policy");
CALL add_column_if_missing('biz_product', 'booking_workday_only', "tinyint(1) DEFAULT 0 COMMENT '预约仅工作日' AFTER booking_required");
CALL add_column_if_missing('biz_product', 'collect_method', "varchar(20) DEFAULT 'HEAD' COMMENT '收款方式 HEAD总部统一收款/STORE门店独立收款' AFTER booking_workday_only");
CALL add_column_if_missing('biz_product', 'mutex_with_store_promotion', "tinyint(1) DEFAULT 1 COMMENT '与店内优惠互斥' AFTER collect_method");
CALL add_column_if_missing('biz_product', 'extra_fee_desc', "varchar(500) DEFAULT '' COMMENT '额外费用说明' AFTER mutex_with_store_promotion");
CALL add_column_if_missing('biz_product', 'other_notice', "varchar(2000) DEFAULT '' COMMENT '其他说明' AFTER extra_fee_desc");
CALL add_column_if_missing('biz_product', 'commission_rate', "decimal(5,2) DEFAULT 0.00 COMMENT '推客佣金比例' AFTER other_notice");
CALL add_column_if_missing('biz_product', 'total_value', "decimal(10,2) DEFAULT 0.00 COMMENT '组合券包总价值' AFTER commission_rate");
CALL add_column_if_missing('biz_product', 'subitem_pick_rule', "varchar(50) DEFAULT 'ALL' COMMENT '子品选择规则' AFTER total_value");
CALL add_column_if_missing('biz_product', 'require_xiaoxin', "tinyint(1) DEFAULT 0 COMMENT '需要冷静期' AFTER subitem_pick_rule");

-- 3) biz_product_store 加 2 字段
CALL add_column_if_missing('biz_product_store', 'subitem_pick_rule', "varchar(50) DEFAULT 'ALL' COMMENT '子品选择规则' AFTER on_sale");
CALL add_column_if_missing('biz_product_store', 'require_xiaoxin', "tinyint(1) DEFAULT 0 COMMENT '需要冷静期' AFTER subitem_pick_rule");

-- 4) 验证：列出现有 v2 字段
SELECT TABLE_NAME, COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND (
    (TABLE_NAME = 'biz_product' AND COLUMN_NAME IN (
      'type_code','industry_code','face_value','min_consume','total_times',
      'period_type','period_count','sale_start_date','sale_end_date',
      'consume_start_days','consume_valid_days','consume_start_today',
      'limit_per_user','max_per_order','max_persons','refund_policy',
      'booking_required','booking_workday_only','collect_method',
      'mutex_with_store_promotion','extra_fee_desc','other_notice',
      'commission_rate','total_value','subitem_pick_rule','require_xiaoxin'
    ))
    OR (TABLE_NAME = 'biz_product_store' AND COLUMN_NAME IN ('subitem_pick_rule','require_xiaoxin'))
    OR (TABLE_NAME = 'sys_user' AND COLUMN_NAME IN ('user_type','merchant_id','openid','openid_bound'))
  )
ORDER BY TABLE_NAME, COLUMN_NAME;
