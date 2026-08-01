package com.ruoyi.biz.domain;

import java.math.BigDecimal;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 分账接收方对象 biz_settle_account
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public class SettleAccount extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 商户ID（多商户隔离字段） */
    private Long merchantId;

    /** 账户ID */
    private Long accountId;

    /** 归属类型（0门店 1推客 2平台） */
    @Excel(name = "归属类型", readConverterExp = "0=门店,1=推客,2=平台")
    private String ownerType;

    /** 归属ID */
    @Excel(name = "归属ID")
    private Long ownerId;

    /** 分账接收方类型 */
    @Excel(name = "分账接收方类型")
    private String receiverType;

    /** 分账接收方账号 */
    @Excel(name = "分账接收方账号")
    private String receiverAccount;

    /** 接收方名称 */
    @Excel(name = "接收方名称")
    private String receiverName;

    /** 分账比例(%) */
    @Excel(name = "分账比例(%)")
    private BigDecimal rate;

    /** 状态（0正常 1停用） */
    @Excel(name = "状态", readConverterExp = "0=正常,1=停用")
    private String status;

    public void setAccountId(Long accountId) 
    {
        this.accountId = accountId;
    }

    public Long getAccountId() 
    {
        return accountId;
    }

    public void setOwnerType(String ownerType) 
    {
        this.ownerType = ownerType;
    }

    public String getOwnerType() 
    {
        return ownerType;
    }

    public void setOwnerId(Long ownerId) 
    {
        this.ownerId = ownerId;
    }

    public Long getOwnerId() 
    {
        return ownerId;
    }

    public void setReceiverType(String receiverType) 
    {
        this.receiverType = receiverType;
    }

    public String getReceiverType() 
    {
        return receiverType;
    }

    public void setReceiverAccount(String receiverAccount) 
    {
        this.receiverAccount = receiverAccount;
    }

    public String getReceiverAccount() 
    {
        return receiverAccount;
    }

    public void setReceiverName(String receiverName) 
    {
        this.receiverName = receiverName;
    }

    public String getReceiverName() 
    {
        return receiverName;
    }

    public void setRate(BigDecimal rate) 
    {
        this.rate = rate;
    }

    public BigDecimal getRate() 
    {
        return rate;
    }

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
            .append("accountId", getAccountId())
            .append("ownerType", getOwnerType())
            .append("ownerId", getOwnerId())
            .append("receiverType", getReceiverType())
            .append("receiverAccount", getReceiverAccount())
            .append("receiverName", getReceiverName())
            .append("rate", getRate())
            .append("status", getStatus())
            .append("createTime", getCreateTime())
            .append("updateTime", getUpdateTime())
            .toString();
    }
}
