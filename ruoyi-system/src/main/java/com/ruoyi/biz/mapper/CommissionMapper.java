package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.biz.domain.Commission;

/**
 * 佣金明细Mapper接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface CommissionMapper 
{
    /**
     * 查询佣金明细
     * 
     * @param commissionId 佣金明细主键
     * @return 佣金明细
     */
    public Commission selectCommissionByCommissionId(Long commissionId);

    /**
     * 查询佣金明细列表
     * 
     * @param commission 佣金明细
     * @return 佣金明细集合
     */
    public List<Commission> selectCommissionList(Commission commission);

    /**
     * 新增佣金明细
     * 
     * @param commission 佣金明细
     * @return 结果
     */
    public int insertCommission(Commission commission);

    /**
     * 修改佣金明细
     * 
     * @param commission 佣金明细
     * @return 结果
     */
    public int updateCommission(Commission commission);

    /**
     * 删除佣金明细
     * 
     * @param commissionId 佣金明细主键
     * @return 结果
     */
    public int deleteCommissionByCommissionId(Long commissionId);

    /**
     * 批量删除佣金明细
     * 
     * @param commissionIds 需要删除的数据主键集合
     * @return 结果
     */
    public int deleteCommissionByCommissionIds(Long[] commissionIds);
}
