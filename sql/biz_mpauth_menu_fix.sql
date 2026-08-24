-- =============================================
-- 小程序授权菜单修复（幂等，可重复执行）
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p 库名 < sql/biz_mpauth_menu_fix.sql
--       ↑ 必须带 --default-character-set=utf8mb4，否则中文菜单名会二次编码变乱码
--         （menu_id=2291 原本就是漏加该参数导致存成 "å°ç¨‹åºæŽˆæƒæŸ¥è¯¢"）
--
-- 修 3 件事：
--   1) 2291 菜单名乱码复原
--   2) 补齐 mpauth 的增删改导出按钮权限（原先只有 list + query）
--   3) 角色绑定：admin(1)/platform(3) 此前完全没绑 2290，后台看不到该菜单
-- 前置：ruoyi-ui/src/views/biz/mpauth/index.vue 已实装（否则点进去空白）
-- 执行后必须清 Redis：redis-cli -n 0 flushdb   否则 getRouters 返旧菜单
-- =============================================

-- 1) 修乱码菜单名
UPDATE sys_menu SET menu_name='小程序授权查询' WHERE menu_id=2291;

-- 2) 补齐按钮权限
--    注意：2292/2293 已被「商品创建/商品详情」占用（v3_p2_menus_routes.sql），
--    2294 才是当时的表尾，故新按钮从 2295 起分配，避免撞号后把商品权限
--    误绑给平台角色。分配前务必确认这些 id 未被占用。
INSERT INTO sys_menu (menu_id, menu_name, parent_id, order_num, path, component, query, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT 2295, '小程序授权修改', 2290, 2, '#', '', '', 1, 0, 'F', '0', '0', 'biz:mpauth:edit', '#', 'admin', SYSDATE(), '维护授权状态'
WHERE NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE menu_id=2295) t);

INSERT INTO sys_menu (menu_id, menu_name, parent_id, order_num, path, component, query, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT 2296, '小程序授权删除', 2290, 3, '#', '', '', 1, 0, 'F', '0', '0', 'biz:mpauth:remove', '#', 'admin', SYSDATE(), '清理本地授权记录'
WHERE NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE menu_id=2296) t);

-- 2294 授权导出此前已由本脚本创建过，保留原 id 以免重复
INSERT INTO sys_menu (menu_id, menu_name, parent_id, order_num, path, component, query, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT 2294, '小程序授权导出', 2290, 4, '#', '', '', 1, 0, 'F', '0', '0', 'biz:mpauth:export', '#', 'admin', SYSDATE(), '导出授权清单'
WHERE NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE menu_id=2294) t);

-- 3) 角色绑定
--    admin(1) / platform(3)：全部权限（授权是平台级能力）
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) VALUES
  (1,2290),(1,2291),(1,2294),(1,2295),(1,2296),
  (3,2290),(3,2291),(3,2294),(3,2295),(3,2296);
--    agent(4)：只读（看名下商户的授权情况，不给删改）
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) VALUES (4,2290),(4,2291);
--    merchant(5)：只读自己的（TenantFilterHelper 会强制过滤到本商户）
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) VALUES (5,2290),(5,2291);
--    代理商不该有删改权限，清掉可能的历史误绑
DELETE FROM sys_role_menu WHERE role_id IN (4,5) AND menu_id IN (2294,2295,2296);

-- 4) 清理悬空绑定
DELETE rm FROM sys_role_menu rm LEFT JOIN sys_menu m ON rm.menu_id=m.menu_id WHERE m.menu_id IS NULL;

-- 5) 校验
SELECT menu_id, parent_id, menu_name, menu_type, perms FROM sys_menu WHERE menu_id=2290 OR parent_id=2290 ORDER BY order_num;
SELECT role_id, GROUP_CONCAT(menu_id ORDER BY menu_id) AS menus FROM sys_role_menu
 WHERE menu_id IN (2290,2291,2294,2295,2296) GROUP BY role_id;
