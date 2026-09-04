-- ============================================================================
-- 业务定时任务补齐（2026-09-04）
--
-- 背景：项目跑到现在只有 1 个业务定时任务（settleCommissionTask 佣金冷静期
-- 结算），一批「到了时间就该自动发生」的状态流转全靠人工或压根没人管。
-- 实测本地库的积压量：
--
--   biz_order              status='0' 且下单超 30 分钟          116 笔
--   biz_pay_bill           status in ('0','1') 且超 30 分钟       9 笔
--   biz_booking            status='0' 且 booking_date < 今天     30 个
--   biz_merchant_staff_invite  status='0' 且 expire_at < now()   52 个
--   sys_job_log                                                75808 行
--
-- 前两项不只是「列表里脏」——它们扣着的代金券全是废的：
-- VoucherUsageService.assertNotHeld 把待支付也算券被占用（这个口径是对的，
-- 否则一张券能在 N 个待付单里各抵一次），于是用户下单不付，那张券就永久
-- 锁死，之后每次选券都弹「已用于另一笔待支付订单」。手动取消入口虽然已经
-- 有了，但没人会为解锁一张券去翻半年前的废单。
--
-- 导入：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/upgrade/biz_quartz_jobs_20260904.sql
-- 幂等：可重复执行
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. 参数（后台「系统管理 → 参数设置」可改，改后要清 Redis 缓存 sys_config:<key>）
--
-- 阈值不硬编码在代码里：大促时运营会想把待付超时放宽、排障时想多留几天日志，
-- 硬编码就得改代码重新发版。TaskConfigResolver 读不到时回落代码内默认值。
-- ----------------------------------------------------------------------------
insert into sys_config (config_name, config_key, config_value, config_type, create_by, create_time, remark)
select '订单待支付超时分钟', 'biz.order.unpaidTimeoutMinutes', '30', 'Y', 'admin', sysdate(),
       '下单后多少分钟未支付自动取消并释放代金券占用，默认30'
from dual
where not exists (select 1 from sys_config where config_key = 'biz.order.unpaidTimeoutMinutes');

insert into sys_config (config_name, config_key, config_value, config_type, create_by, create_time, remark)
select '买单待完成超时分钟', 'biz.bill.pendingTimeoutMinutes', '30', 'Y', 'admin', sysdate(),
       '买单发起后多少分钟未完成（待确认/待支付）自动取消并释放代金券占用，默认30'
from dual
where not exists (select 1 from sys_config where config_key = 'biz.bill.pendingTimeoutMinutes');

insert into sys_config (config_name, config_key, config_value, config_type, create_by, create_time, remark)
select '调度日志保留天数', 'sys.jobLog.keepDays', '30', 'Y', 'admin', sysdate(),
       'sys_job_log 只保留最近多少天，默认30。不要设太小，失败堆栈是排障唯一线索'
from dual
where not exists (select 1 from sys_config where config_key = 'sys.jobLog.keepDays');

-- ----------------------------------------------------------------------------
-- 2. 四个 job
--
-- misfire_policy='3'（放弃执行）：这几个任务都是「扫全量补状态」的幂等操作，
-- 服务重启期间错过的那次不用补跑，下一个周期自然会把积压一起处理掉。
-- 补跑（'2'）反而会在重启后瞬间连打好几次。
--
-- concurrent='1'（禁止并发）：全表扫描 + 批量 update，并发跑只会互相锁行。
-- ----------------------------------------------------------------------------

-- 每 5 分钟：待付订单 / 待完成买单超时取消。5 分钟是为了让券尽快解锁 ——
-- 用户放弃一单后马上换张券重下是常见操作，等 1 小时体验上等于券丢了。
insert into sys_job (job_name, job_group, invoke_target, cron_expression, misfire_policy, concurrent, status, create_by, create_time, remark)
select 'cancel_timeout_order_task', 'DEFAULT', 'cancelTimeoutOrderTask.ryNoParams()', '0 0/5 * * * ?', '3', '1', '0', 'admin', sysdate(),
       '待支付订单/待完成买单超时自动取消，释放被废单锁死的代金券'
from dual
where not exists (select 1 from sys_job where job_name = 'cancel_timeout_order_task');

-- 每天 00:10：过期预约场次关闭。跨过零点再跑，避免恰好卡在日期切换瞬间
-- 把今天的场次误判成过期。
insert into sys_job (job_name, job_group, invoke_target, cron_expression, misfire_policy, concurrent, status, create_by, create_time, remark)
select 'close_overdue_booking_task', 'DEFAULT', 'closeOverdueBookingTask.ryNoParams()', '0 10 0 * * ?', '3', '1', '0', 'admin', sysdate(),
       '预约日期已过去却还停在开放中的场次自动关闭，其下已报名记录一并取消'
from dual
where not exists (select 1 from sys_job where job_name = 'close_overdue_booking_task');

-- 每小时 05 分：员工邀请码过期失效。邀请码有效期按小时/天计，不需要更密。
insert into sys_job (job_name, job_group, invoke_target, cron_expression, misfire_policy, concurrent, status, create_by, create_time, remark)
select 'expire_staff_invite_task', 'DEFAULT', 'expireStaffInviteTask.ryNoParams()', '0 5 * * * ?', '3', '1', '0', 'admin', sysdate(),
       '过期员工邀请码置为已失效（expireOverdue 早就写好但从来没人调用）'
from dual
where not exists (select 1 from sys_job where job_name = 'expire_staff_invite_task');

-- 每天 04:00：调度日志清理。晚于 settle_commission_task 的 03:00，
-- 让当天的结算日志先落完再清历史。
insert into sys_job (job_name, job_group, invoke_target, cron_expression, misfire_policy, concurrent, status, create_by, create_time, remark)
select 'clean_job_log_task', 'DEFAULT', 'cleanJobLogTask.ryNoParams()', '0 0 4 * * ?', '3', '1', '0', 'admin', sysdate(),
       '按 sys.jobLog.keepDays 清理 sys_job_log，只保留近期失败堆栈'
from dual
where not exists (select 1 from sys_job where job_name = 'clean_job_log_task');

-- ----------------------------------------------------------------------------
-- 3. 修 settle_commission_task 的 Cron
--
-- 仓库里 sql/biz_commission_settle_job.sql 写的是 '0 0 3 * * ?'（每天凌晨 3 点），
-- 但库里实际是 '0/30 * * * * ?' —— 当年为了验证结算逻辑手工调成每 30 秒一跑，
-- 之后没还原。这就是 sys_job_log 75808 行的全部来源（一天 2880 行，
-- 而且 75808 行里一条别的 job 都没有）。
--
-- 佣金冷静期是按天算的，每 30 秒扫一遍毫无意义，只是在空转 + 刷日志。
-- 只在确认它还是调试值时才改，别覆盖运维后来有意调整过的 Cron。
-- ----------------------------------------------------------------------------
update sys_job set cron_expression = '0 0 3 * * ?', update_by = 'admin', update_time = sysdate()
where job_name = 'settle_commission_task' and cron_expression = '0/30 * * * * ?';

-- ----------------------------------------------------------------------------
-- 校验
-- ----------------------------------------------------------------------------
select job_name, cron_expression, misfire_policy, concurrent, status from sys_job order by job_id;
select config_key, config_value from sys_config
where config_key in ('biz.order.unpaidTimeoutMinutes', 'biz.bill.pendingTimeoutMinutes', 'sys.jobLog.keepDays');
