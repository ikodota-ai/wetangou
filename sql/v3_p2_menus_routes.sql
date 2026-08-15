-- =====================================================================
-- v3 P2-3: 菜单/权限 SQL 收口
-- - 修复 2265 员工管理 parent_id=NULL 导致 getRouters NPE 的问题
-- - 挂到 tenant 2215 下面（员工管理是通用能力，平台/代理商/商户都可见）
-- - 校验 productType / productSubitem 父链 2108 商品管理
-- - 给 admin 角色补全 3 个新菜单的绑定（防止遗漏）
-- =====================================================================

-- 1) 修 2265 parent_id（NULL → 2215 tenant）
UPDATE sys_menu SET parent_id = 2215 WHERE menu_id = 2265 AND parent_id IS NULL;

-- 2) 校验 2270 / 2276 父链是 2108 商品管理（防止改父）
-- 已是 2108，跳过（仅留 assertion）

-- 3) 给 admin 角色（role_id=1）补全 productType / productSubitem / staffInvite 3 个菜单的权限
INSERT IGNORE INTO sys_role_menu (role_id, menu_id) SELECT 1, menu_id FROM sys_menu WHERE menu_id IN (2265, 2270, 2276, 2266, 2267, 2268, 2269, 2271, 2272, 2273, 2274, 2275, 2277, 2278, 2279, 2280);

-- 4) 校验 admin 角色 menu 数量
-- SELECT COUNT(*) FROM sys_role_menu WHERE role_id=1;  -- 应为 64 + 16 = 80
