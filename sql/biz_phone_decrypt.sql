-- 手机号解密权限（仅平台 / 客服角色可授）
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '手机号解密', m.menu_id, 5, '#', '', 1, 0, 'F', '0', '0', 'biz:phone:decrypt', '#', 'admin', NOW(), '查看完整手机号（脱敏反操作）'
FROM sys_menu m WHERE m.menu_name = '会员管理' AND m.menu_type = 'M' LIMIT 1;

-- 授权给超管 + 客服（角色 ID 1 = 超级管理员，2 = 普通角色，按实际调整）
INSERT INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu WHERE perms = 'biz:phone:decrypt';
