package com.ruoyi.biz.domain;

import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 协议对象 biz_agreement
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public class Agreement extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 商户ID（多商户隔离字段） */
    private Long merchantId;

    /** 协议ID */
    private Long agreementId;

    /** 类型（user用户 privacy隐私 distributor推客） */
    @Excel(name = "类型", readConverterExp = "u=ser用户,p=rivacy隐私,d=istributor推客")
    private String agreementType;

    /** 标题 */
    @Excel(name = "标题")
    private String title;

    /** 协议内容 */
    @Excel(name = "协议内容")
    private String content;

    /** 门店ID（0=全平台） */
    @Excel(name = "门店ID", readConverterExp = "0==全平台")
    private Long storeId;

    /** 门店名称（展示用，非表字段） */
    private String storeName;

    /** 状态（0启用 1停用） */
    @Excel(name = "状态", readConverterExp = "0=启用,1=停用")
    private String status;

    public void setAgreementId(Long agreementId) 
    {
        this.agreementId = agreementId;
    }

    public Long getAgreementId() 
    {
        return agreementId;
    }

    public void setAgreementType(String agreementType) 
    {
        this.agreementType = agreementType;
    }

    public String getAgreementType() 
    {
        return agreementType;
    }

    public void setTitle(String title) 
    {
        this.title = title;
    }

    public String getTitle() 
    {
        return title;
    }

    public void setContent(String content) 
    {
        this.content = content;
    }

    public String getContent() 
    {
        return content;
    }

    public void setStoreId(Long storeId) 
    {
        this.storeId = storeId;
    }

    public Long getStoreId() 
    {
        return storeId;
    }

    public void setStoreName(String storeName) { this.storeName = storeName; }

    public String getStoreName() { return storeName; }


    public void setStatus(String status) 
    {
        this.status = status;
    }

    public String getStatus() 
    {
        return status;
    }

    public Long getMerchantId()
    {
        return merchantId;
    }

    public void setMerchantId(Long merchantId)
    {
        this.merchantId = merchantId;
    }

    @Override
    public String toString() {
        return new ToStringBuilder(this,ToStringStyle.MULTI_LINE_STYLE)
            .append("agreementId", getAgreementId())
            .append("agreementType", getAgreementType())
            .append("title", getTitle())
            .append("content", getContent())
            .append("storeId", getStoreId())
            .append("status", getStatus())
            .append("createBy", getCreateBy())
            .append("createTime", getCreateTime())
            .append("updateBy", getUpdateBy())
            .append("updateTime", getUpdateTime())
            .toString();
    }
}
