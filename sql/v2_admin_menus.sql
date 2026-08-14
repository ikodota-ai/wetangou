-- ============================================
-- v2 admin 菜单（idempotent）
-- 路径：团购运营 / 商品类型 / 子品管理
-- 已含：staffInvite 菜单（之前单独跑过）
-- ============================================

-- 1) 商品类型字典菜单（parent=2108 商品顶级菜单）
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品类型', 2108, 5, 'productType', 'biz/productType/index', 1, 0, 'C', '0', '0', 'biz:productType:list', 'dict', 'admin', SYSDATE(), '商品类型字典管理（11 种类型）'
FROM (SELECT 1) t
WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE component = 'biz/productType/index');

-- 2) 5 个按钮权限（query / add / edit / remove / export）
SET @m = (SELECT menu_id FROM sys_menu WHERE component = 'biz/productType/index' LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品类型查询', @m, 1, '', '', 1, 0, 'F', '0', '0', 'biz:productType:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:productType:query');
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品类型新增', @m, 2, '', '', 1, 0, 'F', '0', '0', 'biz:productType:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:productType:add');
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品类型修改', @m, 3, '', '', 1, 0, 'F', '0', '0', 'biz:productType:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:productType:edit');
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品类型删除', @m, 4, '', '', 1, 0, 'F', '0', '0', 'biz:productType:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:productType:remove');
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品类型导出', @m, 5, '', '', 1, 0, 'F', '0', '0', 'biz:productType:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:productType:export');

-- 3) 角色授权（admin 1 角色）
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu
WHERE component = 'biz/productType/index' OR perms IN ('biz:productType:query','biz:productType:add','biz:productType:edit','biz:productType:remove','biz:productType:export');

-- 4) 子品管理菜单（parent=2108）
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '子品管理', 2108, 6, 'productSubitem', 'biz/productSubitem/index', 1, 0, 'C', '0', '0', 'biz:productSubitem:list', 'tree', 'admin', SYSDATE(), '商品子品组 + 子品管理'
FROM (SELECT 1) t
WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE component = 'biz/productSubitem/index');

-- 5) 子品管理按钮权限
SET @m2 = (SELECT menu_id FROM sys_menu WHERE component = 'biz/productSubitem/index' LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '子品查询', @m2, 1, '', '', 1, 0, 'F', '0', '0', 'biz:productSubitem:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m2 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:productSubitem:query');
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '子品新增', @m2, 2, '', '', 1, 0, 'F', '0', '0', 'biz:productSubitem:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m2 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:productSubitem:add');
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '子品修改', @m2, 3, '', '', 1, 0, 'F', '0', '0', 'biz:productSubitem:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m2 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:productSubitem:edit');
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '子品删除', @m2, 4, '', '', 1, 0, 'F', '0', '0', 'biz:productSubitem:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m2 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:productSubitem:remove');

-- 6) 子品管理授权
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu
WHERE component = 'biz/productSubitem/index' OR perms LIKE 'biz:productSubitem:%';

-- 7) 验证
SELECT menu_id, menu_name, perms, path FROM sys_menu
WHERE component IN ('biz/productType/index','biz/productSubitem/index')
   OR perms LIKE 'biz:productType:%'
   OR perms LIKE 'biz:productSubitem:%'
ORDER BY menu_id;
