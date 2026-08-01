package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.AgentFee;

/**
 * 代理商缴费Service接口
 *
 * @author dytuangou
 */
public interface IAgentFeeService
{
    /**
     * 查询代理商缴费
     *
     * @param feeId 缴费主键
     * @return 代理商缴费
     */
    public AgentFee selectAgentFeeByFeeId(Long feeId);

    /**
     * 查询代理商缴费列表
     *
     * @param agentFee 代理商缴费
     * @return 代理商缴费集合
     */
    public List<AgentFee> selectAgentFeeList(AgentFee agentFee);

    /**
     * 新增代理商缴费
     *
     * @param agentFee 代理商缴费
     * @return 结果
     */
    public int insertAgentFee(AgentFee agentFee);

    /**
     * 修改代理商缴费
     *
     * @param agentFee 代理商缴费
     * @return 结果
     */
    public int updateAgentFee(AgentFee agentFee);

    /**
     * 审核缴费单：确认后增加代理商额度与有效期
     *
     * @param feeId 缴费ID
     * @param status 目标状态（1已确认 2已驳回）
     * @return 结果
     */
    public int auditAgentFee(Long feeId, String status);

    /**
     * 批量删除代理商缴费
     *
     * @param feeIds 需要删除的数据主键集合
     * @return 结果
     */
    public int deleteAgentFeeByFeeIds(Long[] feeIds);
}
