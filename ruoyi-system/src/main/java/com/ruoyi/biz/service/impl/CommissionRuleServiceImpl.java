package com.ruoyi.biz.service.impl;

import java.util.List;
import com.ruoyi.common.utils.DateUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.mapper.CommissionRuleMapper;
import com.ruoyi.biz.domain.CommissionRule;
import com.ruoyi.biz.service.ICommissionRuleService;

/**
 * 佣金规则Service业务层处理
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@Service
public class CommissionRuleServiceImpl implements ICommissionRuleService 
{
    @Autowired
    private CommissionRuleMapper commissionRuleMapper;

    /**
     * 查询佣金规则
     * 
     * @param ruleId 佣金规则主键
     * @return 佣金规则
     */
    @Override
    public CommissionRule selectCommissionRuleByRuleId(Long ruleId)
    {
        return commissionRuleMapper.selectCommissionRuleByRuleId(ruleId);
    }

    /**
     * 查询佣金规则列表
     * 
     * @param commissionRule 佣金规则
     * @return 佣金规则
     */
    @Override
    public List<CommissionRule> selectCommissionRuleList(CommissionRule commissionRule)
    {
        return commissionRuleMapper.selectCommissionRuleList(commissionRule);
    }

    /**
     * 新增佣金规则
     * 
     * @param commissionRule 佣金规则
     * @return 结果
     */
    @Override
    public int insertCommissionRule(CommissionRule commissionRule)
    {
        commissionRule.setCreateTime(DateUtils.getNowDate());
        return commissionRuleMapper.insertCommissionRule(commissionRule);
    }

    /**
     * 修改佣金规则
     * 
     * @param commissionRule 佣金规则
     * @return 结果
     */
    @Override
    public int updateCommissionRule(CommissionRule commissionRule)
    {
        commissionRule.setUpdateTime(DateUtils.getNowDate());
        return commissionRuleMapper.updateCommissionRule(commissionRule);
    }

    /**
     * 批量删除佣金规则
     * 
     * @param ruleIds 需要删除的佣金规则主键
     * @return 结果
     */
    @Override
    public int deleteCommissionRuleByRuleIds(Long[] ruleIds)
    {
        return commissionRuleMapper.deleteCommissionRuleByRuleIds(ruleIds);
    }

    /**
     * 删除佣金规则信息
     * 
     * @param ruleId 佣金规则主键
     * @return 结果
     */
    @Override
    public int deleteCommissionRuleByRuleId(Long ruleId)
    {
        return commissionRuleMapper.deleteCommissionRuleByRuleId(ruleId);
    }
}
