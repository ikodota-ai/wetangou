-- ============================================================
-- 紧急热修：biz_agent 加 store_quota 字段
-- 场景：点"代理商/商户管理"报
--   Unknown column 'store_quota' in 'field list'
-- 原因：sql/biz_agent_store_quota.sql 没跑过
-- 修复：本脚本一条 ALTER + 索引即可
-- ============================================================

-- 1. 加字段（已存在则忽略）
SET @sql = (
  SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_schema=DATABASE() AND table_name='biz_agent' AND column_name='store_quota'),
    'SELECT 1',
    'ALTER TABLE biz_agent ADD COLUMN store_quota int(11) DEFAULT 0 COMMENT ''可开门店额度（0=不限）'' AFTER merchant_quota'
  )
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 2. 加索引（已存在则忽略）
SET @sql = (
  SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.statistics
           WHERE table_schema=DATABASE() AND table_name='biz_agent' AND index_name='idx_store_quota'),
    'SELECT 1',
    'CREATE INDEX idx_store_quota ON biz_agent (store_quota)'
  )
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 3. 默认代理商（平台直营）置 0=不限
UPDATE biz_agent SET store_quota = 0 WHERE store_quota IS NULL;

-- 4. 自检
SELECT agent_id, agent_name, store_quota FROM biz_agent WHERE del_flag = '0';
