package com.ruoyi.quartz.task;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.biz.service.ICommissionRuleService;
import com.ruoyi.biz.service.ICommissionService;

/**
 * 佣金冷静期自动结算
 * <p>
 * 业务规则：佣金产生后有冷静期（CommissionRule.settleDays，默认 7 天），期内订单退款/取消
 * 不会影响推客收益。每天凌晨扫描 biz_commission，把 status='0' 且 create_time + settleDays <= NOW
 * 的记录置为 status='1'、settle_time=NOW。
 * <p>
 * Quartz 调用：bean 名 settleCommissionTask.ryNoParams()，无参
 * 默认 Cron：每天 03:00（生产环境按 sys_job 表为准）
 * <p>
 * TODO:
 * 1. 推客 availableAmount / frozenAmount 在订单完成（commission.status 变为 0）时入冻结，
 *    当前未实现「commission 写入时同步推客 frozenAmount」链路；
 * 2. 结算后 frozenAmount -= amount、availableAmount += amount 需在 DistributorService 同步执行（当前仅结算 commission.status）；
 * 3. 多商户场景下按 merchant_id 维度分组结算或全平台按规则维度遍历；
 * 4. 失败重试：quartz 触发后写 sys_job_log，失败邮件告警。
 */
@Component("settleCommissionTask")
public class SettleCommissionTask
{
    @Autowired
    private ICommissionService commissionService;

    @Autowired
    private ICommissionRuleService commissionRuleService;

    public void ryNoParams()
    {
        // 默认冷静期 7 天；按规则集中结算的逻辑留 TODO
        int defaultSettleDays = 7;
        int rows = commissionService.settleExpiredCommissions(defaultSettleDays);
        System.out.println(StringUtils.format("[SettleCommissionTask] 冷静期到期结算 rows={} settleDays={}", rows, defaultSettleDays));
    }
}
