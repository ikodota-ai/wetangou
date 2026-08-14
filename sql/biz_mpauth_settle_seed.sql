-- ============================================================
-- biz_mp_auth / biz_settle_account / biz_settle_record 种子数据
-- 2026-08-14（推进 doc/下一轮迭代清单-2026-08-14.md E3）
-- 用途：让 admin 端 /biz/mpauth /biz/account /biz/record 端到端可见
-- 幂等：INSERT IGNORE，重复跑安全
-- ============================================================

-- === biz_mp_auth 微信第三方平台授权 ===
-- merchant 1 已授权（与 mprelease 2 条数据匹配 appid）
INSERT IGNORE INTO biz_mp_auth (auth_id, merchant_id, appid, nick_name, head_img, principal_name, verify_type, refresh_token, func_info, auth_status, auth_time, create_time, update_time)
VALUES (5000001, 1, 'wx9e147c4e2151b123', '洞天团购测试小程序', 'https://example.com/headimg.jpg', '张三', '-1', 'rt_xxxxx_refresh_token_value_1234567890', '17,18,19,25,30,31,36,40,41,44,45,48,49,50,51,52', '1', '2026-07-15 10:30:00', '2026-07-15 10:00:00', '2026-08-02 03:24:15');
-- merchant 200 未授权（演示待授权状态）
INSERT IGNORE INTO biz_mp_auth (auth_id, merchant_id, appid, nick_name, principal_name, auth_status, create_time)
VALUES (5000200, 200, 'wx9876543210abcdef', '美食城小程序', '李四', '0', '2026-08-10 14:00:00');

-- === biz_settle_account 分账接收方 ===
-- merchant 1 默认账户：分账给平台 30% / 商户 70%
INSERT IGNORE INTO biz_settle_account (account_id, merchant_id, owner_type, owner_id, receiver_type, receiver_account, receiver_name, rate, status, create_time, update_time)
VALUES (6000001, 1, '1', 1, 'MERCHANT_ID', 'merchant_001', '洞天团购主商户', 70.00, '1', '2026-07-15 11:00:00', '2026-08-01 10:00:00');
-- merchant 1 平台账户
INSERT IGNORE INTO biz_settle_account (account_id, merchant_id, owner_type, owner_id, receiver_type, receiver_account, receiver_name, rate, status, create_time, update_time)
VALUES (6000002, 1, '0', 0, 'PLATFORM', 'platform_main', '平台运营账户', 30.00, '1', '2026-07-15 11:00:00', '2026-08-01 10:00:00');
-- merchant 200 推客账户
INSERT IGNORE INTO biz_settle_account (account_id, merchant_id, owner_type, owner_id, receiver_type, receiver_account, receiver_name, rate, status, create_time)
VALUES (6000200, 200, '2', 100, 'DISTRIBUTOR_ID', 'distributor_100', '推客100账户', 10.00, '1', '2026-08-10 14:30:00');

-- === biz_settle_record 分账记录 ===
-- order 1 (假设) 分账 100 元
INSERT IGNORE INTO biz_settle_record (record_id, merchant_id, order_id, out_order_no, receiver_account, amount, status, finish_time, create_time)
VALUES (7000001, 1, 1001, 'OUT20260810001', 'merchant_001', 70.00, '1', '2026-08-10 15:00:00', '2026-08-10 14:50:00');
INSERT IGNORE INTO biz_settle_record (record_id, merchant_id, order_id, out_order_no, receiver_account, amount, status, finish_time, create_time)
VALUES (7000002, 1, 1001, 'OUT20260810001', 'platform_main', 30.00, '1', '2026-08-10 15:00:00', '2026-08-10 14:50:00');
-- order 2 分账中（演示 status=0 处理中）
INSERT IGNORE INTO biz_settle_record (record_id, merchant_id, order_id, out_order_no, receiver_account, amount, status, create_time)
VALUES (7000003, 1, 1002, 'OUT20260812001', 'merchant_001', 168.00, '0', '2026-08-12 10:00:00');
-- order 3 失败
INSERT IGNORE INTO biz_settle_record (record_id, merchant_id, order_id, out_order_no, receiver_account, amount, status, create_time)
VALUES (7000004, 1, 1003, 'OUT20260813001', 'merchant_001', 38.00, '2', '2026-08-13 16:00:00');
