-- F2 补 v2 新增 controller 的 sys_menu 记录 (mpauth) + agent 角色加 banner/mpauth perms
-- 现象: Banner agent 返 403 没有权限, MpAuth agent 返 403 (sys_menu 缺记录)
-- 根因: Banner v2 升级时漏给 agent 角色加 menu_id 2259/2260; MpAuth 是 v2 新增, sys_menu 完全没注册
-- 修法:
--   1. sys_role_menu: role_id=4 (agent) 加 banner (2259/2260)
--   2. sys_menu: 新增 2290 (mpauth 菜单) + 2291 (mpauth:query 按钮)
--   3. sys_role_menu: role_id=4 加 mpauth (2290/2291)
-- 验证: E16 Banner 3/3 PASS + E17 MpAuth 3/3 PASS (agent 别人 500 / 自己 200 / admin 200)
USE ry-vue;
-- 1. agent 角色加 banner
INSERT IGNORE INTO sys_role_menu (role_id, menu_id) VALUES (4, 2259), (4, 2260);
-- 2. sys_menu 新增 mpauth (parent_id=0 顶级)
INSERT IGNORE INTO sys_menu (menu_id, menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark) VALUES
  (2290, '小程序授权', 0, 99, 'mpauth', 'biz/mpauth/index', 1, 0, 'C', '0', '0', 'biz:mpauth:list',  '#', 'admin', NOW(), 'mpauth 菜单 (v2 新增)'),
  (2291, '小程序授权查询', 2290, 1, '#', '', 1, 0, 'F', '0', '0', 'biz:mpauth:query', '#', 'admin', NOW(), 'mpauth 详情 (v2 新增)');
-- 3. agent 角色加 mpauth
INSERT IGNORE INTO sys_role_menu (role_id, menu_id) VALUES (4, 2290), (4, 2291);
