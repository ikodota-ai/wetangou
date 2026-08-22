-- ============================================================================
-- 修复：扫码入职员工账号被误建成 user_type='00'（平台身份）导致的越权
--
-- 背景：ApiMerchantStaffController.createStaffByOpenid 历史版本写死 u.setUserType("00")。
--      而 buildLoginMember 见到 user_type='00' 就授予 BizRole.PLATFORM，
--      结果扫邀请码入职的普通店员登录小程序后可读全平台商户/订单/员工名单。
--
-- 代码侧已修：新建账号统一 user_type='02'，且「有员工关联的账号」不再升级为平台身份。
-- 本脚本负责清理存量脏数据。
--
-- 幂等：可重复执行。
-- ============================================================================

-- 1) 有商家员工关联、却被标成平台账号（00）的，一律纠正为商户员工（02）
UPDATE sys_user u
JOIN (
    SELECT DISTINCT user_id FROM biz_merchant_staff
) s ON s.user_id = u.user_id
SET u.user_type = '02',
    u.update_time = NOW()
WHERE u.user_type = '00'
  AND u.user_name <> 'admin';

-- 2) 顺带回填 merchant_id（早期版本 insertUser 漏列，导致租户归属为空/0）
UPDATE sys_user u
JOIN (
    SELECT user_id, MIN(merchant_id) AS mid
    FROM biz_merchant_staff
    GROUP BY user_id
) s ON s.user_id = u.user_id
SET u.merchant_id = s.mid,
    u.update_time = NOW()
WHERE u.user_type = '02'
  AND (u.merchant_id IS NULL OR u.merchant_id = 0)
  AND s.mid IS NOT NULL
  AND s.mid <> 0;

-- 3) 校验：以下两条查询都应返回 0 行
-- SELECT user_id, user_name, user_type FROM sys_user
--  WHERE user_type = '00' AND user_id IN (SELECT user_id FROM biz_merchant_staff);
-- SELECT u.user_id FROM sys_user u JOIN biz_merchant_staff s ON s.user_id = u.user_id
--  WHERE u.user_type = '02' AND (u.merchant_id IS NULL OR u.merchant_id = 0) AND s.merchant_id <> 0;
