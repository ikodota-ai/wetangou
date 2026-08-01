package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.SettleRecord;

/**
 * 分账明细Service接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface ISettleRecordService 
{
    /**
     * 查询分账明细
     * 
     * @param recordId 分账明细主键
     * @return 分账明细
     */
    public SettleRecord selectSettleRecordByRecordId(Long recordId);

    /**
     * 查询分账明细列表
     * 
     * @param settleRecord 分账明细
     * @return 分账明细集合
     */
    public List<SettleRecord> selectSettleRecordList(SettleRecord settleRecord);

    /**
     * 新增分账明细
     * 
     * @param settleRecord 分账明细
     * @return 结果
     */
    public int insertSettleRecord(SettleRecord settleRecord);

    /**
     * 修改分账明细
     * 
     * @param settleRecord 分账明细
     * @return 结果
     */
    public int updateSettleRecord(SettleRecord settleRecord);

    /**
     * 批量删除分账明细
     * 
     * @param recordIds 需要删除的分账明细主键集合
     * @return 结果
     */
    public int deleteSettleRecordByRecordIds(Long[] recordIds);

    /**
     * 删除分账明细信息
     * 
     * @param recordId 分账明细主键
     * @return 结果
     */
    public int deleteSettleRecordByRecordId(Long recordId);
}
