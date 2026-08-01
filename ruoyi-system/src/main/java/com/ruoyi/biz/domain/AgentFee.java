package com.ruoyi.biz.domain;

import java.math.BigDecimal;
import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 代理商缴费对象 biz_agent_fee
 *
 * <p>平台向代理商收费：加盟费、商户开通额度、资格续费。
 * 审核通过后按 quota_add / months 增加代理商额度与有效期。</p>
 *
 * @author dytuangou
 */
public class AgentFee extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 缴费ID */
    private Long feeId;

    /** 缴费单号 */
    @Excel(name = "缴费单号")
    private String feeNo;

    /** 代理商ID */
    private Long agentId;

    /** 代理商名称（关联查询） */
    @Excel(name = "代理商")
    private String agentName;

    /** 费用类型（0加盟费 1商户额度 2资格续费 3其他） */
    @Excel(name = "费用类型", readConverterExp = "0=加盟费,1=商户额度,2=资格续费,3=其他")
    private String feeType;

    /** 缴费金额 */
    @Excel(name = "缴费金额")
    private BigDecimal amount;

    /** 本次增加商户额度 */
    @Excel(name = "增加额度")
    private Integer quotaAdd;

    /** 本次延长月数 */
    @Excel(name = "延长月数")
    private Integer months;

    /** 收款方式（0线下转账 1微信 2支付宝 3其他） */
    @Excel(name = "收款方式", readConverterExp = "0=线下转账,1=微信,2=支付宝,3=其他")
    private String payChannel;

    /** 付款凭证图片 */
    private String payVoucher;

    /** 到账时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    @Excel(name = "到账时间", width = 30, dateFormat = "yyyy-MM-dd HH:mm:ss")
    private Date payTime;

    /** 状态（0待确认 1已确认 2已驳回） */
    @Excel(name = "状态", readConverterExp = "0=待确认,1=已确认,2=已驳回")
    private String status;

    /** 审核人 */
    private String auditBy;

    /** 审核时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date auditTime;

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

    public Integer getQuotaAdd()
    {
        return quotaAdd;
    }

    public void setQuotaAdd(Integer quotaAdd)
    {
        this.quotaAdd = quotaAdd;
    }

    public Integer getMonths()
    {
        return months;
    }

    public void setMonths(Integer months)
    {
        this.months = months;
    }

    public String getPayChannel()
    {
        return payChannel;
    }

    public void setPayChannel(String payChannel)
    {
        this.payChannel = payChannel;
    }

    public String getPayVoucher()
    {
        return payVoucher;
    }

    public void setPayVoucher(String payVoucher)
    {
        this.payVoucher = payVoucher;
    }

    public Date getPayTime()
    {
        return payTime;
    }

    public void setPayTime(Date payTime)
    {
        this.payTime = payTime;
    }

    public String getStatus()
    {
        return status;
    }

    public void setStatus(String status)
    {
        this.status = status;
    }

    public String getAuditBy()
    {
        return auditBy;
    }

    public void setAuditBy(String auditBy)
    {
        this.auditBy = auditBy;
    }

    public Date getAuditTime()
    {
        return auditTime;
    }

    public void setAuditTime(Date auditTime)
    {
        this.auditTime = auditTime;
    }
}
