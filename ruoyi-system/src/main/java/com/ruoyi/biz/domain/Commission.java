package com.ruoyi.biz.domain;

import java.math.BigDecimal;
import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 佣金明细对象 biz_commission
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public class Commission extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 商户ID（多商户隔离字段） */
    private Long merchantId;

    /** 佣金ID */
    private Long commissionId;

    /** 推客ID */
    @Excel(name = "推客ID")
    private Long distributorId;

    /** 订单ID */
    @Excel(name = "订单ID")
    private Long orderId;

    /** 门店ID */
    @Excel(name = "门店ID")
    private Long storeId;

    /** 门店名称（展示用，非表字段） */
    private String storeName;

    /** 推客会员昵称（展示用，非表字段） */
    private String memberName;

    /** 订单编号（展示用，非表字段） */
    private String orderNo;

    /** 佣金金额 */
    @Excel(name = "佣金金额")
    private BigDecimal amount;

    /** 佣金比例(%) */
    @Excel(name = "佣金比例(%)")
    private BigDecimal rate;

    /** 状态（0待结算 1已结算 2已失效） */
    @Excel(name = "状态", readConverterExp = "0=待结算,1=已结算,2=已失效")
    private String status;

    /** 结算时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    @Excel(name = "结算时间", width = 30, dateFormat = "yyyy-MM-dd")
    private Date settleTime;

    public void setCommissionId(Long commissionId) 
    {
        this.commissionId = commissionId;
    }

    public Long getCommissionId() 
    {
        return commissionId;
    }

    public void setDistributorId(Long distributorId) 
    {
        this.distributorId = distributorId;
    }

    public Long getDistributorId() 
    {
        return distributorId;
    }

    public void setOrderId(Long orderId) 
    {
        this.orderId = orderId;
    }

    public Long getOrderId() 
    {
        return orderId;
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

    public void setMemberName(String memberName) { this.memberName = memberName; }

    public String getMemberName() { return memberName; }

    public void setOrderNo(String orderNo) { this.orderNo = orderNo; }

    public String getOrderNo() { return orderNo; }

    public void setAmount(BigDecimal amount) 
    {
        this.amount = amount;
    }

    public BigDecimal getAmount() 
    {
        return amount;
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

    public void setSettleTime(Date settleTime) 
    {
        this.settleTime = settleTime;
    }

    public Date getSettleTime() 
    {
        return settleTime;
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
            .append("commissionId", getCommissionId())
            .append("distributorId", getDistributorId())
            .append("orderId", getOrderId())
            .append("storeId", getStoreId())
            .append("amount", getAmount())
            .append("rate", getRate())
            .append("status", getStatus())
            .append("settleTime", getSettleTime())
            .append("createTime", getCreateTime())
            .toString();
    }
}
