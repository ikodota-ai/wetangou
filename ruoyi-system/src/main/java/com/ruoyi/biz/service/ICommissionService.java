package com.ruoyi.biz.service;

import java.util.Date;
import java.util.List;
import com.ruoyi.biz.domain.Commission;

/**
 * 佣金明细Service接口
 *
 * @author dytuangou
 * @date 2026-07-24
 */
public interface ICommissionService
{
    public Commission selectCommissionByCommissionId(Long commissionId);

    public List<Commission> selectCommissionList(Commission commission);

    public int insertCommission(Commission commission);

    public int updateCommission(Commission commission);

    /**
     * 结算冷静期到期的佣金
     */
    public int settleExpiredCommissions(int settleDays);

    /**
     * 与上面相同，但用调用方传入的 now 时间戳（避免 linkSettlementToDistributor 查不到刚写入的 settle_time）
     */
    public int settleExpiredCommissions(int settleDays, java.util.Date now);

    /**
     * 把指定结算时间的佣金联动到推客的 frozenAmount / availableAmount
     */
    public int linkSettlementToDistributor(Date settleTime);

    /**
     * C1 代理商佣金概览：按 merchantId 集合 + 时间范围聚合
     */
    public java.util.List<java.util.Map<String, Object>> sumByMerchantIds(java.util.List<Long> merchantIds, java.util.Date beginTime, java.util.Date endTime);

    /**
     * C1 代理商佣金概览汇总：本月总佣金/已结算/待结算
     */
    public java.util.Map<String, Object> sumAgentOverview(java.util.List<Long> merchantIds, java.util.Date beginTime, java.util.Date endTime);

    public int deleteCommissionByCommissionIds(Long[] commissionIds);

    public int deleteCommissionByCommissionId(Long commissionId);
}
