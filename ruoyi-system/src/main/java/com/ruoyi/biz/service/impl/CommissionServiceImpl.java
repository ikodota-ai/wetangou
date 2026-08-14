package com.ruoyi.biz.service.impl;

import java.math.BigDecimal;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import com.ruoyi.common.utils.DateUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.mapper.CommissionMapper;
import com.ruoyi.biz.mapper.DistributorMapper;
import com.ruoyi.biz.domain.Commission;
import com.ruoyi.biz.service.ICommissionService;

/**
 * 佣金明细Service业务层处理
 *
 * @author dytuangou
 * @date 2026-07-24
 */
@Service
public class CommissionServiceImpl implements ICommissionService
{
    @Autowired
    private CommissionMapper commissionMapper;

    @Autowired
    private DistributorMapper distributorMapper;

    @Override
    public Commission selectCommissionByCommissionId(Long commissionId)
    {
        return commissionMapper.selectCommissionByCommissionId(commissionId);
    }

    @Override
    public List<Commission> selectCommissionList(Commission commission)
    {
        return commissionMapper.selectCommissionList(commission);
    }

    @Override
    public int insertCommission(Commission commission)
    {
        commission.setCreateTime(DateUtils.getNowDate());
        int rows = commissionMapper.insertCommission(commission);
        // A2 修复：佣金产生时同步推客 frozen_amount += amount
        // （冷静期到期由 SettleCommissionTask 把 frozen → available）
        if (rows > 0 && commission.getDistributorId() != null && commission.getAmount() != null)
        {
            java.util.Map<String, Object> p = new java.util.HashMap<>();
            p.put("distributorId", commission.getDistributorId());
            p.put("delta", commission.getAmount());
            distributorMapper.incFrozenAmount(p);
        }
        return rows;
    }

    @Override
    public int updateCommission(Commission commission)
    {
        commission.setUpdateTime(DateUtils.getNowDate());
        return commissionMapper.updateCommission(commission);
    }

    @Override
    public int settleExpiredCommissions(int settleDays)
    {
        return settleExpiredCommissions(settleDays, DateUtils.getNowDate());
    }

    @Override
    public int settleExpiredCommissions(int settleDays, java.util.Date now)
    {
        if (now == null) now = DateUtils.getNowDate();
        Map<String, Object> params = new HashMap<>();
        params.put("settleDays", settleDays);
        params.put("now", now);
        return commissionMapper.settleExpiredCommissions(params);
    }

    /**
     * 把指定结算时间的佣金联动到推客的冻结/可用金额
     */
    @Override
    public int linkSettlementToDistributor(Date settleTime)
    {
        if (settleTime == null)
        {
            return 0;
        }
        // 关键修复：MySQL DATETIME 列只存秒精度，Java Date 毫秒精度，写入时
        // 0.053s 会被截断为 0.000s，再用毫秒值匹配会漏掉刚写入的记录。
        // 这里把 settleTime 截断到秒，让 selectSettleGroupsByTime / markSettledByTime
        // 范围查询能命中刚刚 settleExpiredCommissions 写入的 settle_time。
        Date secondPrecision = com.ruoyi.common.utils.DateUtils.truncateToSeconds(settleTime);
        List<Map<String, Object>> groups = commissionMapper.selectSettleGroupsByTime(secondPrecision);
        int affectedDistributors = 0;
        Map<String, Object> params = new HashMap<>();
        for (Map<String, Object> g : groups)
        {
            Long distributorId = ((Number) g.get("distributorId")).longValue();
            BigDecimal total = new BigDecimal(g.get("totalAmount").toString());
            if (distributorId == null || total == null || total.signum() == 0)
            {
                continue;
            }
            params.put("distributorId", distributorId);
            params.put("delta", total.negate());
            distributorMapper.incFrozenAmount(params);
            params.put("delta", total);
            distributorMapper.incAvailableAmount(params);
            affectedDistributors++;
        }
        commissionMapper.markSettledByTime(secondPrecision);
        return affectedDistributors;
    }

    @Override
    public java.util.List<java.util.Map<String, Object>> sumByMerchantIds(java.util.List<Long> merchantIds, java.util.Date beginTime, java.util.Date endTime)
    {
        java.util.Map<String, Object> params = new java.util.HashMap<>();
        params.put("merchantIds", merchantIds);
        params.put("beginTime", beginTime);
        params.put("endTime", endTime);
        return commissionMapper.sumByMerchantIds(params);
    }

    @Override
    public java.util.Map<String, Object> sumAgentOverview(java.util.List<Long> merchantIds, java.util.Date beginTime, java.util.Date endTime)
    {
        java.util.Map<String, Object> params = new java.util.HashMap<>();
        params.put("merchantIds", merchantIds);
        params.put("merchantIdsEmpty", merchantIds == null || merchantIds.isEmpty());
        params.put("beginTime", beginTime);
        params.put("endTime", endTime);
        java.util.Map<String, Object> r = commissionMapper.sumAgentOverview(params);
        if (r == null) {
            r = new java.util.HashMap<>();
            r.put("pendingAmount", java.math.BigDecimal.ZERO);
            r.put("settledAmount", java.math.BigDecimal.ZERO);
            r.put("totalAmount", java.math.BigDecimal.ZERO);
            r.put("commissionCount", 0L);
        }
        return r;
    }

    @Override
    public int deleteCommissionByCommissionIds(Long[] commissionIds)
    {
        return commissionMapper.deleteCommissionByCommissionIds(commissionIds);
    }

    @Override
    public int deleteCommissionByCommissionId(Long commissionId)
    {
        return commissionMapper.deleteCommissionByCommissionId(commissionId);
    }
}
