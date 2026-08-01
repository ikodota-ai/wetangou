package com.ruoyi.biz.api.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Date;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.biz.domain.Order;
import com.ruoyi.biz.domain.Commission;
import com.ruoyi.biz.domain.CommissionRule;
import com.ruoyi.biz.domain.Distributor;
import com.ruoyi.biz.service.ICommissionService;
import com.ruoyi.biz.service.ICommissionRuleService;
import com.ruoyi.biz.service.IDistributorService;

/**
 * 小程序-佣金结算业务（按可配规则计算分销佣金）
 *
 * @author dytuangou
 */
@Service
public class ApiCommissionService
{
    @Autowired
    private ICommissionService commissionService;

    @Autowired
    private ICommissionRuleService commissionRuleService;

    @Autowired
    private IDistributorService distributorService;

    /**
     * 订单支付成功后结算佣金给分销推客
     */
    @Transactional
    public void settleForOrder(Order order)
    {
        if (order.getDistributorId() == null)
        {
            return;
        }
        Distributor distributor = distributorService.selectDistributorByDistributorId(order.getDistributorId());
        if (distributor == null || !"0".equals(distributor.getStatus()))
        {
            return;
        }
        BigDecimal rate = matchRate(order, distributor);
        if (rate.compareTo(BigDecimal.ZERO) <= 0)
        {
            return;
        }
        BigDecimal base = order.getPayAmount() == null ? BigDecimal.ZERO : order.getPayAmount();
        BigDecimal amount = base.multiply(rate).divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
        if (amount.compareTo(BigDecimal.ZERO) <= 0)
        {
            return;
        }

        Commission commission = new Commission();
        commission.setDistributorId(distributor.getDistributorId());
        commission.setOrderId(order.getOrderId());
        commission.setStoreId(order.getStoreId());
        commission.setAmount(amount);
        commission.setRate(rate);
        commission.setStatus("0");
        commission.setCreateTime(new Date());
        commissionService.insertCommission(commission);

        // 累计佣金进入冻结（待结算冷静期）
        distributor.setTotalCommission(nz(distributor.getTotalCommission()).add(amount));
        distributor.setFrozenAmount(nz(distributor.getFrozenAmount()).add(amount));
        distributorService.updateDistributor(distributor);
    }

    /**
     * 匹配佣金比例：优先级 商品 > 分类 > 门店 > 全平台，且匹配推客等级
     */
    private BigDecimal matchRate(Order order, Distributor distributor)
    {
        CommissionRule query = new CommissionRule();
        query.setStatus("0");
        List<CommissionRule> rules = commissionRuleService.selectCommissionRuleList(query);
        CommissionRule best = null;
        int bestScore = -1;
        for (CommissionRule rule : rules)
        {
            if (rule.getLevel() != null && distributor.getLevel() != null
                    && !rule.getLevel().equals(distributor.getLevel()))
            {
                continue;
            }
            int score = 0;
            if (rule.getProductId() != null)
            {
                if (!rule.getProductId().equals(order.getProductId()))
                {
                    continue;
                }
                score += 4;
            }
            if (rule.getStoreId() != null && rule.getStoreId() != 0L)
            {
                if (!rule.getStoreId().equals(order.getStoreId()))
                {
                    continue;
                }
                score += 2;
            }
            if (score > bestScore)
            {
                bestScore = score;
                best = rule;
            }
        }
        return best == null || best.getRate() == null ? BigDecimal.ZERO : best.getRate();
    }

    private BigDecimal nz(BigDecimal v)
    {
        return v == null ? BigDecimal.ZERO : v;
    }
}
