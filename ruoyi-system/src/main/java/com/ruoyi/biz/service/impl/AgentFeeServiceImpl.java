package com.ruoyi.biz.service.impl;

import java.math.BigDecimal;
import java.util.Date;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.biz.domain.AgentFee;
import com.ruoyi.biz.mapper.AgentFeeMapper;
import com.ruoyi.biz.mapper.AgentMapper;
import com.ruoyi.biz.service.IAgentFeeService;
import com.ruoyi.common.core.domain.model.TenantContext;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.common.utils.TenantContextHolder;

/**
 * 代理商缴费Service业务层处理
 *
 * <p>平台向代理商收费。代理商账号只能查看自己的缴费记录，
 * 登记与审核均为平台权限，审核确认后才真正增加额度与有效期。</p>
 *
 * @author dytuangou
 */
@Service
public class AgentFeeServiceImpl implements IAgentFeeService
{
    /** 待确认 */
    private static final String STATUS_PENDING = "0";

    /** 已确认 */
    private static final String STATUS_CONFIRMED = "1";

    /** 已驳回 */
    private static final String STATUS_REJECTED = "2";

    @Autowired
    private AgentFeeMapper agentFeeMapper;

    @Autowired
    private AgentMapper agentMapper;

    /**
     * 查询代理商缴费
     */
    @Override
    public AgentFee selectAgentFeeByFeeId(Long feeId)
    {
        AgentFee agentFee = agentFeeMapper.selectAgentFeeByFeeId(feeId);
        if (agentFee != null)
        {
            checkAgentScope(agentFee.getAgentId());
        }
        return agentFee;
    }

    /**
     * 查询缴费列表：代理商仅可见自己的记录，商户账号不可见
     */
    @Override
    public List<AgentFee> selectAgentFeeList(AgentFee agentFee)
    {
        TenantContext context = TenantContextHolder.get();
        if (context != null && context.isAgent())
        {
            agentFee.setAgentId(context.getAgentId());
        }
        else if (context != null && context.isMerchant())
        {
            throw new ServiceException("没有权限访问代理商缴费数据");
        }
        return agentFeeMapper.selectAgentFeeList(agentFee);
    }

    /**
     * 新增缴费单（仅平台账号登记）
     */
    @Override
    public int insertAgentFee(AgentFee agentFee)
    {
        checkPlatformOnly();
        if (agentFee.getAgentId() == null)
        {
            throw new ServiceException("请选择代理商");
        }
        if (StringUtils.isEmpty(agentFee.getFeeNo()))
        {
            agentFee.setFeeNo("AF" + System.currentTimeMillis());
        }
        if (StringUtils.isEmpty(agentFee.getStatus()))
        {
            agentFee.setStatus(STATUS_PENDING);
        }
        agentFee.setCreateBy(SecurityUtils.getUsername());
        int rows = agentFeeMapper.insertAgentFee(agentFee);
        // 登记时直接标记已确认的，同步发放额度
        if (rows > 0 && STATUS_CONFIRMED.equals(agentFee.getStatus()))
        {
            applyQuota(agentFee);
        }
        return rows;
    }

    /**
     * 修改缴费单（仅平台账号，已确认的不可再改金额与额度）
     */
    @Override
    public int updateAgentFee(AgentFee agentFee)
    {
        checkPlatformOnly();
        AgentFee origin = agentFeeMapper.selectAgentFeeByFeeId(agentFee.getFeeId());
        if (origin == null)
        {
            throw new ServiceException("缴费记录不存在");
        }
        if (STATUS_CONFIRMED.equals(origin.getStatus()))
        {
            throw new ServiceException("该缴费单已确认，额度已发放，不可修改");
        }
        // 状态变更走审核接口，避免绕过额度发放
        agentFee.setStatus(null);
        agentFee.setUpdateBy(SecurityUtils.getUsername());
        return agentFeeMapper.updateAgentFee(agentFee);
    }

    /**
     * 审核缴费单：确认后发放额度与有效期，仅允许从待确认流转
     */
    @Override
    @Transactional
    public int auditAgentFee(Long feeId, String status)
    {
        checkPlatformOnly();
        if (!STATUS_CONFIRMED.equals(status) && !STATUS_REJECTED.equals(status))
        {
            throw new ServiceException("审核状态不合法");
        }
        AgentFee origin = agentFeeMapper.selectAgentFeeByFeeId(feeId);
        if (origin == null)
        {
            throw new ServiceException("缴费记录不存在");
        }
        if (!STATUS_PENDING.equals(origin.getStatus()))
        {
            throw new ServiceException("该缴费单已审核，不可重复操作");
        }

        AgentFee update = new AgentFee();
        update.setFeeId(feeId);
        update.setStatus(status);
        update.setAuditBy(SecurityUtils.getUsername());
        update.setAuditTime(new Date());
        update.setUpdateBy(SecurityUtils.getUsername());
        int rows = agentFeeMapper.updateAgentFee(update);
        if (rows > 0 && STATUS_CONFIRMED.equals(status))
        {
            applyQuota(origin);
        }
        return rows;
    }

    /**
     * 批量删除缴费单（仅平台账号，已确认的不可删除以保留发放留痕）
     */
    @Override
    public int deleteAgentFeeByFeeIds(Long[] feeIds)
    {
        checkPlatformOnly();
        if (feeIds != null)
        {
            for (Long feeId : feeIds)
            {
                AgentFee origin = agentFeeMapper.selectAgentFeeByFeeId(feeId);
                if (origin != null && STATUS_CONFIRMED.equals(origin.getStatus()))
                {
                    throw new ServiceException("缴费单 " + origin.getFeeNo() + " 已确认，不可删除");
                }
            }
        }
        return agentFeeMapper.deleteAgentFeeByFeeIds(feeIds);
    }

    /**
     * 把缴费单上的额度与月数发放到代理商
     */
    private void applyQuota(AgentFee agentFee)
    {
        BigDecimal amount = agentFee.getAmount() == null ? BigDecimal.ZERO : agentFee.getAmount();
        agentMapper.applyFee(agentFee.getAgentId(), agentFee.getQuotaAdd(), agentFee.getMonths(), amount);
    }

    /**
     * 仅平台账号可操作
     */
    private void checkPlatformOnly()
    {
        TenantContext context = TenantContextHolder.get();
        if (context != null && !context.isPlatform())
        {
            throw new ServiceException("仅平台管理员可执行该操作");
        }
    }

    /**
     * 代理商账号只能访问自己的缴费数据
     */
    private void checkAgentScope(Long agentId)
    {
        TenantContext context = TenantContextHolder.get();
        if (context == null || context.isPlatform())
        {
            return;
        }
        if (context.isAgent() && agentId != null && agentId.equals(context.getAgentId()))
        {
            return;
        }
        throw new ServiceException("没有权限访问该缴费数据");
    }
}
