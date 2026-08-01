-- =============================================
-- 小程序平台配置菜单（微信开放平台第三方平台参数集中维护）
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_mpconfig_menu.sql
-- 说明：wx.open.* 参数原先只能在「系统参数」逐条改，改为独立页面维护
--       脚本可重复执行（幂等），菜单ID由自增分配，不硬编码，避免与代码生成器冲突
-- =============================================

-- ----------------------------
-- 步骤0：定位「团购运营」一级目录与「平台配置」二级目录（不存在则创建）
-- ----------------------------
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '团购运营', 0, 4, 'tuangou', '', '', '', 1, 0, 'M', '0', '0', '', 'shopping', 'admin', SYSDATE(), '洞天团购业务'
FROM (SELECT 1) t
WHERE NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE menu_name = '团购运营' AND parent_id = 0) x);

SET @biz_id = (SELECT menu_id FROM sys_menu WHERE menu_name = '团购运营' AND parent_id = 0 LIMIT 1);

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '平台配置', @biz_id, 5, 'setting', '', '', '', 1, 0, 'M', '0', '0', '', 'tool', 'admin', SYSDATE(), '微信小程序/支付等平台配置'
FROM (SELECT 1) t
WHERE NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE menu_name = '平台配置' AND parent_id = @biz_id) x);

SET @dir_setting = (SELECT menu_id FROM sys_menu WHERE menu_name = '平台配置' AND parent_id = @biz_id LIMIT 1);

-- ----------------------------
-- 步骤1：清理本脚本管理的菜单（按 component 定位，含其下按钮权限）
-- MySQL 不允许 DELETE 子查询直接引用目标表，先用临时表暂存菜单ID
-- ----------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_mpconfig_menu;
CREATE TEMPORARY TABLE tmp_mpconfig_menu (menu_id BIGINT(20) PRIMARY KEY);

INSERT INTO tmp_mpconfig_menu (menu_id)
SELECT menu_id FROM sys_menu WHERE component = 'biz/mpconfig/index';

DROP TEMPORARY TABLE IF EXISTS tmp_mpconfig_child;
CREATE TEMPORARY TABLE tmp_mpconfig_child (menu_id BIGINT(20) PRIMARY KEY);

INSERT IGNORE INTO tmp_mpconfig_child (menu_id)
SELECT m.menu_id FROM sys_menu m JOIN tmp_mpconfig_menu t ON m.parent_id = t.menu_id;

INSERT IGNORE INTO tmp_mpconfig_menu (menu_id)
SELECT menu_id FROM tmp_mpconfig_child;

DELETE rm FROM sys_role_menu rm JOIN tmp_mpconfig_menu t ON rm.menu_id = t.menu_id;
DELETE m FROM sys_menu m JOIN tmp_mpconfig_menu t ON m.menu_id = t.menu_id;

DROP TEMPORARY TABLE IF EXISTS tmp_mpconfig_child;
DROP TEMPORARY TABLE IF EXISTS tmp_mpconfig_menu;

-- ----------------------------
-- 步骤2：菜单与按钮权限
-- ----------------------------
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('小程序平台配置', @dir_setting, 2, 'mpconfig', 'biz/mpconfig/index', '', '', 1, 0, 'C', '0', '0', 'biz:mpconfig:query', 'wechat', 'admin', SYSDATE(), '开放平台第三方平台参数、代码模板与接口域名');
SET @m_mpconfig = LAST_INSERT_ID();

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark) VALUES
('平台配置查询', @m_mpconfig, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:mpconfig:query', '#', 'admin', SYSDATE(), ''),
('平台配置修改', @m_mpconfig, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:mpconfig:edit',  '#', 'admin', SYSDATE(), '');

-- ----------------------------
-- 步骤3：授权（超级管理员 + 平台管理员；代理商与商户不可见）
-- ----------------------------
SET @role_platform = (SELECT role_id FROM sys_role WHERE role_key = 'platform' LIMIT 1);

INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu WHERE menu_id = @m_mpconfig OR parent_id = @m_mpconfig;
INSERT IGNORE INTO sys_role_menu (role_id, menu_id) VALUES (1, @dir_setting);

INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_platform, menu_id FROM sys_menu
WHERE @role_platform IS NOT NULL AND (menu_id = @m_mpconfig OR parent_id = @m_mpconfig);
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_platform, @dir_setting FROM (SELECT 1) t WHERE @role_platform IS NOT NULL;

-- 「平台配置」目录下的既有「微信配置」页面同样归平台管理员（历史脚本只授到目录级）
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_platform, m.menu_id FROM sys_menu m
WHERE @role_platform IS NOT NULL
  AND (m.component = 'biz/wxconfig/index'
       OR m.parent_id IN (SELECT menu_id FROM (SELECT menu_id FROM sys_menu WHERE component = 'biz/wxconfig/index') x));

-- 「微信配置」页面语义调整：改为平台默认商户的兜底凭证，多商户凭证在商户管理中维护
UPDATE sys_menu SET remark = '平台默认商户的小程序/支付兜底凭证，各商户凭证在「商户管理」中维护'
WHERE component = 'biz/wxconfig/index';

-- ----------------------------
-- 验证
-- ----------------------------
SELECT p.menu_name AS 分组, c.order_num AS 排序, c.menu_name AS 菜单, c.perms AS 权限, c.component AS 组件
FROM sys_menu p JOIN sys_menu c ON c.parent_id = p.menu_id
WHERE p.menu_id = @dir_setting ORDER BY c.order_num;

SELECT config_key AS 参数键, config_name AS 参数名, config_value AS 当前值
FROM sys_config WHERE config_key LIKE 'wx.open.%' ORDER BY config_id;
