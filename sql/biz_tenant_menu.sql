-- =============================================
-- 多商户 + 代理商 菜单与角色初始化（幂等，可重复执行）
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_tenant_menu.sql
-- 内容：租户管理目录 + 代理商/商户/缴费/小程序发布菜单 + 平台/代理商/商户三类角色
-- 菜单ID由自增分配，不硬编码，避免与代码生成器冲突
-- =============================================

-- ----------------------------
-- 步骤0：定位「团购运营」一级目录（不存在则创建）
-- 注意：不能傅底到固定 ID，否则在缺少该目录的库上会撞上自增分配的菜单 ID
-- ----------------------------
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '团购运营', 0, 4, 'tuangou', '', '', '', 1, 0, 'M', '0', '0', '', 'shopping', 'admin', SYSDATE(), '洞天团购业务'
FROM (SELECT 1) t
WHERE NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE menu_name = '团购运营' AND parent_id = 0) x);

SET @biz_id = (SELECT menu_id FROM sys_menu WHERE menu_name = '团购运营' AND parent_id = 0 LIMIT 1);

-- ----------------------------
-- 步骤1：清理历史「租户管理」目录（重复执行时先复原层级再删除）
-- ----------------------------
UPDATE sys_menu c
  JOIN sys_menu p ON c.parent_id = p.menu_id
SET c.parent_id = @biz_id
WHERE p.parent_id = @biz_id AND p.menu_type = 'M' AND p.menu_name = '租户管理';

DELETE rm FROM sys_role_menu rm
  JOIN sys_menu m ON rm.menu_id = m.menu_id
WHERE m.parent_id = @biz_id AND m.menu_type = 'M' AND m.menu_name = '租户管理';

DELETE FROM sys_menu WHERE parent_id = @biz_id AND menu_type = 'M' AND menu_name = '租户管理';

-- 清理本脚本管理的业务菜单（按 component 定位，含其下按钮权限）
-- MySQL 不允许 DELETE 子查询直接引用目标表，先用临时表暂存菜单ID
DROP TEMPORARY TABLE IF EXISTS tmp_tenant_menu;
CREATE TEMPORARY TABLE tmp_tenant_menu (menu_id BIGINT(20) PRIMARY KEY);

INSERT INTO tmp_tenant_menu (menu_id)
SELECT menu_id FROM sys_menu WHERE component IN
  ('biz/agent/index', 'biz/merchant/index', 'biz/agentfee/index', 'biz/merchantfee/index', 'biz/mprelease/index');

-- 临时表在同一语句中不可重复打开，父子两级分两张临时表处理
DROP TEMPORARY TABLE IF EXISTS tmp_tenant_child;
CREATE TEMPORARY TABLE tmp_tenant_child (menu_id BIGINT(20) PRIMARY KEY);

INSERT IGNORE INTO tmp_tenant_child (menu_id)
SELECT m.menu_id FROM sys_menu m JOIN tmp_tenant_menu t ON m.parent_id = t.menu_id;

INSERT IGNORE INTO tmp_tenant_menu (menu_id)
SELECT menu_id FROM tmp_tenant_child;

DELETE rm FROM sys_role_menu rm JOIN tmp_tenant_menu t ON rm.menu_id = t.menu_id;
DELETE m FROM sys_menu m JOIN tmp_tenant_menu t ON m.menu_id = t.menu_id;

DROP TEMPORARY TABLE IF EXISTS tmp_tenant_child;
DROP TEMPORARY TABLE IF EXISTS tmp_tenant_menu;

-- ----------------------------
-- 步骤2：新增「租户管理」二级目录
-- ----------------------------
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('租户管理', @biz_id, 0, 'tenant', '', '', '', 1, 0, 'M', '0', '0', '', 'peoples', 'admin', SYSDATE(), '代理商、商户、缴费与小程序发布');
SET @dir_tenant = LAST_INSERT_ID();

