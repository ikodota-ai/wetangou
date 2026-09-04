-- ===========================================================================
-- 定时任务名改中文（中文 + 英文标识）
--
-- 背景：后台「定时任务」列表里显示的是 settle_commission_task 这类英文函数名，
-- 运营看不出这个任务到底在干什么，也不敢停/不敢改 cron。
-- 保留括号里的英文标识是为了跟 invoke_target 和日志里的类名对得上。
--
-- 幂等：按 invoke_target 精确匹配，可重复执行。
-- ===========================================================================

update sys_job set job_name = '分销佣金结算（settle_commission）'
  where invoke_target = 'settleCommissionTask.ryNoParams()';

update sys_job set job_name = '超时未支付订单自动取消（cancel_timeout_order）'
  where invoke_target = 'cancelTimeoutOrderTask.ryNoParams()';

update sys_job set job_name = '过期预约自动关闭（close_overdue_booking）'
  where invoke_target = 'closeOverdueBookingTask.ryNoParams()';

update sys_job set job_name = '员工邀请码过期处理（expire_staff_invite）'
  where invoke_target = 'expireStaffInviteTask.ryNoParams()';

update sys_job set job_name = '定时任务日志清理（clean_job_log）'
  where invoke_target = 'cleanJobLogTask.ryNoParams()';

-- RuoYi 自带的 3 个示例任务本来就是中文，这里只补齐「（英文标识）」后缀，
-- 方便和 ryTask 的方法名对应。
update sys_job set job_name = '系统默认-无参（ryNoParams）'
  where invoke_target = 'ryTask.ryNoParams';
update sys_job set job_name = '系统默认-有参（ryParams）'
  where invoke_target = 'ryTask.ryParams(''ry'')';
update sys_job set job_name = '系统默认-多参（ryMultipleParams）'
  where invoke_target = 'ryTask.ryMultipleParams(''ry'', true, 2000L, 316.50D, 100)';
