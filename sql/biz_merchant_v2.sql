-- =====================================================================
-- 商家端 v2 迁移脚本
-- 1) sys_user 加 openid 列（员工/会员登录复用）
-- 2) biz_merchant_staff 表（替代 biz_store_user，保留旧表 + 视图）
-- 3) biz_merchant_staff_invite 邀请码表
-- =====================================================================

-- 1) sys_user 加 openid（idempotent：已存在则跳过）
-- 改用 DEFAULT NULL 而非 ''：MySQL UNIQUE KEY 允许多个 NULL，但不允许多个空字符串
-- 业务代码 selectUserByOpenId 已兼容 NULL（if (openid == null || openid.isEmpty()) return null;）

-- 1.1 加 openid 列（若已存在则跳过）
SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_SCHEMA = DATABASE()
                      AND TABLE_NAME = 'sys_user'
                      AND COLUMN_NAME = 'openid');
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE sys_user ADD COLUMN openid varchar(64) DEFAULT NULL COMMENT ''微信 openid（绑定后唯一）'' AFTER avatar',
  'SELECT ''openid 列已存在，跳过'' AS msg');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 1.2 加 openid_bound 列（若已存在则跳过）
SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_SCHEMA = DATABASE()
                      AND TABLE_NAME = 'sys_user'
                      AND COLUMN_NAME = 'openid_bound');
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE sys_user ADD COLUMN openid_bound tinyint(1) DEFAULT 0 COMMENT ''openid 绑定状态 0未绑 1已绑'' AFTER openid',
  'SELECT ''openid_bound 列已存在，跳过'' AS msg');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 1.3 修已有 openid 列的默认值为 NULL（若已是 NULL 跳过）
SET @col_default := (SELECT COLUMN_DEFAULT FROM INFORMATION_SCHEMA.COLUMNS
                     WHERE TABLE_SCHEMA = DATABASE()
                       AND TABLE_NAME = 'sys_user'
                       AND COLUMN_NAME = 'openid');
SET @sql := IF(@col_default IS NULL OR @col_default != 'NULL',
  'ALTER TABLE sys_user MODIFY COLUMN openid varchar(64) DEFAULT NULL COMMENT ''微信 openid（绑定后唯一）''',
  'SELECT ''openid 默认值已是 NULL，跳过'' AS msg');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 1.4 加 UNIQUE KEY uk_sys_user_openid（若已存在则跳过）
SET @idx_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
                    WHERE TABLE_SCHEMA = DATABASE()
                      AND TABLE_NAME = 'sys_user'
                      AND INDEX_NAME = 'uk_sys_user_openid');
SET @sql := IF(@idx_exists = 0,
  'ALTER TABLE sys_user ADD UNIQUE KEY uk_sys_user_openid (openid)',
  'SELECT ''uk_sys_user_openid 索引已存在，跳过'' AS msg');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 2) 新建 biz_merchant_staff 表（商家员工关联）
-- 2) 新建 biz_merchant_staff 表（商家员工关联）
DROP TABLE IF EXISTS biz_merchant_staff;
CREATE TABLE biz_merchant_staff (
  id            bigint(20)    NOT NULL AUTO_INCREMENT          COMMENT '主键',
  merchant_id   bigint(20)    NOT NULL                          COMMENT '商户ID',
  store_id      bigint(20)    NOT NULL                          COMMENT '门店ID',
  user_id       bigint(20)    NOT NULL                          COMMENT '员工 sys_user_id',
  role          varchar(20)   DEFAULT 'STAFF'                   COMMENT '角色 STAFF/MANAGER/OWNER',
  staff_no      varchar(32)   DEFAULT ''                        COMMENT '员工编号（人工补录）',
  real_name     varchar(32)   DEFAULT ''                        COMMENT '员工姓名（人工补录）',
  phone         varchar(20)   DEFAULT ''                        COMMENT '员工手机号（人工补录）',
  hired_at      datetime      DEFAULT NULL                      COMMENT '入职时间',
  status        char(1)       DEFAULT '0'                       COMMENT '0在职 1离职',
  create_by     varchar(64)   DEFAULT '',
  create_time   datetime,
  update_by     varchar(64)   DEFAULT '',
  update_time   datetime,
  PRIMARY KEY (id),
  UNIQUE KEY uk_merchant_staff (merchant_id, store_id, user_id),
  KEY idx_merchant_staff_user (user_id),
  KEY idx_merchant_staff_store (store_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT = '商家员工表';

-- 3) 视图：旧 biz_store_user 仍能查询（兼容期）
DROP VIEW IF EXISTS biz_store_user_v;
CREATE VIEW biz_store_user_v AS
  SELECT id, merchant_id, store_id, user_id, status, create_time
  FROM biz_merchant_staff;

-- 4) 数据迁移：把现有 biz_store_user 数据同步到 biz_merchant_staff
INSERT INTO biz_merchant_staff (merchant_id, store_id, user_id, role, status, create_time)
SELECT IFNULL(merchant_id, 0), store_id, user_id, 'STAFF', create_time
FROM biz_store_user
ON DUPLICATE KEY UPDATE update_time = NOW();

