-- ============================================================================
-- 修复：商户老板/店长在后台完全招不了店员（店员邀请菜单一个权限都没绑）
--
-- 根因：sys_role「商户管理员」(role_key=merchant，新建商户自动开通的老板账号就用它)
--      绑了商品(biz:product:*)、门店(biz:store:*) 等 125 条菜单，
--      却没有任何一条 biz:staffInvite:*。于是老板登录 PC 后台：
--        · POST /biz/staffInvite            → 403 没有权限（生成不了邀请码）
--        · GET  /biz/staffInvite/staff/list → 403（看不到员工名单）
--        · GET  /biz/staffInvite/staff/audit→ 403（审不了扫码入职申请）
--        · PUT  /biz/staffInvite/staff/resetPwd/{userId} → 403（重置不了员工密码）
--      而「店员扫码入职 → 店长审核 → 店员核销」是商家端最基础的流程，
--      店长这一环全断，只能让平台管理员代劳每一家店的招人，实测 403 全中。
--
-- 同时补代理商(role_key=agent)：代理商要帮名下商户做开通支持，
-- 数据范围本来就由 TenantFilterHelper.assertDataScope 限制在名下商户，
-- 给菜单权限不会造成跨租户越权（越权场景另有 smoke 覆盖）。
--
-- 按 perms 定位菜单、按 role_key 定位角色，两者都不写死 id：
-- menu_id 由各菜单脚本插入顺序决定，role_id 由 sys_role 插入顺序决定，各库都不一致。
-- 原版本写死 role_id=5(商户)/4(代理商)，而 sql/biz_tenant_menu.sql 建这两个角色用的是
-- 「WHERE NOT EXISTS (role_key=...)」——在一个先有其它角色的库里，merchant 完全可能落到 6/7，
-- 那时这个脚本就把 staffInvite 权限补给了 role_id=5 的另一个角色，老板依旧 403。
--
-- 幂等：可重复执行。
-- ============================================================================

-- 1) 商户管理员 + 代理商：绑定店员邀请菜单的全部按钮
--    代理商也要给：它要帮名下商户做开通支持，数据范围由 TenantFilterHelper.assertDataScope
--    限制在名下商户，给菜单权限不造成跨租户越权（越权场景另有 smoke 覆盖）。
INSERT INTO sys_role_menu (role_id, menu_id)
SELECT r.role_id, m.menu_id
FROM sys_role r
JOIN sys_menu m
  ON m.perms IN (
        'biz:staffInvite:list',
        'biz:staffInvite:query',
        'biz:staffInvite:add',
        'biz:staffInvite:edit',
        'biz:staffInvite:remove'
     )
WHERE r.role_key IN ('merchant', 'agent')
  AND r.del_flag = '0'
  AND NOT EXISTS (
        SELECT 1 FROM sys_role_menu rm WHERE rm.role_id = r.role_id AND rm.menu_id = m.menu_id
      );

-- 2) 店员邀请是「店员管理」页的入口，父菜单没绑的话菜单树里不显示（接口能调但点不进去）
INSERT INTO sys_role_menu (role_id, menu_id)
SELECT r.role_id, p.menu_id
FROM sys_role r
JOIN sys_menu c ON c.perms = 'biz:staffInvite:list'
JOIN sys_menu p ON p.menu_id = c.parent_id AND p.menu_id > 0
WHERE r.role_key IN ('merchant', 'agent')
  AND r.del_flag = '0'
  AND NOT EXISTS (
        SELECT 1 FROM sys_role_menu rm WHERE rm.role_id = r.role_id AND rm.menu_id = p.menu_id
      );

-- 3) 校验：两个角色都应各有 5 条 staffInvite 权限
-- SELECT r.role_key, COUNT(*) FROM sys_role_menu rm
--   JOIN sys_menu m ON m.menu_id = rm.menu_id
--   JOIN sys_role r ON r.role_id = rm.role_id
--  WHERE m.perms LIKE 'biz:staffInvite:%' AND r.role_key IN ('merchant','agent')
--  GROUP BY r.role_key;
