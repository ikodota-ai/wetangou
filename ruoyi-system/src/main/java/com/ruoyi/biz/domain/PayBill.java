package com.ruoyi.biz.domain;

import java.math.BigDecimal;
import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 买单流水对象 biz_pay_bill
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public class PayBill extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 商户ID（多商户隔离字段） */
    private Long merchantId;

    /** 买单ID */
    private Long billId;

    /** 买单编号 */
    @Excel(name = "买单编号")
    private String billNo;

    /** 关联订单ID */
    @Excel(name = "关联订单ID")
    private Long orderId;

    /** 门店ID */
    @Excel(name = "门店ID")
    private Long storeId;

    /** 会员ID */
    @Excel(name = "会员ID")
    private Long memberId;

    /** 门店名称（展示用，非表字段） */
    private String storeName;

    /** 会员昵称（展示用，非表字段） */
    private String memberName;

    /** 消费金额 */
    @Excel(name = "消费金额")
    private BigDecimal amount;

    /** 使用的会员代金券ID */
    @Excel(name = "使用的会员代金券ID")
    private Long memberVoucherId;

    /** 优惠金额 */
    @Excel(name = "优惠金额")
    private BigDecimal discountAmount;

    /** 实付金额 */
    @Excel(name = "实付金额")
    private BigDecimal payAmount;

    /** 确认店员 */
    @Excel(name = "确认店员")
    private String confirmUser;

    /** 确认时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    @Excel(name = "确认时间", width = 30, dateFormat = "yyyy-MM-dd")
    private Date confirmTime;

    /** 支付完成时间（微信回调时间；为空表示尚未支付成功） */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date payTime;

    /** 微信支付订单号 transaction_id（对账/查单/退款都要靠它） */
    private String payNo;

    /** 状态（0待确认 1待支付 2已完成 3已取消） */
    @Excel(name = "状态", readConverterExp = "0=待确认,1=待支付,2=已完成,3=已取消")
    private String status;

    public void setBillId(Long billId) 
    {
        this.billId = billId;
    }

    public Long getBillId() 
    {
        return billId;
    }

    public void setBillNo(String billNo) 
    {
        this.billNo = billNo;
    }

    public String getBillNo() 
    {
        return billNo;
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

    public void setMemberId(Long memberId) 
    {
        this.memberId = memberId;
    }

    public Long getMemberId() 
    {
        return memberId;
    }

    public void setStoreName(String storeName)
    {
        this.storeName = storeName;
    }

    public String getStoreName()
    {
        return storeName;
    }

    public void setMemberName(String memberName)
    {
        this.memberName = memberName;
    }

    public String getMemberName()
    {
        return memberName;
    }

    public void setAmount(BigDecimal amount) 
    {
        this.amount = amount;
    }

    public BigDecimal getAmount() 
    {
        return amount;
    }

    public void setMemberVoucherId(Long memberVoucherId) 
    {
        this.memberVoucherId = memberVoucherId;
    }

    public Long getMemberVoucherId() 
    {
        return memberVoucherId;
    }

    public void setDiscountAmount(BigDecimal discountAmount) 
    {
        this.discountAmount = discountAmount;
    }

    public BigDecimal getDiscountAmount() 
    {
        return discountAmount;
    }

    public void setPayAmount(BigDecimal payAmount) 
    {
        this.payAmount = payAmount;
    }

    public BigDecimal getPayAmount() 
    {
        return payAmount;
    }

    public void setConfirmUser(String confirmUser) 
    {
        this.confirmUser = confirmUser;
    }

    public String getConfirmUser() 
    {
        return confirmUser;
    }

    public void setConfirmTime(Date confirmTime) 
    {
        this.confirmTime = confirmTime;
    }

    public Date getConfirmTime() 
    {
        return confirmTime;
    }

    public void setStatus(String status) 
    {
        this.status = status;
    }

    public Date getPayTime() 
    {
        return payTime;
    }

    public void setPayTime(Date payTime) 
    {
        this.payTime = payTime;
    }

    public String getPayNo() 
    {
        return payNo;
    }

    public void setPayNo(String payNo) 
    {
        this.payNo = payNo;
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
            .append("billId", getBillId())
            .append("billNo", getBillNo())
            .append("orderId", getOrderId())
            .append("storeId", getStoreId())
            .append("memberId", getMemberId())
            .append("amount", getAmount())
            .append("memberVoucherId", getMemberVoucherId())
            .append("discountAmount", getDiscountAmount())
            .append("payAmount", getPayAmount())
            .append("confirmUser", getConfirmUser())
            .append("confirmTime", getConfirmTime())
            .append("payTime", getPayTime())
            .append("payNo", getPayNo())
            .append("status", getStatus())
            .append("createTime", getCreateTime())
            .append("updateTime", getUpdateTime())
            .toString();
    }
}
