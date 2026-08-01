package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.biz.domain.AgentFee;
import com.ruoyi.common.annotation.IgnoreTenant;

/**
 * 代理商缴费Mapper接口
 *
 * <p>平台级表，不参与 merchant_id 过滤，可见范围由服务层按账号类型控制。</p>
 *
 * @author dytuangou
 */
@IgnoreTenant
public interface AgentFeeMapper
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
     * 批量删除代理商缴费
     *
     * @param feeIds 需要删除的数据主键集合
     * @return 结果
     */
    public int deleteAgentFeeByFeeIds(Long[] feeIds);
}
