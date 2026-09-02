-- ============================================================================
-- 修复：老板/店长在 PC 后台重置员工密码一律 403，员工丢了密码就永久登不进商家版
--
-- 根因：PC 端权限只认 sys_user_role。实测本地库里
--        biz_merchant_staff 的 1 个 OWNER + 1 个 MANAGER 在 sys_user_role 里一条记录都没有，
--      于是这两个账号登 PC 后台后 permissions 为空集：
--        · PUT /biz/staffInvite/staff/resetPwd/{userId} → 403（重置不了员工密码）
--        · GET /biz/staffInvite/staff/list              → 403（看不到员工名单）
--        · POST /biz/staffInvite                        → 403（发不了邀请码）
--      而「员工换微信/openid 失效」之后唯一的补救途径就是让店长重置密码，这一环断了。
--      v12 脚本只给「商户管理员」这个角色补菜单权限，可它解决不了
--      「账号压根没绑任何角色」——两件事，缺一个都是 403。
--
-- 代码侧已修：扫码入职(ApiMerchantStaffController.resolvePcRoleId)与
--            新建商户建老板(MerchantServiceImpl.resolveOwnerPcRoleId)都会按
--            role_key='merchant' 绑角色。本脚本回填代码修复之前建出来的历史账号。
--
-- 只回填 OWNER / MANAGER：STAFF 是设计上不给 PC 权限的（只在小程序核销），
-- 给了反而让店员能在后台改别人密码、发邀请码（自我提权）。
--
-- 只补「一条角色都没有」的账号：已有角色的可能是平台/代理商兼任，
-- 再塞一条商户角色会让它的菜单树混进商户菜单，属于降权/串权。
--
-- 角色按 role_key 定位，不写死 role_id（role_id 由 sys_role 插入顺序决定，各库不一致）。
--
-- 幂等：可重复执行。
-- ============================================================================

INSERT INTO sys_user_role (user_id, role_id)
SELECT t.user_id, r.role_id
FROM (
        SELECT DISTINCT ms.user_id
        FROM biz_merchant_staff ms
        JOIN sys_user u ON u.user_id = ms.user_id AND u.del_flag = '0'
        LEFT JOIN sys_user_role ur ON ur.user_id = ms.user_id
        WHERE ur.role_id IS NULL
          AND ms.role IN ('OWNER', 'MANAGER')
          AND ms.merchant_id > 0
     ) t
JOIN sys_role r ON r.role_key = 'merchant' AND r.del_flag = '0'
WHERE NOT EXISTS (
        SELECT 1 FROM sys_user_role x WHERE x.user_id = t.user_id AND x.role_id = r.role_id
      );

-- 校验：以下查询应返回 0 行（不再有无角色的老板/店长）
-- SELECT ms.user_id, u.user_name, ms.role FROM biz_merchant_staff ms
--   JOIN sys_user u ON u.user_id = ms.user_id AND u.del_flag = '0'
--   LEFT JOIN sys_user_role ur ON ur.user_id = ms.user_id
--  WHERE ur.role_id IS NULL AND ms.role IN ('OWNER','MANAGER');
