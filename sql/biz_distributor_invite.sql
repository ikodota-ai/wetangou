-- 推客粉丝邀请机制：biz_member 增加 invite_by
-- 邀请通过 wxacode.getUnlimited 的 scene 携带，登录时回写。
-- scene 格式：distributor:{merchantId}:{memberId}

-- 幂等：仅在字段不存在时新增
SET @sql_add_invite_by = (
  SELECT IF(
    EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_member' AND COLUMN_NAME = 'invite_by'),
    'SELECT 1',
    'ALTER TABLE biz_member ADD COLUMN invite_by bigint(20) DEFAULT NULL COMMENT ''邀请人 member_id'' AFTER last_login_time'
  )
);
PREPARE stmt FROM @sql_add_invite_by; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql_add_invite_time = (
  SELECT IF(
    EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_member' AND COLUMN_NAME = 'invite_time'),
    'SELECT 1',
    'ALTER TABLE biz_member ADD COLUMN invite_time datetime DEFAULT NULL COMMENT ''邀请绑定时间'' AFTER invite_by'
  )
);
PREPARE stmt FROM @sql_add_invite_time; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 索引：粉丝列表按 invite_by 查询
SET @sql_add_idx = (
  SELECT IF(
    EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_member' AND INDEX_NAME = 'idx_invite_by'),
    'SELECT 1',
    'ALTER TABLE biz_member ADD INDEX idx_invite_by (invite_by)'
  )
);
PREPARE stmt FROM @sql_add_idx; EXECUTE stmt; DEALLOCATE PREPARE stmt;
