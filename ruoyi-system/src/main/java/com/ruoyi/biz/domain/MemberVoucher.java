package com.ruoyi.biz.domain;

import java.math.BigDecimal;
import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 会员代金券对象 biz_member_voucher
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public class MemberVoucher extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 商户ID（多商户隔离字段） */
    private Long merchantId;

    /** 主键 */
    private Long id;

    /** 代金券名称（join biz_voucher.voucher_name，非持久化字段） */
    @Excel(name = "代金券名称")
    private String voucherName;

    /** 代金券模板ID */
    @Excel(name = "代金券模板ID")
    private Long voucherId;

    /** 会员ID */
    @Excel(name = "会员ID")
    private Long memberId;

    /** 面额快照 */
    @Excel(name = "面额快照")
    private BigDecimal faceValue;

    /** 门槛快照 */
    @Excel(name = "门槛快照")
    private BigDecimal threshold;

    /** 状态（0未使用 1已使用 2已过期） */
    @Excel(name = "状态", readConverterExp = "0=未使用,1=已使用,2=已过期")
    private String status;

    /** 使用订单ID */
    @Excel(name = "使用订单ID")
    private Long useOrderId;

    /** 过期时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    @Excel(name = "过期时间", width = 30, dateFormat = "yyyy-MM-dd")
    private Date expireTime;

    /** 领取时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    @Excel(name = "领取时间", width = 30, dateFormat = "yyyy-MM-dd")
    private Date getTime;

    /** 使用时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    @Excel(name = "使用时间", width = 30, dateFormat = "yyyy-MM-dd")
    private Date useTime;

    public void setId(Long id) 
    {
        this.id = id;
    }

    public Long getId() 
    {
        return id;
    }

    public void setVoucherId(Long voucherId) 
    {
        this.voucherId = voucherId;
    }

    public Long getVoucherId() 
    {
        return voucherId;
    }

    public void setMemberId(Long memberId) 
    {
        this.memberId = memberId;
    }

    public Long getMemberId() 
    {
        return memberId;
    }

    public void setFaceValue(BigDecimal faceValue) 
    {
        this.faceValue = faceValue;
    }

    public BigDecimal getFaceValue() 
    {
        return faceValue;
    }

    public void setThreshold(BigDecimal threshold) 
    {
        this.threshold = threshold;
    }

    public BigDecimal getThreshold() 
    {
        return threshold;
    }

    public void setStatus(String status) 
    {
        this.status = status;
    }

    public String getStatus() 
    {
        return status;
    }

    public void setUseOrderId(Long useOrderId) 
    {
        this.useOrderId = useOrderId;
    }

    public Long getUseOrderId() 
    {
        return useOrderId;
    }

    public void setExpireTime(Date expireTime) 
    {
        this.expireTime = expireTime;
    }

    public Date getExpireTime() 
    {
        return expireTime;
    }

    public void setGetTime(Date getTime) 
    {
        this.getTime = getTime;
    }

    public Date getGetTime() 
    {
        return getTime;
    }

    public void setUseTime(Date useTime) 
    {
        this.useTime = useTime;
    }

    public void setVoucherName(String voucherName)
    {
        this.voucherName = voucherName;
    }

    public String getVoucherName()
    {
        return voucherName;
    }

    public Date getUseTime() 
    {
        return useTime;
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
            .append("id", getId())
            .append("voucherId", getVoucherId())
            .append("memberId", getMemberId())
            .append("faceValue", getFaceValue())
            .append("threshold", getThreshold())
            .append("status", getStatus())
            .append("useOrderId", getUseOrderId())
            .append("expireTime", getExpireTime())
            .append("getTime", getGetTime())
            .append("useTime", getUseTime())
            .toString();
    }
}
