-- ============================================================================
-- 修复：扫码入职的员工账号在 PC 端被当成「平台账号」，能看到别家商户的数据
--
-- 根因：PC 端的租户身份只认 biz_merchant_user（TenantServiceImpl.buildContextByUserId），
--      查不到记录就 return TenantContext.ofPlatform() 兜底成平台身份。
--      而 ApiMerchantStaffController.createStaffByOpenid（扫码入职自动建账号）
--      只写了 sys_user.merchant_id，从来没往 biz_merchant_user 落过记录。
--      实测给这类账号绑上「商户管理员」角色后：
--        · GET /getInfo          → userType=0 / merchantId=null（前端按平台身份分流）
--        · GET /biz/store/list   → total=6，含 merchant_id=2 和 200 的别家门店
--      补齐 biz_merchant_user 记录后同一账号立刻收敛为 total=4（只剩自己商户）。
--
-- 代码侧已在 createStaffByOpenid 里补 setTenantUserType/setTenantMerchantId，
-- 本脚本负责回填代码修复之前已经入职的历史账号（本地实测 30 个：1 个店长 + 29 个店员）。
--
-- 只回填「在 biz_merchant_staff 有在职/待审关联、且 biz_merchant_user 无记录」的账号，
-- 不动任何已有记录（已有记录可能是平台/代理商，覆盖会造成降权）。
-- 跨商户任职的账号（同一 user_id 关联多个 merchant_id）跳过，避免回填错商户。
--
-- 幂等：可重复执行。
-- ============================================================================

INSERT INTO biz_merchant_user (user_id, user_type, merchant_id, agent_id)
SELECT t.user_id, '2', t.merchant_id, 0
FROM (
        SELECT ms.user_id, MIN(ms.merchant_id) AS merchant_id
        FROM biz_merchant_staff ms
        JOIN sys_user u ON u.user_id = ms.user_id AND u.del_flag = '0'
        LEFT JOIN biz_merchant_user mu ON mu.user_id = ms.user_id
        WHERE mu.user_id IS NULL
          AND ms.merchant_id > 0
        GROUP BY ms.user_id
        HAVING COUNT(DISTINCT ms.merchant_id) = 1
     ) t;
