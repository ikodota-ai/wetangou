-- ============================================================
-- 核销 / 买单确认：菜单权限插入
--   - biz:order:verify  订单核销（后台 web 端）
--   - biz:bill:confirm   买单确认（后台 web 端）
-- ============================================================

-- 1) 订单核销按钮（挂在「订单管理」菜单下）
SET @order_parent = (SELECT menu_id FROM sys_menu WHERE perms = 'biz:order:list' LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '订单核销', @order_parent, 6, '#', '', 1, 0, 'F', '0', '0', 'biz:order:verify', '#', 'admin', NOW(), '订单核销（后台 web 端）'
FROM DUAL
WHERE @order_parent IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:order:verify');

-- 2) 买单确认按钮
SET @bill_parent = (SELECT menu_id FROM sys_menu WHERE perms = 'biz:bill:list' LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单确认', @bill_parent, 6, '#', '', 1, 0, 'F', '0', '0', 'biz:bill:confirm', '#', 'admin', NOW(), '买单确认（后台 web 端）'
FROM DUAL
WHERE @bill_parent IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:bill:confirm');

-- 3) 把新权限授权给 admin + common 角色（默认全开）
INSERT INTO sys_role_menu (role_id, menu_id)
SELECT r.role_id, m.menu_id
FROM sys_role r, sys_menu m
WHERE r.role_key IN ('admin','common')
  AND m.perms IN ('biz:order:verify','biz:bill:confirm')
  AND NOT EXISTS (
    SELECT 1 FROM sys_role_menu rm
    WHERE rm.role_id = r.role_id AND rm.menu_id = m.menu_id
  );

-- 4) 自检
SELECT m.menu_id, m.menu_name, m.perms FROM sys_menu m WHERE m.perms IN ('biz:order:verify','biz:bill:confirm');
