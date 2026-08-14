-- ============================================================
-- biz_agent_fee / biz_merchant_fee / biz_merchant_staff_invite 种子数据
-- 2026-08-14（推进 doc/下一轮迭代清单-2026-08-14.md E2）
-- 用途：让 admin 端 /biz/agentfee /biz/merchantfee /biz/staffInvite 端到端可见
-- 幂等：INSERT IGNORE，重复跑安全
-- ============================================================

-- === biz_agent_fee 缴费记录 ===
-- agent 1 缴费 12 个月（年初缴到明年）
INSERT IGNORE INTO biz_agent_fee (fee_id, fee_no, agent_id, fee_type, amount, quota_add, months, pay_channel, pay_time, status, audit_by, audit_time, create_by, create_time, remark)
VALUES (1000001, 'AF2026010001', 1, '1', 1200.00, 50, 12, '1', '2026-01-15 10:30:00', '1', 'admin', '2026-01-15 11:00:00', 'admin', '2026-01-15 10:00:00', '2026 年度缴费 12 个月 +50 商户额度');
-- agent 1 续费 6 个月
INSERT IGNORE INTO biz_agent_fee (fee_id, fee_no, agent_id, fee_type, amount, quota_add, months, pay_channel, pay_time, status, audit_by, audit_time, create_by, create_time, remark)
VALUES (1000002, 'AF2026080001', 1, '1', 800.00, 30, 6, '1', '2026-08-01 14:20:00', '1', 'admin', '2026-08-01 14:30:00', 'admin', '2026-08-01 14:00:00', '2026-08 续费 6 个月 +30 商户额度');
-- agent 100 缴费 3 个月（小代理商）
INSERT IGNORE INTO biz_agent_fee (fee_id, fee_no, agent_id, fee_type, amount, quota_add, months, pay_channel, pay_time, status, audit_by, audit_time, create_by, create_time, remark)
VALUES (1000100, 'AF2026070100', 100, '1', 600.00, 10, 3, '0', NULL, '0', NULL, NULL, 'admin', '2026-07-15 09:00:00', '2026-07 提交 3 个月缴费待审核');
-- agent 101 缴费 1 个月
INSERT IGNORE INTO biz_agent_fee (fee_id, fee_no, agent_id, fee_type, amount, quota_add, months, pay_channel, pay_time, status, audit_by, audit_time, create_by, create_time, remark)
VALUES (1000101, 'AF2026080101', 101, '1', 200.00, 5, 1, '1', '2026-08-10 16:00:00', '1', 'admin', '2026-08-10 16:30:00', 'admin', '2026-08-10 15:30:00', '2026-08 缴费 1 个月 +5 商户额度');

-- === biz_merchant_fee 商户服务费 ===
-- merchant 1 缴年费（agent 1 名下）
INSERT IGNORE INTO biz_merchant_fee (fee_id, fee_no, merchant_id, agent_id, fee_type, amount, months, begin_time, end_time, status, create_by, create_time, remark)
VALUES (2000001, 'MF2026010001', 1, 1, '1', 800.00, 12, '2026-01-15 11:30:00', '2027-01-15 11:30:00', '1', 'admin', '2026-01-15 11:00:00', '2026 年度服务费 12 个月');
-- merchant 200 缴半年（agent 101 名下）
INSERT IGNORE INTO biz_merchant_fee (fee_id, fee_no, merchant_id, agent_id, fee_type, amount, months, begin_time, end_time, status, create_by, create_time, remark)
VALUES (2000200, 'MF2026080200', 200, 101, '1', 500.00, 6, '2026-08-10 17:00:00', '2027-02-10 17:00:00', '1', 'admin', '2026-08-10 16:30:00', '2026-08 半年服务费');

-- === biz_merchant_staff_invite 员工邀请码 ===
-- merchant 1 store 1 邀请 STAFF
INSERT IGNORE INTO biz_merchant_staff_invite (invite_id, invite_code, scene, wxacode_url, merchant_id, store_id, role, expire_at, status, create_by, create_time, remark)
VALUES (3000001, 'STAFF001', 'staff_invite:1:1:STAFF', 'https://example.com/qr/staff001.png', 1, 1, 'STAFF', '2026-09-30 23:59:59', '0', 'admin', '2026-08-01 09:00:00', '员工邀请码 STAFF001');
-- merchant 1 store 1 邀请 MANAGER
INSERT IGNORE INTO biz_merchant_staff_invite (invite_id, invite_code, scene, wxacode_url, merchant_id, store_id, role, expire_at, status, create_by, create_time, remark)
VALUES (3000002, 'MNG0002', 'staff_invite:1:1:MGR', 'https://example.com/qr/mng0002.png', 1, 1, 'MANAGER', '2026-09-30 23:59:59', '1', 'admin', '2026-08-05 10:00:00', '店长邀请码 MNG0002（已用）');
