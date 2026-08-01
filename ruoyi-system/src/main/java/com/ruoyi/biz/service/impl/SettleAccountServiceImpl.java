package com.ruoyi.biz.service.impl;

import java.util.List;
import com.ruoyi.common.utils.DateUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.mapper.SettleAccountMapper;
import com.ruoyi.biz.domain.SettleAccount;
import com.ruoyi.biz.service.ISettleAccountService;

/**
 * 分账接收方Service业务层处理
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@Service
public class SettleAccountServiceImpl implements ISettleAccountService 
{
    @Autowired
    private SettleAccountMapper settleAccountMapper;

    /**
     * 查询分账接收方
     * 
     * @param accountId 分账接收方主键
     * @return 分账接收方
     */
    @Override
    public SettleAccount selectSettleAccountByAccountId(Long accountId)
    {
        return settleAccountMapper.selectSettleAccountByAccountId(accountId);
    }

    /**
     * 查询分账接收方列表
     * 
     * @param settleAccount 分账接收方
     * @return 分账接收方
     */
    @Override
    public List<SettleAccount> selectSettleAccountList(SettleAccount settleAccount)
    {
        return settleAccountMapper.selectSettleAccountList(settleAccount);
    }

    /**
     * 新增分账接收方
     * 
     * @param settleAccount 分账接收方
     * @return 结果
     */
    @Override
    public int insertSettleAccount(SettleAccount settleAccount)
    {
        settleAccount.setCreateTime(DateUtils.getNowDate());
        return settleAccountMapper.insertSettleAccount(settleAccount);
    }

    /**
     * 修改分账接收方
     * 
     * @param settleAccount 分账接收方
     * @return 结果
     */
    @Override
    public int updateSettleAccount(SettleAccount settleAccount)
    {
        settleAccount.setUpdateTime(DateUtils.getNowDate());
        return settleAccountMapper.updateSettleAccount(settleAccount);
    }

    /**
     * 批量删除分账接收方
     * 
     * @param accountIds 需要删除的分账接收方主键
     * @return 结果
     */
    @Override
    public int deleteSettleAccountByAccountIds(Long[] accountIds)
    {
        return settleAccountMapper.deleteSettleAccountByAccountIds(accountIds);
    }

    /**
     * 删除分账接收方信息
     * 
     * @param accountId 分账接收方主键
     * @return 结果
     */
    @Override
    public int deleteSettleAccountByAccountId(Long accountId)
    {
        return settleAccountMapper.deleteSettleAccountByAccountId(accountId);
    }
}
