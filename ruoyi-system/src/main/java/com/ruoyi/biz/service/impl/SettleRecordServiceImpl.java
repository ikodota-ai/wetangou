package com.ruoyi.biz.service.impl;

import java.util.List;
import com.ruoyi.common.utils.DateUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.mapper.SettleRecordMapper;
import com.ruoyi.biz.domain.SettleRecord;
import com.ruoyi.biz.service.ISettleRecordService;

/**
 * 分账明细Service业务层处理
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@Service
public class SettleRecordServiceImpl implements ISettleRecordService 
{
    @Autowired
    private SettleRecordMapper settleRecordMapper;

    /**
     * 查询分账明细
     * 
     * @param recordId 分账明细主键
     * @return 分账明细
     */
    @Override
    public SettleRecord selectSettleRecordByRecordId(Long recordId)
    {
        return settleRecordMapper.selectSettleRecordByRecordId(recordId);
    }

    /**
     * 查询分账明细列表
     * 
     * @param settleRecord 分账明细
     * @return 分账明细
     */
    @Override
    public List<SettleRecord> selectSettleRecordList(SettleRecord settleRecord)
    {
        return settleRecordMapper.selectSettleRecordList(settleRecord);
    }

    /**
     * 新增分账明细
     * 
     * @param settleRecord 分账明细
     * @return 结果
     */
    @Override
    public int insertSettleRecord(SettleRecord settleRecord)
    {
        settleRecord.setCreateTime(DateUtils.getNowDate());
        return settleRecordMapper.insertSettleRecord(settleRecord);
    }

    /**
     * 修改分账明细
     * 
     * @param settleRecord 分账明细
     * @return 结果
     */
    @Override
    public int updateSettleRecord(SettleRecord settleRecord)
    {
        return settleRecordMapper.updateSettleRecord(settleRecord);
    }

    /**
     * 批量删除分账明细
     * 
     * @param recordIds 需要删除的分账明细主键
     * @return 结果
     */
    @Override
    public int deleteSettleRecordByRecordIds(Long[] recordIds)
    {
        return settleRecordMapper.deleteSettleRecordByRecordIds(recordIds);
    }

    /**
     * 删除分账明细信息
     * 
     * @param recordId 分账明细主键
     * @return 结果
     */
    @Override
    public int deleteSettleRecordByRecordId(Long recordId)
    {
        return settleRecordMapper.deleteSettleRecordByRecordId(recordId);
    }
}