-- ----------------------------
-- 步骤3：业务菜单（C）
-- ----------------------------
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('代理商管理', @dir_tenant, 1, 'agent', 'biz/agent/index', '', '', 1, 0, 'C', '0', '0', 'biz:agent:list', 'tree', 'admin', SYSDATE(), '平台管理代理商及商户额度');
SET @m_agent = LAST_INSERT_ID();

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('代理商缴费', @dir_tenant, 2, 'agentfee', 'biz/agentfee/index', '', '', 1, 0, 'C', '0', '0', 'biz:agentfee:list', 'money', 'admin', SYSDATE(), '代理商向平台缴费与额度充值');
SET @m_agentfee = LAST_INSERT_ID();

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('商户管理', @dir_tenant, 3, 'merchant', 'biz/merchant/index', '', '', 1, 0, 'C', '0', '0', 'biz:merchant:list', 'shopping', 'admin', SYSDATE(), '商户开通、小程序AppId与支付配置');
SET @m_merchant = LAST_INSERT_ID();

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('商户收费', @dir_tenant, 4, 'merchantfee', 'biz/merchantfee/index', '', '', 1, 0, 'C', '0', '0', 'biz:merchantfee:list', 'money', 'admin', SYSDATE(), '代理商向商户收费记录');
SET @m_merchantfee = LAST_INSERT_ID();

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('小程序发布', @dir_tenant, 5, 'mprelease', 'biz/mprelease/index', '', '', 1, 0, 'C', '0', '0', 'biz:mprelease:list', 'upload', 'admin', SYSDATE(), '小程序授权、代上传、提审与发布');
SET @m_release = LAST_INSERT_ID();

