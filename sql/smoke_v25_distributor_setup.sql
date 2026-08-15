-- V5-11 推客身份测试数据 (smoke-c49 用)
-- 给 staff_c43 (user_id=61) 绑 openid + 同步 biz_member + biz_distributor

UPDATE sys_user SET openid='oTest_distributor_001', openid_bound=1 WHERE user_id=61;

INSERT INTO biz_member (member_id, merchant_id, openid, nickname, status, user_type, create_time)
VALUES (999901, 1, 'oTest_distributor_001', '员工兼推客C43', '0', '0', NOW())
ON DUPLICATE KEY UPDATE openid=VALUES(openid);

-- 清掉历史错误数据
DELETE FROM biz_distributor WHERE distributor_id IN (999427, 999428) OR (merchant_id=1 AND member_id=61);

INSERT INTO biz_distributor (distributor_id, merchant_id, member_id, level, total_commission, available_amount, status, join_time, create_time)
VALUES (999901, 1, 999901, 1, 0, 100.00, '0', NOW(), NOW())
ON DUPLICATE KEY UPDATE available_amount=100.00;

SELECT 'verify:' as t;
SELECT user_id, openid FROM sys_user WHERE user_id=61;
SELECT member_id, openid FROM biz_member WHERE member_id=999901;
SELECT distributor_id, member_id, available_amount FROM biz_distributor WHERE distributor_id=999901;
