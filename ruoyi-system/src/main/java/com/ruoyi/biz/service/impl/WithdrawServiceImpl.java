package com.ruoyi.biz.service.impl;

import java.util.List;
import com.ruoyi.common.utils.DateUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.mapper.WithdrawMapper;
import com.ruoyi.biz.domain.Withdraw;
import com.ruoyi.biz.service.IWithdrawService;

/**
 * 提现记录Service业务层处理
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@Service
public class WithdrawServiceImpl implements IWithdrawService 
{
    @Autowired
    private WithdrawMapper withdrawMapper;

    /**
     * 查询提现记录
     * 
     * @param withdrawId 提现记录主键
     * @return 提现记录
     */
    @Override
    public Withdraw selectWithdrawByWithdrawId(Long withdrawId)
    {
        return withdrawMapper.selectWithdrawByWithdrawId(withdrawId);
    }

    /**
     * 查询提现记录列表
     * 
     * @param withdraw 提现记录
     * @return 提现记录
     */
    @Override
    public List<Withdraw> selectWithdrawList(Withdraw withdraw)
    {
        return withdrawMapper.selectWithdrawList(withdraw);
    }

    /**
     * 新增提现记录
     * 
     * @param withdraw 提现记录
     * @return 结果
     */
    @Override
    public int insertWithdraw(Withdraw withdraw)
    {
        withdraw.setCreateTime(DateUtils.getNowDate());
        return withdrawMapper.insertWithdraw(withdraw);
    }

    /**
     * 修改提现记录
     * 
     * @param withdraw 提现记录
     * @return 结果
     */
    @Override
    public int updateWithdraw(Withdraw withdraw)
    {
        return withdrawMapper.updateWithdraw(withdraw);
    }

    /**
     * 批量删除提现记录
     * 
     * @param withdrawIds 需要删除的提现记录主键
     * @return 结果
     */
    @Override
    public int deleteWithdrawByWithdrawIds(Long[] withdrawIds)
    {
        return withdrawMapper.deleteWithdrawByWithdrawIds(withdrawIds);
    }

    /**
     * 删除提现记录信息
     * 
     * @param withdrawId 提现记录主键
     * @return 结果
     */
    @Override
    public int deleteWithdrawByWithdrawId(Long withdrawId)
    {
        return withdrawMapper.deleteWithdrawByWithdrawId(withdrawId);
    }
}
