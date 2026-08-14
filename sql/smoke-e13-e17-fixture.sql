-- Smoke E13/E14/E16 测试数据 fixture (跨 merchantId 测试)
-- 警告：c1 smoke 假设 agent001 (mid=1) 总额 = 62.8；本 fixture 含 E15 commission 数据
-- 跑顺序：E13/E14/E16 -> C1 -> E15（避免 E15 commission 999202 污染 C1 断言）
USE ry-vue;

-- E13: OrderController
INSERT INTO biz_order (order_id, order_no, merchant_id, store_id, product_id, member_id, num, total_amount, discount_amount, pay_amount, status, create_time) VALUES
  (999001, 'SMOKE_O_999001', 2, 1, 1, 1, 1, 100.00, 0.00, 100.00, '0', NOW()),
  (999002, 'SMOKE_O_999002', 1, 1, 1, 1, 1, 200.00, 0.00, 200.00, '0', NOW())
ON DUPLICATE KEY UPDATE merchant_id=VALUES(merchant_id);

-- E14: 5 controllers (mid=2 别人 / mid=1 自己)
INSERT INTO biz_pay_bill (bill_id, bill_no, merchant_id, store_id, member_id, amount, status, create_time) VALUES
  (999101, 'SMOKE_BILL_999101', 2, 1, 1, 100.00, '0', NOW()),
  (999102, 'SMOKE_BILL_999102', 1, 1, 1, 200.00, '0', NOW())
ON DUPLICATE KEY UPDATE merchant_id=VALUES(merchant_id);

INSERT INTO biz_voucher (voucher_id, merchant_id, store_id, voucher_name, face_value, total, received, status, create_by, create_time) VALUES
  (999101, 2, 1, 'SMOKE_VCH_999101', 50.00, 100, 0, '0', 'admin', NOW()),
  (999102, 1, 1, 'SMOKE_VCH_999102', 80.00, 100, 0, '0', 'admin', NOW())
ON DUPLICATE KEY UPDATE merchant_id=VALUES(merchant_id);

INSERT INTO biz_withdraw (withdraw_id, withdraw_no, merchant_id, distributor_id, amount, withdraw_type, account, account_name, status, apply_time, create_time) VALUES
  (999101, 'W999101', 2, 1, 500.00, '0', '622800000000999101', 'T1', '0', NOW(), NOW()),
  (999102, 'W999102', 1, 1, 300.00, '0', '622800000000999102', 'T2', '0', NOW(), NOW())
ON DUPLICATE KEY UPDATE merchant_id=VALUES(merchant_id);

INSERT INTO biz_settle_record (record_id, merchant_id, order_id, out_order_no, amount, status, create_time) VALUES
  (999101, 2, 1, 'O999101', 200.00, '0', NOW()),
  (999102, 1, 1, 'O999102', 150.00, '0', NOW())
ON DUPLICATE KEY UPDATE merchant_id=VALUES(merchant_id);

INSERT INTO biz_settle_account (account_id, merchant_id, owner_type, owner_id, receiver_account, receiver_name, rate, status, create_time) VALUES
  (999101, 2, '0', 1, '622800000000999101', 'R1', 0.30, '0', NOW()),
  (999102, 1, '0', 1, '622800000000999102', 'R2', 0.30, '0', NOW())
ON DUPLICATE KEY UPDATE merchant_id=VALUES(merchant_id);

-- E15: 6 controllers (5 mid + 1 aid)
INSERT INTO biz_member (member_id, merchant_id, openid, nickname, status, create_time) VALUES
  (999201, 2, 'smoke_open_999201', 'SMOKE_M_999201', '0', NOW()),
  (999202, 1, 'smoke_open_999202', 'SMOKE_M_999202', '0', NOW())
ON DUPLICATE KEY UPDATE merchant_id=VALUES(merchant_id);

INSERT INTO biz_distributor (distributor_id, merchant_id, member_id, level, total_commission, available_amount, frozen_amount, withdraw_amount, status, join_time, create_time) VALUES
  (999201, 2, 999201, 1, 0.00, 0.00, 0.00, 0.00, '0', NOW(), NOW()),
  (999202, 1, 999202, 1, 0.00, 0.00, 0.00, 0.00, '0', NOW(), NOW())
ON DUPLICATE KEY UPDATE merchant_id=VALUES(merchant_id);

INSERT INTO biz_merchant_fee (fee_id, fee_no, merchant_id, agent_id, fee_type, amount, months, begin_time, end_time, status, create_time) VALUES
  (999201, 'MFEE_999201', 2, 1, '0', 1000.00, 12, NOW(), DATE_ADD(NOW(), INTERVAL 1 YEAR), '0', NOW()),
  (999202, 'MFEE_999202', 1, 1, '0', 800.00, 12, NOW(), DATE_ADD(NOW(), INTERVAL 1 YEAR), '0', NOW())
ON DUPLICATE KEY UPDATE merchant_id=VALUES(merchant_id);

