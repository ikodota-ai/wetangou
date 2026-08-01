package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.Agreement;

/**
 * 协议Service接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface IAgreementService 
{
    /**
     * 查询协议
     * 
     * @param agreementId 协议主键
     * @return 协议
     */
    public Agreement selectAgreementByAgreementId(Long agreementId);

    /**
     * 查询协议列表
     * 
     * @param agreement 协议
     * @return 协议集合
     */
    public List<Agreement> selectAgreementList(Agreement agreement);

    /**
     * 新增协议
     * 
     * @param agreement 协议
     * @return 结果
     */
    public int insertAgreement(Agreement agreement);

    /**
     * 修改协议
     * 
     * @param agreement 协议
     * @return 结果
     */
    public int updateAgreement(Agreement agreement);

    /**
     * 批量删除协议
     * 
     * @param agreementIds 需要删除的协议主键集合
     * @return 结果
     */
    public int deleteAgreementByAgreementIds(Long[] agreementIds);

    /**
     * 删除协议信息
     * 
     * @param agreementId 协议主键
     * @return 结果
     */
    public int deleteAgreementByAgreementId(Long agreementId);
}
