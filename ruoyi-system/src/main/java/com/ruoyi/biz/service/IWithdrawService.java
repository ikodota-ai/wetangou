package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.Withdraw;

/**
 * 提现记录Service接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface IWithdrawService 
{
    /**
     * 查询提现记录
     * 
     * @param withdrawId 提现记录主键
     * @return 提现记录
     */
    public Withdraw selectWithdrawByWithdrawId(Long withdrawId);

    /**
     * 查询提现记录列表
     * 
     * @param withdraw 提现记录
     * @return 提现记录集合
     */
    public List<Withdraw> selectWithdrawList(Withdraw withdraw);

    /**
     * 新增提现记录
     * 
     * @param withdraw 提现记录
     * @return 结果
     */
    public int insertWithdraw(Withdraw withdraw);

    /**
     * 修改提现记录
     * 
     * @param withdraw 提现记录
     * @return 结果
     */
    public int updateWithdraw(Withdraw withdraw);

    /**
     * 批量删除提现记录
     * 
     * @param withdrawIds 需要删除的提现记录主键集合
     * @return 结果
     */
    public int deleteWithdrawByWithdrawIds(Long[] withdrawIds);

    /**
     * 删除提现记录信息
     * 
     * @param withdrawId 提现记录主键
     * @return 结果
     */
    public int deleteWithdrawByWithdrawId(Long withdrawId);
}
