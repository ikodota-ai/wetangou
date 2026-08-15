-- V5-3 代理商与登录用户绑定（user_type=01 → biz_agent.user_id）
-- 用于代理商 dashboard 自动取 agentId

ALTER TABLE biz_agent
  ADD COLUMN user_id BIGINT NULL COMMENT '绑定登录用户 (sys_user.user_id)';

CREATE INDEX idx_biz_agent_user_id ON biz_agent(user_id);

-- backfill：已知的 agent_c43 (user_id=63) → agent_id=102 (测试代理商)
UPDATE biz_agent SET user_id = 63 WHERE agent_id = 102;
UPDATE biz_agent SET user_id = 62 WHERE agent_id = 1;   -- 平台直营 (platform_c43)
UPDATE biz_agent SET user_id = 64 WHERE agent_id = 100; -- 代理平台1

SELECT agent_id, agent_no, agent_name, user_id, status FROM biz_agent ORDER BY agent_id;
