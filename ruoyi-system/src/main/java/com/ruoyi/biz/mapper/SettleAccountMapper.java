package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.biz.domain.SettleAccount;

/**
 * 分账接收方Mapper接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface SettleAccountMapper 
{
    /**
     * 查询分账接收方
     * 
     * @param accountId 分账接收方主键
     * @return 分账接收方
     */
    public SettleAccount selectSettleAccountByAccountId(Long accountId);

    /**
     * 查询分账接收方列表
     * 
     * @param settleAccount 分账接收方
     * @return 分账接收方集合
     */
    public List<SettleAccount> selectSettleAccountList(SettleAccount settleAccount);

    /**
     * 新增分账接收方
     * 
     * @param settleAccount 分账接收方
     * @return 结果
     */
    public int insertSettleAccount(SettleAccount settleAccount);

    /**
     * 修改分账接收方
     * 
     * @param settleAccount 分账接收方
     * @return 结果
     */
    public int updateSettleAccount(SettleAccount settleAccount);

    /**
     * 删除分账接收方
     * 
     * @param accountId 分账接收方主键
     * @return 结果
     */
    public int deleteSettleAccountByAccountId(Long accountId);

    /**
     * 批量删除分账接收方
     * 
     * @param accountIds 需要删除的数据主键集合
     * @return 结果
     */
    public int deleteSettleAccountByAccountIds(Long[] accountIds);
}
