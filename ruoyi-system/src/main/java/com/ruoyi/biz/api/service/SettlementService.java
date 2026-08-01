package com.ruoyi.biz.api.service;

import java.math.BigDecimal;
import java.util.Calendar;
import java.util.Date;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.biz.domain.Commission;
import com.ruoyi.biz.domain.CommissionRule;
import com.ruoyi.biz.domain.Distributor;
import com.ruoyi.biz.domain.Withdraw;
import com.ruoyi.biz.service.ICommissionService;
import com.ruoyi.biz.service.ICommissionRuleService;
import com.ruoyi.biz.service.IDistributorService;
import com.ruoyi.biz.service.IWithdrawService;

/**
 * 佣金/提现资金结算服务
 * - 佣金冷静期结算：待结算(0) 且超过冷静期 → 已结算(1)，冻结转可提现
 * - 提现审核：通过(1) 计入已提现；驳回(2) 回退可提现余额
 *
 * @author dytuangou
 */
@Service
public class SettlementService
{
    private static final Logger log = LoggerFactory.getLogger(SettlementService.class);

    @Autowired
    private ICommissionService commissionService;

    @Autowired
    private ICommissionRuleService commissionRuleService;

    @Autowired
    private IDistributorService distributorService;

    @Autowired
    private IWithdrawService withdrawService;

    /**
     * 结算到期佣金：将超过冷静期的待结算佣金置为已结算，并把对应推客的冻结金额转为可提现。
     *
     * @return 本次结算的佣金笔数
     */
    @Transactional
    public int settleMaturedCommissions()
    {
        Commission query = new Commission();
        query.setStatus("0");
        List<Commission> pending = commissionService.selectCommissionList(query);
        Date now = new Date();
        int settled = 0;
        for (Commission c : pending)
        {
            int coolingDays = resolveCoolingDays(c);
            Date base = c.getCreateTime() == null ? now : c.getCreateTime();
            Calendar cal = Calendar.getInstance();
            cal.setTime(base);
            cal.add(Calendar.DAY_OF_MONTH, coolingDays);
            if (cal.getTime().after(now))
            {
                continue; // 未到结算时间
            }
            c.setStatus("1");
            c.setSettleTime(now);
            commissionService.updateCommission(c);

            Distributor d = distributorService.selectDistributorByDistributorId(c.getDistributorId());
            if (d != null)
            {
                BigDecimal amount = nz(c.getAmount());
                d.setFrozenAmount(max0(nz(d.getFrozenAmount()).subtract(amount)));
                d.setAvailableAmount(nz(d.getAvailableAmount()).add(amount));
                distributorService.updateDistributor(d);
            }
            settled++;
        }
        if (settled > 0)
        {
            log.info("[Settlement] 结算到期佣金 {} 笔", settled);
        }
        return settled;
    }

    /**
     * 提现审核通过：置成功，累计已提现金额（申请时已扣减可提现，无需再扣）。
     */
    @Transactional
    public void approveWithdraw(Long withdrawId)
    {
        Withdraw w = loadProcessing(withdrawId);
        w.setStatus("1");
        w.setFinishTime(new Date());
        withdrawService.updateWithdraw(w);

        Distributor d = distributorService.selectDistributorByDistributorId(w.getDistributorId());
        if (d != null)
        {
            d.setWithdrawAmount(nz(d.getWithdrawAmount()).add(nz(w.getAmount())));
            distributorService.updateDistributor(d);
        }
    }

    /**
     * 提现审核驳回：置失败，把冻结在提现中的金额退回可提现余额。
     */
    @Transactional
    public void rejectWithdraw(Long withdrawId, String reason)
    {
        Withdraw w = loadProcessing(withdrawId);
        w.setStatus("2");
        w.setFailReason(reason);
        w.setFinishTime(new Date());
        withdrawService.updateWithdraw(w);

        Distributor d = distributorService.selectDistributorByDistributorId(w.getDistributorId());
        if (d != null)
        {
            d.setAvailableAmount(nz(d.getAvailableAmount()).add(nz(w.getAmount())));
            distributorService.updateDistributor(d);
        }
    }

    private Withdraw loadProcessing(Long withdrawId)
    {
        Withdraw w = withdrawService.selectWithdrawByWithdrawId(withdrawId);
        if (w == null)
        {
            throw new ServiceException("提现记录不存在");
        }
        if (!"0".equals(w.getStatus()))
        {
            throw new ServiceException("该提现记录不是处理中状态，无法操作");
        }
        return w;
    }

    private int resolveCoolingDays(Commission c)
    {
        // 优先匹配佣金规则中的结算冷静期，默认7天
        CommissionRule query = new CommissionRule();
        query.setStatus("0");
        List<CommissionRule> rules = commissionRuleService.selectCommissionRuleList(query);
        int best = 7;
        int bestScore = -1;
        for (CommissionRule r : rules)
        {
            int score = 0;
            if (r.getStoreId() != null && r.getStoreId() != 0L)
            {
                if (!r.getStoreId().equals(c.getStoreId()))
                {
                    continue;
                }
                score += 2;
            }
            if (score > bestScore && r.getSettleDays() != null)
            {
                bestScore = score;
                best = r.getSettleDays();
            }
        }
        return best;
    }

    private BigDecimal nz(BigDecimal v)
    {
        return v == null ? BigDecimal.ZERO : v;
    }

    private BigDecimal max0(BigDecimal v)
    {
        return v.compareTo(BigDecimal.ZERO) < 0 ? BigDecimal.ZERO : v;
    }
}