INSERT INTO biz_agent_fee (fee_id, fee_no, agent_id, fee_type, amount, quota_add, months, pay_channel, status, create_time) VALUES
  (999201, 'AFEE_999201', 101, '0', 5000.00, 100, 12, '0', '0', NOW()),
  (999202, 'AFEE_999202', 1,   '0', 3000.00, 60, 12, '0', '0', NOW())
ON DUPLICATE KEY UPDATE agent_id=VALUES(agent_id);

INSERT INTO biz_commission (commission_id, merchant_id, distributor_id, order_id, store_id, amount, rate, status, create_time) VALUES
  (999201, 2, 1, 1, 1, 50.00, 0.10, '0', NOW()),
  (999202, 1, 1, 1, 1, 80.00, 0.10, '0', NOW())
ON DUPLICATE KEY UPDATE merchant_id=VALUES(merchant_id);

INSERT INTO biz_commission_rule (rule_id, merchant_id, rule_name, level, rate, settle_days, status, create_time) VALUES
  (999201, 2, 'SMOKE_RULE_999201', 1, 10.00, 7, '0', NOW()),
  (999202, 1, 'SMOKE_RULE_999202', 1, 10.00, 7, '0', NOW())
ON DUPLICATE KEY UPDATE merchant_id=VALUES(merchant_id);

-- E16: 6 controllers (mid=2 别人 / mid=1 自己)
INSERT INTO biz_product (product_id, merchant_id, store_id, product_name, price, status, create_time) VALUES
  (999301, 2, 1, 'SMOKE_PROD_999301', 99.00, '0', NOW()),
  (999302, 1, 1, 'SMOKE_PROD_999302', 199.00, '0', NOW())
ON DUPLICATE KEY UPDATE merchant_id=VALUES(merchant_id);

INSERT INTO biz_product_category (category_id, merchant_id, category_name, industry_code, status, create_time) VALUES
  (999301, 2, 'SMOKE_CAT_999301', 'DINING', '0', NOW()),
  (999302, 1, 'SMOKE_CAT_999302', 'DINING', '0', NOW())
ON DUPLICATE KEY UPDATE merchant_id=VALUES(merchant_id);

INSERT INTO biz_store (store_id, merchant_id, store_name, status, create_time) VALUES
  (999301, 2, 'SMOKE_STORE_999301', '0', NOW()),
  (999302, 1, 'SMOKE_STORE_999302', '0', NOW())
ON DUPLICATE KEY UPDATE merchant_id=VALUES(merchant_id);

INSERT INTO biz_store_album (album_id, merchant_id, store_id, image_url, create_time) VALUES
  (999301, 2, 1, 'http://example.com/999301.jpg', NOW()),
  (999302, 1, 1, 'http://example.com/999302.jpg', NOW())
ON DUPLICATE KEY UPDATE merchant_id=VALUES(merchant_id);

INSERT INTO biz_booking (booking_id, booking_no, merchant_id, store_id, booking_date, status, create_time) VALUES
  (999301, 'BK_999301', 2, 1, CURDATE(), '0', NOW()),
  (999302, 'BK_999302', 1, 1, CURDATE(), '0', NOW())
ON DUPLICATE KEY UPDATE merchant_id=VALUES(merchant_id);

INSERT INTO biz_banner (banner_id, merchant_id, title, image_url, position, status, sort, create_time) VALUES
  (999301, 2, 'SMOKE_BAN_999301', 'http://example.com/999301.jpg', 'home', '0', 0, NOW()),
  (999302, 1, 'SMOKE_BAN_999302', 'http://example.com/999302.jpg', 'home', '0', 0, NOW())
ON DUPLICATE KEY UPDATE merchant_id=VALUES(merchant_id);

SELECT 'all smoke data inserted (idempotent)' AS step;

-- E17: 3 controllers (mid=2 别人 / mid=1 自己)
INSERT INTO biz_agreement (agreement_id, agreement_type, merchant_id, title, content, status, create_time) VALUES
  (999401, 'SERVICE', 2, 'SMOKE_AGR_999401', 'content 999401', '0', NOW()),
  (999402, 'SERVICE', 1, 'SMOKE_AGR_999402', 'content 999402', '0', NOW())
ON DUPLICATE KEY UPDATE merchant_id=VALUES(merchant_id);

INSERT INTO biz_mp_auth (auth_id, merchant_id, appid, nick_name, auth_status, create_time) VALUES
  (999401, 2, 'smoke_app_999401', 'SMOKE_AUTH_999401', '0', NOW()),
  (999402, 1, 'smoke_app_999402', 'SMOKE_AUTH_999402', '0', NOW())
ON DUPLICATE KEY UPDATE merchant_id=VALUES(merchant_id);

INSERT INTO biz_mp_release (release_id, merchant_id, appid, user_version, release_status, create_time) VALUES
  (999401, 2, 'smoke_app_999401', 'v1.0', '0', NOW()),
  (999402, 1, 'smoke_app_999402', 'v1.0', '0', NOW())
ON DUPLICATE KEY UPDATE merchant_id=VALUES(merchant_id);
