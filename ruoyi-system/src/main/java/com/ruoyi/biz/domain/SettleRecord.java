package com.ruoyi.biz.domain;

import java.math.BigDecimal;
import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 分账明细对象 biz_settle_record
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public class SettleRecord extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 商户ID（多商户隔离字段） */
    private Long merchantId;

    /** 分账记录ID */
    private Long recordId;

    /** 订单ID */
    @Excel(name = "订单ID")
    private Long orderId;

    /** 分账单号 */
    @Excel(name = "分账单号")
    private String outOrderNo;

    /** 接收方账号 */
    @Excel(name = "接收方账号")
    private String receiverAccount;

    /** 分账金额 */
    @Excel(name = "分账金额")
    private BigDecimal amount;

    /** 状态（0处理中 1成功 2失败） */
    @Excel(name = "状态", readConverterExp = "0=处理中,1=成功,2=失败")
    private String status;

    /** 完成时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    @Excel(name = "完成时间", width = 30, dateFormat = "yyyy-MM-dd")
    private Date finishTime;

    public void setRecordId(Long recordId) 
    {
        this.recordId = recordId;
    }

    public Long getRecordId() 
    {
        return recordId;
    }

    public void setOrderId(Long orderId) 
    {
        this.orderId = orderId;
    }

    public Long getOrderId() 
    {
        return orderId;
    }

    public void setOutOrderNo(String outOrderNo) 
    {
        this.outOrderNo = outOrderNo;
    }

    public String getOutOrderNo() 
    {
        return outOrderNo;
    }

    public void setReceiverAccount(String receiverAccount) 
    {
        this.receiverAccount = receiverAccount;
    }

    public String getReceiverAccount() 
    {
        return receiverAccount;
    }

    public void setAmount(BigDecimal amount) 
    {
        this.amount = amount;
    }

    public BigDecimal getAmount() 
    {
        return amount;
    }

    public void setStatus(String status) 
    {
        this.status = status;
    }

    public String getStatus() 
    {
        return status;
    }

    public void setFinishTime(Date finishTime) 
    {
        this.finishTime = finishTime;
    }

    public Date getFinishTime() 
    {
        return finishTime;
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
            .append("recordId", getRecordId())
            .append("orderId", getOrderId())
            .append("outOrderNo", getOutOrderNo())
            .append("receiverAccount", getReceiverAccount())
            .append("amount", getAmount())
            .append("status", getStatus())
            .append("finishTime", getFinishTime())
            .append("createTime", getCreateTime())
            .toString();
    }
}
