package com.ruoyi.biz.service.impl;

import java.util.List;
import com.ruoyi.common.utils.DateUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.mapper.CommissionMapper;
import com.ruoyi.biz.domain.Commission;
import com.ruoyi.biz.service.ICommissionService;

/**
 * 佣金明细Service业务层处理
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@Service
public class CommissionServiceImpl implements ICommissionService 
{
    @Autowired
    private CommissionMapper commissionMapper;

    /**
     * 查询佣金明细
     * 
     * @param commissionId 佣金明细主键
     * @return 佣金明细
     */
    @Override
    public Commission selectCommissionByCommissionId(Long commissionId)
    {
        return commissionMapper.selectCommissionByCommissionId(commissionId);
    }

    /**
     * 查询佣金明细列表
     * 
     * @param commission 佣金明细
     * @return 佣金明细
     */
    @Override
    public List<Commission> selectCommissionList(Commission commission)
    {
        return commissionMapper.selectCommissionList(commission);
    }

    /**
     * 新增佣金明细
     * 
     * @param commission 佣金明细
     * @return 结果
     */
    @Override
    public int insertCommission(Commission commission)
    {
        commission.setCreateTime(DateUtils.getNowDate());
        return commissionMapper.insertCommission(commission);
    }

    /**
     * 修改佣金明细
     * 
     * @param commission 佣金明细
     * @return 结果
     */
    @Override
    public int updateCommission(Commission commission)
    {
        return commissionMapper.updateCommission(commission);
    }

    /**
     * 结算冷静期到期的佣金
     */
    @Override
    public int settleExpiredCommissions(int settleDays)
    {
        java.util.Map<String, Object> params = new java.util.HashMap<>();
        params.put("settleDays", settleDays);
        params.put("now", DateUtils.getNowDate());
        return commissionMapper.settleExpiredCommissions(params);
    }

    /**
     * 批量删除佣金明细
     * 
     * @param commissionIds 需要删除的佣金明细主键
     * @return 结果
     */
    @Override
    public int deleteCommissionByCommissionIds(Long[] commissionIds)
    {
        return commissionMapper.deleteCommissionByCommissionIds(commissionIds);
    }

    /**
     * 删除佣金明细信息
     * 
     * @param commissionId 佣金明细主键
     * @return 结果
     */
    @Override
    public int deleteCommissionByCommissionId(Long commissionId)
    {
        return commissionMapper.deleteCommissionByCommissionId(commissionId);
    }
}
