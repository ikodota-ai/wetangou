package com.ruoyi.quartz.task;

import java.util.Date;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.biz.service.ICommissionService;

/**
 * 佣金冷静期自动结算
 *
 * <p>业务规则：佣金产生后有冷静期（默认 7 天），期内订单退款/取消
 * 不会影响推客收益。每天凌晨扫描 biz_commission，把 status='0' 且
 * create_time + settleDays <= NOW 的记录置为 status='1'、settle_time=NOW，
 * 再把同批次记录按 distributor_id 分组扣减 frozenAmount / 增加 availableAmount。</p>
 *
 * <p>Quartz 调用：bean 名 settleCommissionTask.ryNoParams()，无参。
 * 默认 Cron：每天 03:00（生产环境按 sys_job 表为准）。</p>
 *
 * <p>TODO（下一轮）：
 * 1. 佣金产生（commission.status=0）时同步推客 frozenAmount += amount
 * 2. 订单退款回调 → commission.status=2，已结算过则 availableAmount -= amount
 * 3. 失败邮件 / 钉钉告警
 * </p>
 */
@Component("settleCommissionTask")
public class SettleCommissionTask
{
    private static final Logger log = LoggerFactory.getLogger(SettleCommissionTask.class);

    @Autowired
    private ICommissionService commissionService;

    /**
     * 冷静期天数
     * 后续从 biz_commission_rule 全局默认值读，本期硬编码 7
     */
    private static final int DEFAULT_SETTLE_DAYS = 7;

    @Transactional(rollbackFor = Exception.class)
    public void ryNoParams()
    {
        // 取与 settleExpiredCommissions 完全一致的时间戳，避免
        // linkSettlementToDistributor 用任务开始前的 before 找不到刚写入的 settle_time
        Date now = com.ruoyi.common.utils.DateUtils.getNowDate();
        int rows = commissionService.settleExpiredCommissions(DEFAULT_SETTLE_DAYS, now);
        int distributors = 0;
        if (rows > 0)
        {
            // 同一个事务内：先 settle（写 status=1 + settle_time），再联动推客金额
            distributors = commissionService.linkSettlementToDistributor(now);
        }
        log.info("[SettleCommissionTask] 冷静期到期结算 rows={} distributors={} settleDays={}",
                rows, distributors, DEFAULT_SETTLE_DAYS);
    }
}
