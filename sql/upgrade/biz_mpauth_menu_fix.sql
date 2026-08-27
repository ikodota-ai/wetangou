-- =============================================
-- 小程序授权菜单修复（幂等，可重复执行）
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p 库名 < sql/biz_mpauth_menu_fix.sql
--       ↑ 必须带 --default-character-set=utf8mb4，否则中文菜单名会二次编码变乱码
--         （menu_id=2291 原本就是漏加该参数导致存成 "å°ç¨‹åºæŽˆæƒæŸ¥è¯¢"）
--
-- 修 3 件事：
--   1) mpauth 查询菜单名乱码复原
--   2) 补齐 mpauth 的增删改导出按钮权限（原先只有 list + query）
--   3) 角色绑定：admin(1)/platform(3) 此前完全没绑 mpauth 菜单，后台看不到
-- 前置：ruoyi-ui/src/views/biz/mpauth/index.vue 已实装（否则点进去空白）
-- 缓存：菜单本身不走缓存，无需 flushdb（详见 doc/部署上线指南.md §7.2）
--
-- ⚠️ 本脚本原先写死 menu_id 2290/2291/2294/2295/2296，实测这会改错菜单：
--    menu_id 由各菜单脚本的插入顺序决定，不同库不一致。init-all.sh 建出来的
--    全新库里 2294/2295/2296 是「在线预约」的增删改按钮（biz:booking:add/edit/remove），
--    旧版脚本把它们当成 mpauth 按钮绑给了 admin/platform，
--    还用 DELETE 把它们从代理商/商户角色手里删掉 —— 是一次真实的权限错授。
--    现全部改为按 perms 定位，新按钮的 menu_id 交给 auto_increment。
-- =============================================

-- 1) 修乱码菜单名（按 perms 定位，menu_id 在各库不一致）
UPDATE sys_menu SET menu_name='小程序授权查询' WHERE perms='biz:mpauth:query';

-- 2) 补齐按钮权限。
--    menu_id 不再手工指定，交给 auto_increment —— 手工分配就是上面那次错授的根因。
--    父菜单按 perms='biz:mpauth:list' 现查，缺父菜单时整段不插（NOT EXISTS 兜住）。
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '小程序授权修改', p.menu_id, 2, '#', '', '', 1, 0, 'F', '0', '0', 'biz:mpauth:edit', '#', 'admin', SYSDATE(), '维护授权状态'
  FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:mpauth:list' LIMIT 1) p
 WHERE NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:mpauth:edit') t);

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '小程序授权删除', p.menu_id, 3, '#', '', '', 1, 0, 'F', '0', '0', 'biz:mpauth:remove', '#', 'admin', SYSDATE(), '清理本地授权记录'
  FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:mpauth:list' LIMIT 1) p
 WHERE NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:mpauth:remove') t);

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '小程序授权导出', p.menu_id, 4, '#', '', '', 1, 0, 'F', '0', '0', 'biz:mpauth:export', '#', 'admin', SYSDATE(), '导出授权清单'
  FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:mpauth:list' LIMIT 1) p
 WHERE NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:mpauth:export') t);

-- 3) 角色绑定（同样按 perms 现查 menu_id）
--    admin(1) / platform(3)：全部权限（授权是平台级能力）
INSERT IGNORE INTO sys_role_menu(role_id, menu_id)
SELECT r.role_id, m.menu_id FROM sys_menu m
  JOIN (SELECT 1 AS role_id UNION ALL SELECT 3) r
 WHERE m.perms IN ('biz:mpauth:list','biz:mpauth:query','biz:mpauth:edit','biz:mpauth:remove','biz:mpauth:export');

--    agent(4) / merchant(5)：只读（代理商看名下商户，商户看自己，
--    TenantFilterHelper 会强制过滤），不给增删改导出
INSERT IGNORE INTO sys_role_menu(role_id, menu_id)
SELECT r.role_id, m.menu_id FROM sys_menu m
  JOIN (SELECT 4 AS role_id UNION ALL SELECT 5) r
 WHERE m.perms IN ('biz:mpauth:list','biz:mpauth:query');

--    清掉可能的历史误绑：代理商/商户不该有 mpauth 的删改导出
DELETE rm FROM sys_role_menu rm
  JOIN sys_menu m ON m.menu_id = rm.menu_id
 WHERE rm.role_id IN (4,5)
   AND m.perms IN ('biz:mpauth:edit','biz:mpauth:remove','biz:mpauth:export');

-- 4) 清理悬空绑定
DELETE rm FROM sys_role_menu rm LEFT JOIN sys_menu m ON rm.menu_id=m.menu_id WHERE m.menu_id IS NULL;

-- 5) 校验
SELECT menu_id, parent_id, menu_name, menu_type, perms FROM sys_menu
 WHERE perms LIKE 'biz:mpauth:%' ORDER BY order_num;
SELECT rm.role_id, GROUP_CONCAT(m.perms ORDER BY m.perms) AS perms
  FROM sys_role_menu rm JOIN sys_menu m ON m.menu_id = rm.menu_id
 WHERE m.perms LIKE 'biz:mpauth:%' GROUP BY rm.role_id;
