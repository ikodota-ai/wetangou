-- ============================================================
-- C1 代理商佣金概览（admin 端）权限 + 菜单
-- 2026-08-14
-- ============================================================
-- 菜单（hidden=true，只是个权限载体，admin 端不显示菜单项，/agent/index 容器内调用）
INSERT IGNORE INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('代理商佣金概览', 0, 5, 'agentCommission', NULL, 1, 0, 'F', '0', '0', 'biz:agent:commission:summary', 'money', 'admin', NOW(), '代理商工作台佣金概览（admin 端）');

-- 绑定 admin 角色（role_id=1）
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu WHERE perms='biz:agent:commission:summary' AND menu_id NOT IN (SELECT menu_id FROM sys_role_menu WHERE role_id=1);
