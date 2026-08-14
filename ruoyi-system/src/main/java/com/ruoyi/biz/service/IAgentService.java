package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.Agent;

/**
 * 代理商Service接口
 *
 * @author dytuangou
 */
public interface IAgentService
{
    /**
     * 查询代理商
     *
     * @param agentId 代理商主键
     * @return 代理商
     */
    public Agent selectAgentByAgentId(Long agentId);

    /**
     * 查询代理商列表（代理商账号仅可见自己）
     *
     * @param agent 代理商
     * @return 代理商集合
     */
    public List<Agent> selectAgentList(Agent agent);

    /**
     * 新增代理商
     *
     * @param agent 代理商
     * @return 结果
     */
    public int insertAgent(Agent agent);

    /**
     * 修改代理商
     *
     * @param agent 代理商
     * @return 结果
     */
    public int updateAgent(Agent agent);

    /**
     * 批量删除代理商
     *
     * @param agentIds 需要删除的代理商主键集合
     * @return 结果
     */
    public int deleteAgentByAgentIds(Long[] agentIds);

    /**
     * 校验当前账号是否有权访问该代理商数据
     * 平台 / 未登录 / agentId 为空 → 放行；代理商账号只能访问自己
     */
    public void checkAgentDataScope(Long agentId);
}
