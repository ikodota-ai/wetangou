-- =============================================
-- 角色权限扩展 (小程序端 3 角色 + 平台 + 代理商 = 5 角色)
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p133301 ry-vue < sql/biz_role_extension.sql
-- 可重复执行（幂等）
-- 背景：之前小程序商家端只区分「店员」一种身份，老板/店长/平台/代理都走同一链路
--       现在需要：PLATFORM（平台）/ AGENT（代理商）/ OWNER（老板）/ MANAGER（店长）/ STAFF（店员）
--       注意：biz_merchant_staff.role 字段已存在（STAFF/MANAGER/OWNER），本脚本不破坏存量数据
-- =============================================

-- 1) biz_merchant_staff.role 字段扩展注释（不改字段类型，已有 STAFF/MANAGER/OWNER）
ALTER TABLE biz_merchant_staff MODIFY COLUMN role VARCHAR(20) DEFAULT 'STAFF'
  COMMENT 'STAFF=店员 / MANAGER=店长 / OWNER=老板';

-- 2) 5 角色测试账号 (smoke-c43 密码统一 admin123)
-- 2.1) PLATFORM (user_type=00, 无商家员工关联)
INSERT INTO sys_user (user_name, nick_name, password, status, user_type, merchant_id, create_by, create_time, remark)
SELECT 'platform_c43', '平台运营C43', '$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2',
       '0', '00', 0, 'system', NOW(), 'smoke-c43 平台账号 (小程序端可查跨店业绩)'
WHERE NOT EXISTS (SELECT 1 FROM sys_user WHERE user_name='platform_c43');


-- 兜底：清理旧 'AG_C43' agent 名字
UPDATE biz_agent SET agent_name='测试代理商', contact='陈代理', phone='13900139001' WHERE agent_no='AG_C43';

-- 2.2) AGENT (user_type=01, biz_agent 关联, 无商家员工关联)
INSERT INTO sys_user (user_name, nick_name, password, status, user_type, merchant_id, create_by, create_time, remark)
SELECT 'agent_c43', '代理商C43', '$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2',
       '0', '01', 0, 'system', NOW(), 'smoke-c43 代理商账号'
WHERE NOT EXISTS (SELECT 1 FROM sys_user WHERE user_name='agent_c43');

INSERT INTO biz_agent (agent_no, agent_name, contact, phone, region, status, create_by, create_time)
SELECT 'AG_C43', '测试代理商', '陈代理', '13900139001',
       '广东省', '0', 'system', NOW()
WHERE NOT EXISTS (SELECT 1 FROM biz_agent WHERE agent_no='AG_C43');

-- biz_merchant_user 兼容 TenantIdentityResolver (agent_id 必填)
INSERT INTO biz_merchant_user (user_id, agent_id, user_type)
SELECT u.user_id, a.agent_id, '1'
FROM sys_user u, biz_agent a
WHERE u.user_name='agent_c43' AND a.agent_no='AG_C43'
  AND NOT EXISTS (SELECT 1 FROM biz_merchant_user mu
                  JOIN sys_user u2 ON u2.user_id=mu.user_id
                  JOIN biz_agent a2 ON a2.agent_id=mu.agent_id
                  WHERE u2.user_name='agent_c43' AND a2.agent_no='AG_C43');

-- 2.3) OWNER (user_type=02, biz_merchant_staff.role=OWNER)
INSERT INTO sys_user (user_name, nick_name, password, status, user_type, merchant_id, create_by, create_time, remark)
SELECT 'owner_c43', '老板C43', '$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2',
       '0', '02', 1, 'system', NOW(), 'smoke-c43 老板测试账号'
WHERE NOT EXISTS (SELECT 1 FROM sys_user WHERE user_name='owner_c43');

INSERT INTO biz_merchant_staff (merchant_id, store_id, user_id, role, real_name, status, create_by, create_time)
SELECT 1, 100, user_id, 'OWNER', '王老板', '0', 'system', NOW()
FROM sys_user WHERE user_name='owner_c43'
  AND NOT EXISTS (SELECT 1 FROM biz_merchant_staff ms
                  JOIN sys_user u ON u.user_id=ms.user_id
                  WHERE u.user_name='owner_c43' AND ms.role='OWNER');

-- 2.4) MANAGER (user_type=02, role=MANAGER)
INSERT INTO sys_user (user_name, nick_name, password, status, user_type, merchant_id, create_by, create_time, remark)
SELECT 'manager_c43', '店长C43', '$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2',
       '0', '02', 1, 'system', NOW(), 'smoke-c43 店长测试账号'
WHERE NOT EXISTS (SELECT 1 FROM sys_user WHERE user_name='manager_c43');

INSERT INTO biz_merchant_staff (merchant_id, store_id, user_id, role, real_name, status, create_by, create_time)
SELECT 1, 100, user_id, 'MANAGER', '李店长', '0', 'system', NOW()
FROM sys_user WHERE user_name='manager_c43'
  AND NOT EXISTS (SELECT 1 FROM biz_merchant_staff ms
                  JOIN sys_user u ON u.user_id=ms.user_id
                  WHERE u.user_name='manager_c43' AND ms.role='MANAGER');

-- 2.5) STAFF (user_type=02, role=STAFF)
INSERT INTO sys_user (user_name, nick_name, password, status, user_type, merchant_id, create_by, create_time, remark)
SELECT 'staff_c43', '店员C43', '$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2',
       '0', '02', 1, 'system', NOW(), 'smoke-c43 店员测试账号'
WHERE NOT EXISTS (SELECT 1 FROM sys_user WHERE user_name='staff_c43');

INSERT INTO biz_merchant_staff (merchant_id, store_id, user_id, role, real_name, status, create_by, create_time)
SELECT 1, 100, user_id, 'STAFF', '赵店员', '0', 'system', NOW()
FROM sys_user WHERE user_name='staff_c43'
  AND NOT EXISTS (SELECT 1 FROM biz_merchant_staff ms
                  JOIN sys_user u ON u.user_id=ms.user_id
                  WHERE u.user_name='staff_c43' AND ms.role='STAFF');

-- 3) 5 角色密码统一 admin123 (兜底)
UPDATE sys_user SET password = '$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2'
WHERE user_name IN ('platform_c43','agent_c43','owner_c43','manager_c43','staff_c43');

-- 4) 验证
SELECT '--- smoke-c43 5 角色账号清单 ---' AS info;
SELECT u.user_name, u.user_type AS sys_user_type,
       ms.role AS staff_role, ms.real_name,
       a.agent_name
FROM sys_user u
LEFT JOIN biz_merchant_staff ms ON ms.user_id = u.user_id
LEFT JOIN biz_merchant_user mu ON mu.user_id = u.user_id
LEFT JOIN biz_agent a ON a.agent_id = mu.agent_id
WHERE u.user_name IN ('platform_c43','agent_c43','owner_c43','manager_c43','staff_c43')
ORDER BY FIELD(u.user_name,'platform_c43','agent_c43','owner_c43','manager_c43','staff_c43');
