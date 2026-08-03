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
        return commissionMapper.insertCommission(commission);
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
        Map<String, Object> params = new HashMap<>();
        params.put("settleDays", settleDays);
        params.put("now", DateUtils.getNowDate());
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
        List<Map<String, Object>> groups = commissionMapper.selectSettleGroupsByTime(settleTime);
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
        commissionMapper.markSettledByTime(settleTime);
        return affectedDistributors;
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
