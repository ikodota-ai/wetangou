package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.biz.domain.CommissionRule;

/**
 * 佣金规则Mapper接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface CommissionRuleMapper 
{
    /**
     * 查询佣金规则
     * 
     * @param ruleId 佣金规则主键
     * @return 佣金规则
     */
    public CommissionRule selectCommissionRuleByRuleId(Long ruleId);

    /**
     * 查询佣金规则列表
     * 
     * @param commissionRule 佣金规则
     * @return 佣金规则集合
     */
    public List<CommissionRule> selectCommissionRuleList(CommissionRule commissionRule);

    /**
     * 新增佣金规则
     * 
     * @param commissionRule 佣金规则
     * @return 结果
     */
    public int insertCommissionRule(CommissionRule commissionRule);

    /**
     * 修改佣金规则
     * 
     * @param commissionRule 佣金规则
     * @return 结果
     */
    public int updateCommissionRule(CommissionRule commissionRule);

    /**
     * 删除佣金规则
     * 
     * @param ruleId 佣金规则主键
     * @return 结果
     */
    public int deleteCommissionRuleByRuleId(Long ruleId);

    /**
     * 批量删除佣金规则
     * 
     * @param ruleIds 需要删除的数据主键集合
     * @return 结果
     */
    public int deleteCommissionRuleByRuleIds(Long[] ruleIds);
}
