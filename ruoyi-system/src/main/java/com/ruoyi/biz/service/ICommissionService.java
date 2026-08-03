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

    public int deleteCommissionByCommissionIds(Long[] commissionIds);

    public int deleteCommissionByCommissionId(Long commissionId);
}
