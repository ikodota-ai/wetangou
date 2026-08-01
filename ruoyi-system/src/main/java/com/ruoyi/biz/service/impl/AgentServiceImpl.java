package com.ruoyi.biz.service.impl;

import java.math.BigDecimal;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.domain.Agent;
import com.ruoyi.biz.mapper.AgentMapper;
import com.ruoyi.biz.service.IAgentService;
import com.ruoyi.common.core.domain.model.TenantContext;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.common.utils.TenantContextHolder;

/**
 * 代理商Service业务层处理
 *
 * @author dytuangou
 */
@Service
public class AgentServiceImpl implements IAgentService
{
    @Autowired
    private AgentMapper agentMapper;

    /**
     * 查询代理商
     */
    @Override
    public Agent selectAgentByAgentId(Long agentId)
    {
        checkAgentDataScope(agentId);
        Agent a = agentMapper.selectAgentByAgentId(agentId);
        if (a != null)
        {
            a.setUsedStoreCount(agentMapper.countStoresByAgentId(agentId));
        }
        return a;
    }

    /**
     * 查询代理商列表：代理商账号仅可见自己，商户账号不可见
     */
    @Override
    public List<Agent> selectAgentList(Agent agent)
    {
        TenantContext context = TenantContextHolder.get();
        if (context != null && context.isAgent())
        {
            agent.setAgentId(context.getAgentId());
        }
        else if (context != null && context.isMerchant())
        {
            throw new ServiceException("没有权限访问代理商数据");
        }
        List<Agent> list = agentMapper.selectAgentList(agent);
        // 列表场景下为每个代理商计算当前已用门店数
        if (list != null)
        {
            for (Agent a : list)
            {
                a.setUsedStoreCount(agentMapper.countStoresByAgentId(a.getAgentId()));
            }
        }
        return list;
    }



    /**
     * 新增代理商（仅平台账号）
     */
    @Override
    public int insertAgent(Agent agent)
    {
        checkPlatformOnly();
        if (StringUtils.isEmpty(agent.getAgentNo()))
        {
            agent.setAgentNo("AG" + System.currentTimeMillis());
        }
        if (StringUtils.isEmpty(agent.getStatus()))
        {
            agent.setStatus("0");
        }
        if (agent.getUsedQuota() == null)
        {
            agent.setUsedQuota(0);
        }
        if (agent.getPaidAmount() == null)
        {
            agent.setPaidAmount(BigDecimal.ZERO);
        }
        agent.setCreateBy(SecurityUtils.getUsername());
        return agentMapper.insertAgent(agent);
    }

    /**
     * 修改代理商：代理商账号只能改联系方式，额度与有效期由平台控制
     */
    @Override
    public int updateAgent(Agent agent)
    {
        checkAgentDataScope(agent.getAgentId());
        TenantContext context = TenantContextHolder.get();
        if (context != null && !context.isPlatform())
        {
            agent.setMerchantQuota(null);
            agent.setExpireTime(null);
            agent.setPaidAmount(null);
            agent.setUsedQuota(null);
            agent.setStatus(null);
        }
        agent.setUpdateBy(SecurityUtils.getUsername());
        return agentMapper.updateAgent(agent);
    }

    /**
     * 批量删除代理商（仅平台账号，逻辑删除）
     */
    @Override
    public int deleteAgentByAgentIds(Long[] agentIds)
    {
        checkPlatformOnly();
        return agentMapper.deleteAgentByAgentIds(agentIds);
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
     * 代理商账号只能访问自己的数据
     */
    private void checkAgentDataScope(Long agentId)
    {
        TenantContext context = TenantContextHolder.get();
        if (context == null || context.isPlatform() || agentId == null)
        {
            return;
        }
        if (context.isAgent() && agentId.equals(context.getAgentId()))
        {
            return;
        }
        throw new ServiceException("没有权限访问该代理商数据");
    }
}
