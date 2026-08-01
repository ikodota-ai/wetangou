package com.ruoyi.biz.mapper;

import java.math.BigDecimal;
import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.biz.domain.Agent;
import com.ruoyi.common.annotation.IgnoreTenant;

/**
 * 代理商Mapper接口
 *
 * <p>代理商表不参与 merchant_id 过滤，可见范围由服务层按账号类型控制。</p>
 *
 * @author dytuangou
 */
@IgnoreTenant
public interface AgentMapper
{
    /**
     * 查询代理商
     *
     * @param agentId 代理商主键
     * @return 代理商
     */
    public Agent selectAgentByAgentId(Long agentId);

    /**
     * 查询代理商列表
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
     * @param agentIds 需要删除的数据主键集合
     * @return 结果
     */
    public int deleteAgentByAgentIds(Long[] agentIds);

    /**
     * 已用商户额度+1
     *
     * @param agentId 代理商ID
     * @return 结果
     */
    public int increaseUsedQuota(Long agentId);

    /**
     * 缴费确认后累加额度、延长有效期与累计缴费金额
     *
     * @param agentId 代理商ID
     * @param quotaAdd 增加的商户额度
     * @param months 延长月数
     * @param amount 缴费金额
     * @return 结果
     */
    public int applyFee(@Param("agentId") Long agentId, @Param("quotaAdd") Integer quotaAdd,
            @Param("months") Integer months, @Param("amount") BigDecimal amount);
}