-- 5) biz_merchant_staff_invite 邀请码表
DROP TABLE IF EXISTS biz_merchant_staff_invite;
CREATE TABLE biz_merchant_staff_invite (
  invite_id     bigint(20)    NOT NULL AUTO_INCREMENT          COMMENT '主键',
  invite_code   varchar(8)    NOT NULL                          COMMENT '邀请短码（6-8位）',
  scene         varchar(128)  NOT NULL                          COMMENT '微信小程序码 scene（invite:MID:SID:CODE）',
  wxacode_url   varchar(500)  DEFAULT ''                        COMMENT '已生成的微信小程序码 base64',
  merchant_id   bigint(20)    NOT NULL,
  store_id      bigint(20)    NOT NULL,
  role          varchar(20)   DEFAULT 'STAFF'                   COMMENT 'STAFF/MANAGER',
  expire_at     datetime      NOT NULL,
  used_at       datetime      DEFAULT NULL,
  used_by       bigint(20)    DEFAULT NULL                      COMMENT '使用的 sys_user_id',
  status        char(1)       DEFAULT '0'                       COMMENT '0有效 1已用 2过期 3作废',
  remark        varchar(255)  DEFAULT '',
  create_by     varchar(64)   DEFAULT '',
  create_time   datetime,
  PRIMARY KEY (invite_id),
  UNIQUE KEY uk_invite_code (invite_code),
  KEY idx_invite_merchant (merchant_id, store_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT = '商家员工邀请码表';

-- 6) 索引：提升查询效率
SET @idx := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_merchant_staff' AND INDEX_NAME = 'idx_staff_merchant');
SET @sql := IF(@idx = 0, 'ALTER TABLE biz_merchant_staff ADD INDEX idx_staff_merchant (merchant_id)', 'SELECT "idx_staff_merchant exists" AS msg');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
SET @idx := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_merchant_staff_invite' AND INDEX_NAME = 'idx_invite_status');
SET @sql := IF(@idx = 0, 'ALTER TABLE biz_merchant_staff_invite ADD INDEX idx_invite_status (status, expire_at)', 'SELECT "idx_invite_status exists" AS msg');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ============================================================
-- 商家员工/邀请码 admin 菜单（idempotent）
-- 路径：团购运营 / 门店商品 / 员工管理
-- 组件：biz/staffInvite/index
-- ============================================================

-- 1) 员工管理菜单（若已存在则忽略）
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '员工管理',
       (SELECT menu_id FROM sys_menu WHERE menu_name = '门店商品' AND parent_id = (SELECT menu_id FROM sys_menu WHERE menu_name = '团购运营' AND parent_id = 0) LIMIT 1 LIMIT 1),
       6, 'staffInvite', 'biz/staffInvite/index', 1, 0, 'C', '0', '0', 'biz:staffInvite:list', 'peoples', 'admin', SYSDATE(), '商家员工邀请码 + 员工名单管理'
FROM (SELECT 1) t
WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE component = 'biz/staffInvite/index' LIMIT 1);

-- 2) 按钮权限（list / add / edit / remove / query / export）
--    按 ruoyi 习惯直接用 menu_id 拼 perms，这里用存储过程式逐行插入
SET @m_staff = (SELECT menu_id FROM sys_menu WHERE component = 'biz/staffInvite/index' LIMIT 1 LIMIT 1);

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '员工查询', @m_staff, 1, '', '', 1, 0, 'F', '0', '0', 'biz:staffInvite:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m_staff IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:staffInvite:query' LIMIT 1);

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '生成邀请码', @m_staff, 2, '', '', 1, 0, 'F', '0', '0', 'biz:staffInvite:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m_staff IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:staffInvite:add' LIMIT 1);

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '修改员工', @m_staff, 3, '', '', 1, 0, 'F', '0', '0', 'biz:staffInvite:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m_staff IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:staffInvite:edit' LIMIT 1);

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '删除员工', @m_staff, 4, '', '', 1, 0, 'F', '0', '0', 'biz:staffInvite:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m_staff IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:staffInvite:remove' LIMIT 1);

-- 3) 把菜单 + 按钮权限授予 admin 角色（其它角色按需自行分配）
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu
WHERE component = 'biz/staffInvite/index' OR perms IN ('biz:staffInvite:query','biz:staffInvite:add','biz:staffInvite:edit','biz:staffInvite:remove');
