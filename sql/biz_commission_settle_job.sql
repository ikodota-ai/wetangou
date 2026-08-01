-- ----------------------------
-- 佣金冷静期自动结算定时任务
-- ----------------------------
-- 默认：每天 03:00 执行 settleCommissionTask.ryNoParams()，冷静期 7 天
INSERT INTO sys_job (job_name, job_group, invoke_target, cron_expression, misfire_policy, concurrent, status, create_by, create_time, remark)
SELECT 'settle_commission_task', 'DEFAULT', 'settleCommissionTask.ryNoParams()', '0 0 3 * * ?', '3', '1', '0', 'admin', NOW(), '佣金冷静期自动结算（待 review：需补 frozenAmount/availableAmount 联动）'
WHERE NOT EXISTS (SELECT 1 FROM sys_job WHERE job_name='settle_commission_task');
