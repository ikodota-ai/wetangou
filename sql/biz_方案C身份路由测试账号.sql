-- 方案 C：登录入口按 userType 路由分流 + 菜单按角色过滤
-- 测试账号初始化（生产请删除或改密码）

-- 1) 平台运营账号
-- 平台账号 userType=0 agent_id=0 merchant_id=0
-- 密码: admin123 (BCrypt)
INSERT INTO sys_user(dept_id, user_name, nick_name, user_type, status, password, create_by, remark)
VALUES(103, 'platform001', '平台运营', '00', '0',
       '$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2',
       'admin', '方案C测试-平台账号')
ON DUPLICATE KEY UPDATE update_time=now();

-- 2) 代理商账号
-- userType=1 agent_id=100 (代理平台1) merchant_id=0
INSERT INTO sys_user(dept_id, user_name, nick_name, user_type, status, password, create_by, remark)
VALUES(103, 'agent001', '代理商管理员', '00', '0',
       '$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2',
       'admin', '方案C测试-代理商账号')
ON DUPLICATE KEY UPDATE update_time=now();

-- 3) 商户管理员账号
-- userType=2 agent_id=1 (平台直营) merchant_id=1 (洞天团购)
INSERT INTO sys_user(dept_id, user_name, nick_name, user_type, status, password, create_by, remark)
VALUES(103, 'merchant001', '商户管理员', '00', '0',
       '$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2',
       'admin', '方案C测试-商户账号')
ON DUPLICATE KEY UPDATE update_time=now();

-- 角色绑定
INSERT INTO sys_user_role(user_id, role_id)
SELECT u.user_id, 3 FROM sys_user u WHERE u.user_name='platform001'
ON DUPLICATE KEY UPDATE role_id=3;
INSERT INTO sys_user_role(user_id, role_id)
SELECT u.user_id, 4 FROM sys_user u WHERE u.user_name='agent001'
ON DUPLICATE KEY UPDATE role_id=4;
INSERT INTO sys_user_role(user_id, role_id)
SELECT u.user_id, 5 FROM sys_user u WHERE u.user_name='merchant001'
ON DUPLICATE KEY UPDATE role_id=5;

-- 业务身份回填（biz_merchant_user）
-- platform001 → 平台
INSERT INTO biz_merchant_user(user_id, user_type, agent_id, merchant_id, create_by)
SELECT user_id, '0', 0, 0, 'admin' FROM sys_user WHERE user_name='platform001'
ON DUPLICATE KEY UPDATE user_type='0', agent_id=0, merchant_id=0;

-- agent001 → 代理商 (agent_id=100)
INSERT INTO biz_merchant_user(user_id, user_type, agent_id, merchant_id, create_by)
SELECT user_id, '1', 100, 0, 'admin' FROM sys_user WHERE user_name='agent001'
ON DUPLICATE KEY UPDATE user_type='1', agent_id=100, merchant_id=0;

-- merchant001 → 商户 (merchant_id=1, agent_id=1)
INSERT INTO biz_merchant_user(user_id, user_type, agent_id, merchant_id, create_by)
SELECT user_id, '2', 1, 1, 'admin' FROM sys_user WHERE user_name='merchant001'
ON DUPLICATE KEY UPDATE user_type='2', agent_id=1, merchant_id=1;

-- 补 agent 角色顶级父菜单绑定（修复 0 菜单 bug）
-- 原因：SysMenuServiceImpl.selectMenuTreeByUserId 调 getChildPerms(list, 0)
-- 找 parent_id=0 的顶级菜单；agent 角色没绑"团购运营"（menu_id=2001）
-- 顶级菜单找不到 → returnList 空 → 0 router
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) VALUES(4, 2001);
-- 补"代理商管理"(2216) C 菜单，让 agent 能看自己代理商信息
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) VALUES(4, 2216);
-- 删 merchant 角色误绑的"代理商管理/代理商缴费"（merchant 不应看代理商）
DELETE FROM sys_role_menu WHERE role_id=5 AND menu_id IN (2216, 2217);
