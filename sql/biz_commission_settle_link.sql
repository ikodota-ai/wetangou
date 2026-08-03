-- 佣金冷静期结算后联动推客冻结/可用金额：biz_commission 加 settled_to_distributor 标记
-- 工作流程：
--   1) Quartz 每天 03:00 跑 SettleCommissionTask
--   2) Phase 1：UPDATE biz_commission SET status=1, settle_time=NOW(), settled_to_distributor=0
--      WHERE status=0 AND create_time + 7d <= NOW()  (commissionMapper.settleExpiredCommissions)
--   3) Phase 2：SELECT distributor_id, SUM(amount) FROM biz_commission
--      WHERE settle_time = ? AND settled_to_distributor=0 GROUP BY distributor_id
--   4) Phase 3：逐 distributor UPDATE frozen_amount -X, available_amount +X
--   5) Phase 4：UPDATE biz_commission SET settled_to_distributor=1 WHERE settle_time = ?

SET @sql_add = (
  SELECT IF(
    EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_commission' AND COLUMN_NAME = 'settled_to_distributor'),
    'SELECT 1',
    'ALTER TABLE biz_commission ADD COLUMN settled_to_distributor TINYINT(1) DEFAULT 0 COMMENT ''已联动推客金额（0否 1是）'' AFTER settle_time'
  )
);
PREPARE stmt FROM @sql_add; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql_idx = (
  SELECT IF(
    EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_commission' AND INDEX_NAME = 'idx_settle_link'),
    'SELECT 1',
    'CREATE INDEX idx_settle_link ON biz_commission (settle_time, settled_to_distributor)'
  )
);
PREPARE stmt FROM @sql_idx; EXECUTE stmt; DEALLOCATE PREPARE stmt;