-- ----------------------------
-- 步骤4：按钮权限（F）
-- ----------------------------
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark) VALUES
('代理商查询', @m_agent, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:agent:query',  '#', 'admin', SYSDATE(), ''),
('代理商新增', @m_agent, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:agent:add',    '#', 'admin', SYSDATE(), ''),
('代理商修改', @m_agent, 3, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:agent:edit',   '#', 'admin', SYSDATE(), ''),
('代理商删除', @m_agent, 4, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:agent:remove', '#', 'admin', SYSDATE(), ''),
('代理商导出', @m_agent, 5, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:agent:export', '#', 'admin', SYSDATE(), '');

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark) VALUES
('缴费查询', @m_agentfee, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:agentfee:query',  '#', 'admin', SYSDATE(), ''),
('缴费登记', @m_agentfee, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:agentfee:add',    '#', 'admin', SYSDATE(), ''),
('缴费修改', @m_agentfee, 3, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:agentfee:edit',   '#', 'admin', SYSDATE(), ''),
('缴费审核', @m_agentfee, 4, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:agentfee:audit',  '#', 'admin', SYSDATE(), '确认到账并发放商户额度'),
('缴费删除', @m_agentfee, 5, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:agentfee:remove', '#', 'admin', SYSDATE(), '');

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark) VALUES
('商户查询',   @m_merchant, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:merchant:query',  '#', 'admin', SYSDATE(), ''),
('商户新增',   @m_merchant, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:merchant:add',    '#', 'admin', SYSDATE(), '代理商在额度内开通商户'),
('商户修改',   @m_merchant, 3, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:merchant:edit',   '#', 'admin', SYSDATE(), ''),
('商户删除',   @m_merchant, 4, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:merchant:remove', '#', 'admin', SYSDATE(), ''),
('商户导出',   @m_merchant, 5, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:merchant:export', '#', 'admin', SYSDATE(), ''),
('微信配置',   @m_merchant, 6, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:merchant:wxconfig', '#', 'admin', SYSDATE(), '维护商户小程序与支付凭证');

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark) VALUES
('收费查询', @m_merchantfee, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:merchantfee:query',  '#', 'admin', SYSDATE(), ''),
('收费登记', @m_merchantfee, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:merchantfee:add',    '#', 'admin', SYSDATE(), ''),
('收费修改', @m_merchantfee, 3, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:merchantfee:edit',   '#', 'admin', SYSDATE(), ''),
('收费删除', @m_merchantfee, 4, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:merchantfee:remove', '#', 'admin', SYSDATE(), '');

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark) VALUES
('发布记录查询', @m_release, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:mprelease:query',   '#', 'admin', SYSDATE(), ''),
('小程序授权',   @m_release, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:mprelease:auth',    '#', 'admin', SYSDATE(), '生成第三方平台授权链接'),
('代码上传',     @m_release, 3, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:mprelease:upload',  '#', 'admin', SYSDATE(), '按模板+ext.json代上传'),
('提交审核',     @m_release, 4, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:mprelease:audit',   '#', 'admin', SYSDATE(), ''),
('发布上线',     @m_release, 5, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:mprelease:release', '#', 'admin', SYSDATE(), ''),
('版本回退',     @m_release, 6, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:mprelease:rollback','#', 'admin', SYSDATE(), '');

-- ----------------------------
-- 步骤5：三类角色（平台管理员 / 代理商 / 商户管理员）
-- data_scope=1 全部数据，2 自定，4 本部门及以下
-- 业务数据隔离由 merchant_id 租户上下文强制过滤，部门数据权限只管账号与组织可见范围
-- ----------------------------
INSERT INTO sys_role (role_name, role_key, role_sort, data_scope, menu_check_strictly, dept_check_strictly, status, del_flag, create_by, create_time, remark)
SELECT '平台管理员', 'platform', 3, '1', 1, 1, '0', '0', 'admin', SYSDATE(), '平台侧：代理商与商户全局管理'
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM (SELECT role_id FROM sys_role WHERE role_key = 'platform') t);

INSERT INTO sys_role (role_name, role_key, role_sort, data_scope, menu_check_strictly, dept_check_strictly, status, del_flag, create_by, create_time, remark)
SELECT '代理商', 'agent', 4, '4', 1, 1, '0', '0', 'admin', SYSDATE(), '代理商侧：在额度内开通并管理自己的商户'
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM (SELECT role_id FROM sys_role WHERE role_key = 'agent') t);

INSERT INTO sys_role (role_name, role_key, role_sort, data_scope, menu_check_strictly, dept_check_strictly, status, del_flag, create_by, create_time, remark)
SELECT '商户管理员', 'merchant', 5, '4', 1, 1, '0', '0', 'admin', SYSDATE(), '商户侧：仅可见本商户门店与业务数据'
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM (SELECT role_id FROM sys_role WHERE role_key = 'merchant') t);

SET @role_platform = (SELECT role_id FROM sys_role WHERE role_key = 'platform' LIMIT 1);
SET @role_agent    = (SELECT role_id FROM sys_role WHERE role_key = 'agent'    LIMIT 1);
SET @role_merchant = (SELECT role_id FROM sys_role WHERE role_key = 'merchant' LIMIT 1);

-- ----------------------------
-- 步骤6：角色授权
-- ----------------------------
-- 6.1 超级管理员 + 平台管理员：租户管理全部菜单
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu WHERE menu_id = @dir_tenant OR parent_id = @dir_tenant
   OR parent_id IN (@m_agent, @m_agentfee, @m_merchant, @m_merchantfee, @m_release);

INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_platform, menu_id FROM sys_menu WHERE menu_id = @dir_tenant OR parent_id = @dir_tenant
   OR parent_id IN (@m_agent, @m_agentfee, @m_merchant, @m_merchantfee, @m_release);

-- 平台管理员额外拥有全部团购业务菜单（只读运营查看）
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_platform, menu_id FROM sys_menu WHERE menu_id = @biz_id OR parent_id = @biz_id;

-- 6.2 代理商：商户管理 + 商户收费 + 小程序发布（不含代理商管理与平台缴费审核）
INSERT IGNORE INTO sys_role_menu (role_id, menu_id) VALUES
(@role_agent, @dir_tenant), (@role_agent, @m_merchant), (@role_agent, @m_merchantfee), (@role_agent, @m_release);

INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_agent, menu_id FROM sys_menu
WHERE parent_id IN (@m_merchant, @m_merchantfee, @m_release)
  AND perms <> 'biz:merchant:remove';

-- 代理商可查看自己缴费记录（无审核权）
INSERT IGNORE INTO sys_role_menu (role_id, menu_id) VALUES (@role_agent, @m_agentfee);
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_agent, menu_id FROM sys_menu WHERE parent_id = @m_agentfee AND perms IN ('biz:agentfee:query', 'biz:agentfee:add');

-- 6.3 商户管理员：全部团购业务菜单 + 自己的小程序发布，不含租户管理与平台配置
-- 「平台配置」目录下是平台级参数（微信/支付兜底凭证、开放平台第三方参数），
-- 商户账号一律不可见，其自身小程序与支付凭证在「商户管理」的微信配置弹窗中维护
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_merchant, menu_id FROM sys_menu
WHERE menu_id = @biz_id
   OR (parent_id = @biz_id AND NOT (menu_type = 'M' AND menu_name = '平台配置'));

INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_merchant, c.menu_id FROM sys_menu p JOIN sys_menu c ON c.parent_id = p.menu_id
WHERE p.parent_id = @biz_id AND p.menu_type = 'M' AND p.menu_name NOT IN ('租户管理', '平台配置');

INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_merchant, f.menu_id FROM sys_menu p
  JOIN sys_menu c ON c.parent_id = p.menu_id
  JOIN sys_menu f ON f.parent_id = c.menu_id
WHERE p.parent_id = @biz_id AND p.menu_type = 'M' AND p.menu_name NOT IN ('租户管理', '平台配置');

-- 回收历史脚本可能已授予商户/代理商的平台配置权限（目录 + 页面 + 按钮）
DROP TEMPORARY TABLE IF EXISTS tmp_setting_menu;
CREATE TEMPORARY TABLE tmp_setting_menu (menu_id BIGINT(20) PRIMARY KEY);

INSERT IGNORE INTO tmp_setting_menu (menu_id)
SELECT menu_id FROM sys_menu WHERE parent_id = @biz_id AND menu_type = 'M' AND menu_name = '平台配置';

INSERT IGNORE INTO tmp_setting_menu (menu_id)
SELECT c.menu_id FROM sys_menu c JOIN sys_menu p ON c.parent_id = p.menu_id
WHERE p.parent_id = @biz_id AND p.menu_type = 'M' AND p.menu_name = '平台配置';

INSERT IGNORE INTO tmp_setting_menu (menu_id)
SELECT f.menu_id FROM sys_menu f
  JOIN sys_menu c ON f.parent_id = c.menu_id
  JOIN sys_menu p ON c.parent_id = p.menu_id
WHERE p.parent_id = @biz_id AND p.menu_type = 'M' AND p.menu_name = '平台配置';

DELETE rm FROM sys_role_menu rm JOIN tmp_setting_menu t ON rm.menu_id = t.menu_id
WHERE rm.role_id IN (@role_merchant, @role_agent);

DROP TEMPORARY TABLE IF EXISTS tmp_setting_menu;

INSERT IGNORE INTO sys_role_menu (role_id, menu_id) VALUES (@role_merchant, @dir_tenant), (@role_merchant, @m_release);
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_merchant, menu_id FROM sys_menu WHERE parent_id = @m_release;

-- 商户可只读查看代理商向自己开具的收费单（写操作由服务层拦截）
INSERT IGNORE INTO sys_role_menu (role_id, menu_id) VALUES (@role_merchant, @m_merchantfee);
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_merchant, menu_id FROM sys_menu
WHERE parent_id = @m_merchantfee AND perms IN ('biz:merchantfee:query');

-- ----------------------------
-- 步骤7：小程序第三方平台参数（代发布用，平台级唯一，保存在 sys_config）
-- ----------------------------
-- 注意：sys_config 无 config_key 唯一索引，INSERT IGNORE 无法去重，
-- 重复执行会产生多份同 key 配置，故一律用 NOT EXISTS 条件插入。
-- 先清理历史脚本可能造成的重复项（保留 config_id 最小的一条）
DELETE c FROM sys_config c
  JOIN (SELECT config_key, MIN(config_id) AS keep_id FROM sys_config
        WHERE config_key LIKE 'wx.open.%' GROUP BY config_key) k
    ON k.config_key = c.config_key AND c.config_id > k.keep_id;

INSERT INTO sys_config (config_name, config_key, config_value, config_type, create_by, create_time, remark)
SELECT t.* FROM (
  SELECT '开放平台第三方AppId' AS a,   'wx.open.componentAppId' AS b,  '' AS c, 'N' AS d, 'admin' AS e, SYSDATE() AS f, '小程序代发布' AS g
  UNION ALL SELECT '开放平台第三方Secret',  'wx.open.componentSecret',  '', 'N', 'admin', SYSDATE(), '小程序代发布'
  UNION ALL SELECT '开放平台消息校验Token', 'wx.open.componentToken',   '', 'N', 'admin', SYSDATE(), '小程序代发布'
  UNION ALL SELECT '开放平台消息加密Key',   'wx.open.componentAesKey',  '', 'N', 'admin', SYSDATE(), '小程序代发布'
  UNION ALL SELECT '小程序代码模板ID',      'wx.open.templateId',       '', 'N', 'admin', SYSDATE(), '小程序代发布'
  UNION ALL SELECT '授权回调域名',          'wx.open.redirectDomain',   '', 'N', 'admin', SYSDATE(), '小程序代发布'
  UNION ALL SELECT '小程序接口域名',        'wx.open.apiBaseUrl',       '', 'N', 'admin', SYSDATE(), '生成ext.json时注入各商户小程序的后端接口地址'
) t
WHERE NOT EXISTS (SELECT 1 FROM (SELECT config_key FROM sys_config) x WHERE x.config_key = t.b);

-- ----------------------------
-- 验证
-- ----------------------------
SELECT p.menu_name AS 分组, c.order_num AS 排序, c.menu_name AS 菜单, c.perms AS 权限, c.component AS 组件
FROM sys_menu p JOIN sys_menu c ON c.parent_id = p.menu_id
WHERE p.menu_id = @dir_tenant ORDER BY c.order_num;

SELECT r.role_name AS 角色, r.role_key AS 标识, COUNT(rm.menu_id) AS 菜单数
FROM sys_role r LEFT JOIN sys_role_menu rm ON rm.role_id = r.role_id
WHERE r.role_key IN ('platform', 'agent', 'merchant') GROUP BY r.role_id, r.role_name, r.role_key;
