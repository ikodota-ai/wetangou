-- =============================================
-- 菜单平铺：去掉"团购运营"顶级，6 个子模块平铺为顶级 + 2215 改名"我的商户"
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_menu_flatten.sql
-- 可重复执行（幂等）
-- 前置：已完成 19 个业务页建表 + 5 大类二级分组（见 sql/biz_menu_reorganization.sql），
--       此时"团购运营"顶级 menu_id=2001，下挂 2108/2109/2110/2111/2112/2215
-- =============================================

-- 0) 备份（重演前先备份）
-- CREATE TABLE sys_menu_bak_YYYYMMDD AS SELECT * FROM sys_menu;
-- CREATE TABLE sys_role_menu_bak_YYYYMMDD AS SELECT * FROM sys_role_menu;

-- 1) 6 个二级菜单平铺为顶级（order_num 5 起步，避让 RuoYi 原生 1-4）
UPDATE sys_menu SET parent_id=0, order_num=5  WHERE menu_id=2108;
UPDATE sys_menu SET parent_id=0, order_num=6  WHERE menu_id=2109;
UPDATE sys_menu SET parent_id=0, order_num=7  WHERE menu_id=2110;
UPDATE sys_menu SET parent_id=0, order_num=8  WHERE menu_id=2111;
UPDATE sys_menu SET parent_id=0, order_num=9  WHERE menu_id=2112;
UPDATE sys_menu SET parent_id=0, order_num=10, menu_name='我的商户' WHERE menu_id=2215;

-- 2) 删"团购运营"顶级 2001 及其角色绑定
DELETE FROM sys_role_menu WHERE menu_id=2001;
DELETE FROM sys_menu       WHERE menu_id=2001;

-- 3) 角色重新绑顶级（admin=1, platform=3, agent=4, merchant=5）
--    admin / platform 看全部 6 个顶级
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) VALUES(1,2108),(1,2109),(1,2110),(1,2111),(1,2112),(1,2215);
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) VALUES(3,2108),(3,2109),(3,2110),(3,2111),(3,2112),(3,2215);
--    agent 只看"我的商户"
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) VALUES(4,2215);
--    merchant 看 5 个（不含 2112 平台配置）
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) VALUES(5,2108),(5,2109),(5,2110),(5,2111),(5,2215);

-- 4) 清理悬空绑定
DELETE rm FROM sys_role_menu rm LEFT JOIN sys_menu m ON rm.menu_id=m.menu_id WHERE m.menu_id IS NULL;

-- 5) 清 Redis 缓存（必须！否则 getRouters 返旧值）
-- redis-cli -n 0 flushdb

-- A3: 补 'biz:mpconfig:list' 菜单 + 绑 platform/admin/agent 角色
INSERT INTO sys_menu(menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark) 
SELECT '平台状态查询', 2112, 1, '#', '', 1, 0, 'F', '0', '0', 'biz:mpconfig:list', '#', 'admin', NOW(), '第三方平台状态'
FROM (SELECT 1) t
WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='biz:mpconfig:list');
SET @mp_list = (SELECT menu_id FROM sys_menu WHERE perms='biz:mpconfig:list' LIMIT 1);
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) SELECT 1, @mp_list;
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) SELECT 3, @mp_list;
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) SELECT 4, @mp_list;

-- 轮播图管理（在 平台配置 顶级下）
INSERT INTO sys_menu(menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '轮播图管理', 2112, 10, 'banner', 'biz/banner/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:banner:list', 'picture', 'admin', NOW(), '首页 banner 轮播图'
FROM (SELECT 1) t
WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='biz:banner:list');
SET @banner_id = (SELECT menu_id FROM sys_menu WHERE perms='biz:banner:list' LIMIT 1);
-- 5 个按钮权限
INSERT INTO sys_menu(menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT 'banner:query', @banner_id, 1, '#', NULL, NULL, '', 1, 0, 'F', '0', '0', 'biz:banner:query', '#', 'admin', NOW(), 'banner 按钮'
FROM (SELECT 1) t WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='biz:banner:query');
INSERT INTO sys_menu(menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT 'banner:add', @banner_id, 2, '#', NULL, NULL, '', 1, 0, 'F', '0', '0', 'biz:banner:add', '#', 'admin', NOW(), 'banner 按钮'
FROM (SELECT 1) t WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='biz:banner:add');
INSERT INTO sys_menu(menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT 'banner:edit', @banner_id, 3, '#', NULL, NULL, '', 1, 0, 'F', '0', '0', 'biz:banner:edit', '#', 'admin', NOW(), 'banner 按钮'
FROM (SELECT 1) t WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='biz:banner:edit');
INSERT INTO sys_menu(menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT 'banner:remove', @banner_id, 4, '#', NULL, NULL, '', 1, 0, 'F', '0', '0', 'biz:banner:remove', '#', 'admin', NOW(), 'banner 按钮'
FROM (SELECT 1) t WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='biz:banner:remove');
INSERT INTO sys_menu(menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT 'banner:export', @banner_id, 5, '#', NULL, NULL, '', 1, 0, 'F', '0', '0', 'biz:banner:export', '#', 'admin', NOW(), 'banner 按钮'
FROM (SELECT 1) t WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='biz:banner:export');
-- 绑 admin / platform 角色
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) SELECT 1, @banner_id;
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) SELECT 3, @banner_id;
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) 
  SELECT 1, menu_id FROM sys_menu WHERE parent_id=@banner_id;
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) 
  SELECT 3, menu_id FROM sys_menu WHERE parent_id=@banner_id;
