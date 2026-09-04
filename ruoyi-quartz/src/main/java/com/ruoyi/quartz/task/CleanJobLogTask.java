package com.ruoyi.quartz.task;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import com.ruoyi.quartz.service.ISysJobLogService;

/**
 * 调度日志定期清理
 *
 * <p>为什么必须有：每个 job 每次执行都会往 sys_job_log 插一行，而这张表
 * RuoYi 只给了「手工点清空」（truncate）这一个出口，没人会天天去点。
 * 实测本地库 75808 行，全部来自 settle_commission_task —— 因为那个 job 的
 * Cron 被历史调试改成了 {@code 0/30 * * * * ?}（每 30 秒一跑），
 * 一天就是 2880 行。表越大，后台「调度日志」页的分页查询越慢，
 * 生产上还白占 RDS 空间。</p>
 *
 * <p>用按天保留而不是 truncate：出问题时最近几天的失败堆栈是唯一线索，
 * 一刀切光就没法排查了。</p>
 *
 * <p>Quartz 调用：{@code cleanJobLogTask.ryNoParams()}，建议 Cron
 * 每天 04:00（{@code 0 0 4 * * ?}）—— 放在业务低峰，且晚于
 * settleCommissionTask 的 03:00，让当天的结算日志先落完。</p>
 *
 * @author dytuangou
 */
@Component("cleanJobLogTask")
public class CleanJobLogTask
{
    private static final Logger log = LoggerFactory.getLogger(CleanJobLogTask.class);

    /** 参数key：调度日志保留天数 */
    private static final String KEY_KEEP_DAYS = "sys.jobLog.keepDays";

    /** 默认保留 30 天：够覆盖「上个月那天的任务是不是没跑」这类回溯 */
    private static final int DEFAULT_KEEP_DAYS = 30;

    @Autowired
    private ISysJobLogService jobLogService;

    @Autowired
    private TaskConfigResolver configResolver;

    public void ryNoParams()
    {
        int keepDays = configResolver.getPositiveInt(KEY_KEEP_DAYS, DEFAULT_KEEP_DAYS);
        int rows = jobLogService.deleteJobLogBeforeDays(keepDays);
        log.info("[CleanJobLogTask] 清理调度日志 rows={} keepDays={}", rows, keepDays);
    }
}
