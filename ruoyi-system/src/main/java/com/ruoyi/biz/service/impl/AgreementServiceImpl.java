package com.ruoyi.biz.service.impl;

import java.util.List;
import com.ruoyi.common.utils.DateUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.mapper.AgreementMapper;
import com.ruoyi.biz.domain.Agreement;
import com.ruoyi.biz.service.IAgreementService;

/**
 * 协议Service业务层处理
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@Service
public class AgreementServiceImpl implements IAgreementService 
{
    @Autowired
    private AgreementMapper agreementMapper;

    /**
     * 查询协议
     * 
     * @param agreementId 协议主键
     * @return 协议
     */
    @Override
    public Agreement selectAgreementByAgreementId(Long agreementId)
    {
        return agreementMapper.selectAgreementByAgreementId(agreementId);
    }

    /**
     * 查询协议列表
     * 
     * @param agreement 协议
     * @return 协议
     */
    @Override
    public List<Agreement> selectAgreementList(Agreement agreement)
    {
        return agreementMapper.selectAgreementList(agreement);
    }

    /**
     * 新增协议
     * 
     * @param agreement 协议
     * @return 结果
     */
    @Override
    public int insertAgreement(Agreement agreement)
    {
        agreement.setCreateTime(DateUtils.getNowDate());
        return agreementMapper.insertAgreement(agreement);
    }

    /**
     * 修改协议
     * 
     * @param agreement 协议
     * @return 结果
     */
    @Override
    public int updateAgreement(Agreement agreement)
    {
        agreement.setUpdateTime(DateUtils.getNowDate());
        return agreementMapper.updateAgreement(agreement);
    }

    /**
     * 批量删除协议
     * 
     * @param agreementIds 需要删除的协议主键
     * @return 结果
     */
    @Override
    public int deleteAgreementByAgreementIds(Long[] agreementIds)
    {
        return agreementMapper.deleteAgreementByAgreementIds(agreementIds);
    }

    /**
     * 删除协议信息
     * 
     * @param agreementId 协议主键
     * @return 结果
     */
    @Override
    public int deleteAgreementByAgreementId(Long agreementId)
    {
        return agreementMapper.deleteAgreementByAgreementId(agreementId);
    }
}
