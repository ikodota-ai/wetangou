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
-- 按 perms 定位，不写死 menu_id（menu_id 由各菜单脚本插入顺序决定，各库不一致）。
--
-- 幂等：可重复执行。
-- ============================================================================

-- 1) 商户管理员：绑定店员邀请菜单 + 全部按钮
INSERT INTO sys_role_menu (role_id, menu_id)
SELECT 5, m.menu_id
FROM sys_menu m
WHERE m.perms IN (
        'biz:staffInvite:list',
        'biz:staffInvite:query',
        'biz:staffInvite:add',
        'biz:staffInvite:edit',
        'biz:staffInvite:remove'
      )
  AND NOT EXISTS (
        SELECT 1 FROM sys_role_menu rm WHERE rm.role_id = 5 AND rm.menu_id = m.menu_id
      );

-- 2) 店员邀请是「店员管理」页的入口，父菜单没绑的话菜单树里不显示（接口能调但点不进去）
INSERT INTO sys_role_menu (role_id, menu_id)
SELECT 5, p.menu_id
FROM sys_menu c
JOIN sys_menu p ON p.menu_id = c.parent_id
WHERE c.perms = 'biz:staffInvite:list'
  AND p.menu_id > 0
  AND NOT EXISTS (
        SELECT 1 FROM sys_role_menu rm WHERE rm.role_id = 5 AND rm.menu_id = p.menu_id
      );

-- 3) 代理商同样需要（数据范围由 assertDataScope 限制在名下商户）
INSERT INTO sys_role_menu (role_id, menu_id)
SELECT 4, m.menu_id
FROM sys_menu m
WHERE m.perms IN (
        'biz:staffInvite:list',
        'biz:staffInvite:query',
        'biz:staffInvite:add',
        'biz:staffInvite:edit',
        'biz:staffInvite:remove'
      )
  AND NOT EXISTS (
        SELECT 1 FROM sys_role_menu rm WHERE rm.role_id = 4 AND rm.menu_id = m.menu_id
      );

INSERT INTO sys_role_menu (role_id, menu_id)
SELECT 4, p.menu_id
FROM sys_menu c
JOIN sys_menu p ON p.menu_id = c.parent_id
WHERE c.perms = 'biz:staffInvite:list'
  AND p.menu_id > 0
  AND NOT EXISTS (
        SELECT 1 FROM sys_role_menu rm WHERE rm.role_id = 4 AND rm.menu_id = p.menu_id
      );

-- 4) 校验：两个角色都应各有 5 条 staffInvite 权限
-- SELECT rm.role_id, COUNT(*) FROM sys_role_menu rm
--   JOIN sys_menu m ON m.menu_id = rm.menu_id
--  WHERE m.perms LIKE 'biz:staffInvite:%' AND rm.role_id IN (4,5)
--  GROUP BY rm.role_id;
