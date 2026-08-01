package com.ruoyi.biz.domain;

import java.math.BigDecimal;
import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 商户收费对象 biz_merchant_fee
 *
 * <p>代理商向其名下商户收费，平台仅记账不参与资金。
 * 收款确认后按 end_time 同步商户服务到期时间。</p>
 *
 * @author dytuangou
 */
public class MerchantFee extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 收费ID */
    private Long feeId;

    /** 收费单号 */
    @Excel(name = "收费单号")
    private String feeNo;

    /** 商户ID */
    private Long merchantId;

    /** 商户名称（关联查询） */
    @Excel(name = "商户")
    private String merchantName;

    /** 收费代理商ID（0=平台直收） */
    private Long agentId;

    /** 代理商名称（关联查询） */
    @Excel(name = "收费方")
    private String agentName;

    /** 费用类型（0开通费 1年费 2增值服务 3其他） */
    @Excel(name = "费用类型", readConverterExp = "0=开通费,1=年费,2=增值服务,3=其他")
    private String feeType;

    /** 收费金额 */
    @Excel(name = "收费金额")
    private BigDecimal amount;

    /** 服务月数 */
    @Excel(name = "服务月数")
    private Integer months;

    /** 服务开始时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    @Excel(name = "服务开始", width = 30, dateFormat = "yyyy-MM-dd HH:mm:ss")
    private Date beginTime;

    /** 服务结束时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    @Excel(name = "服务结束", width = 30, dateFormat = "yyyy-MM-dd HH:mm:ss")
    private Date endTime;

    /** 状态（0未收 1已收 2作废） */
    @Excel(name = "状态", readConverterExp = "0=未收,1=已收,2=作废")
    private String status;

    public Long getFeeId()
    {
        return feeId;
    }

    public void setFeeId(Long feeId)
    {
        this.feeId = feeId;
    }

    public String getFeeNo()
    {
        return feeNo;
    }

    public void setFeeNo(String feeNo)
    {
        this.feeNo = feeNo;
    }

    public Long getMerchantId()
    {
        return merchantId;
    }

    public void setMerchantId(Long merchantId)
    {
        this.merchantId = merchantId;
    }

    public String getMerchantName()
    {
        return merchantName;
    }

    public void setMerchantName(String merchantName)
    {
        this.merchantName = merchantName;
    }

    public Long getAgentId()
    {
        return agentId;
    }

    public void setAgentId(Long agentId)
    {
        this.agentId = agentId;
    }

    public String getAgentName()
    {
        return agentName;
    }

    public void setAgentName(String agentName)
    {
        this.agentName = agentName;
    }

    public String getFeeType()
    {
        return feeType;
    }

    public void setFeeType(String feeType)
    {
        this.feeType = feeType;
    }

    public BigDecimal getAmount()
    {
        return amount;
    }

    public void setAmount(BigDecimal amount)
    {
        this.amount = amount;
    }

    public Integer getMonths()
    {
        return months;
    }

    public void setMonths(Integer months)
    {
        this.months = months;
    }

    public Date getBeginTime()
    {
        return beginTime;
    }

    public void setBeginTime(Date beginTime)
    {
        this.beginTime = beginTime;
    }

    public Date getEndTime()
    {
        return endTime;
    }

    public void setEndTime(Date endTime)
    {
        this.endTime = endTime;
    }

    public String getStatus()
    {
        return status;
    }

    public void setStatus(String status)
    {
        this.status = status;
    }
}
