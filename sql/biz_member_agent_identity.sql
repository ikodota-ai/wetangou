-- 2026-08-15: 代理商身份字段
-- 解决 /api/distributor/agent/summary dead-end (C23):
--   LoginMember 原本不读 userType/agentId, biz_member 表无列
ALTER TABLE biz_member
  ADD COLUMN user_type varchar(2) DEFAULT '0' COMMENT '用户类型: 0=普通会员 1=代理商 2=员工' AFTER status,
  ADD COLUMN agent_id  bigint(20) DEFAULT NULL COMMENT '代理商ID(user_type=1 时)' AFTER user_type;
-- 索引
ALTER TABLE biz_member
  ADD INDEX idx_user_type_agent (user_type, agent_id);
