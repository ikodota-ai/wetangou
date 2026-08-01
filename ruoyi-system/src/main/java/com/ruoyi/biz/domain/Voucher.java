package com.ruoyi.biz.domain;

import java.math.BigDecimal;
import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 代金券模板对象 biz_voucher
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public class Voucher extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 商户ID（多商户隔离字段） */
    private Long merchantId;

    /** 代金券ID */
    private Long voucherId;

    /** 门店ID（0=全平台通用） */
    @Excel(name = "门店ID", readConverterExp = "0==全平台通用")
    private Long storeId;

    /** 门店名称（展示用，非表字段） */
    private String storeName;

    /** 代金券名称 */
    @Excel(name = "代金券名称")
    private String voucherName;

    /** 面额 */
    @Excel(name = "面额")
    private BigDecimal faceValue;

    /** 使用门槛（满减） */
    @Excel(name = "使用门槛", readConverterExp = "满=减")
    private BigDecimal threshold;

    /** 发放总量（0=不限） */
    @Excel(name = "发放总量", readConverterExp = "0==不限")
    private Long total;

    /** 已领取数量 */
    @Excel(name = "已领取数量")
    private Long received;

    /** 有效期开始 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    @Excel(name = "有效期开始", width = 30, dateFormat = "yyyy-MM-dd")
    private Date validFrom;

    /** 有效期结束 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    @Excel(name = "有效期结束", width = 30, dateFormat = "yyyy-MM-dd")
    private Date validTo;

    /** 领取后有效天数（0=用固定日期） */
    @Excel(name = "领取后有效天数", readConverterExp = "0==用固定日期")
    private Integer validDays;

    /** 状态（0启用 1停用） */
    @Excel(name = "状态", readConverterExp = "0=启用,1=停用")
    private String status;

    public void setVoucherId(Long voucherId) 
    {
        this.voucherId = voucherId;
    }

    public Long getVoucherId() 
    {
        return voucherId;
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


    public void setVoucherName(String voucherName) 
    {
        this.voucherName = voucherName;
    }

    public String getVoucherName() 
    {
        return voucherName;
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

    public void setTotal(Long total) 
    {
        this.total = total;
    }

    public Long getTotal() 
    {
        return total;
    }

    public void setReceived(Long received) 
    {
        this.received = received;
    }

    public Long getReceived() 
    {
        return received;
    }

    public void setValidFrom(Date validFrom) 
    {
        this.validFrom = validFrom;
    }

    public Date getValidFrom() 
    {
        return validFrom;
    }

    public void setValidTo(Date validTo) 
    {
        this.validTo = validTo;
    }

    public Date getValidTo() 
    {
        return validTo;
    }

    public void setValidDays(Integer validDays) 
    {
        this.validDays = validDays;
    }

    public Integer getValidDays() 
    {
        return validDays;
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
            .append("voucherId", getVoucherId())
            .append("storeId", getStoreId())
            .append("voucherName", getVoucherName())
            .append("faceValue", getFaceValue())
            .append("threshold", getThreshold())
            .append("total", getTotal())
            .append("received", getReceived())
            .append("validFrom", getValidFrom())
            .append("validTo", getValidTo())
            .append("validDays", getValidDays())
            .append("status", getStatus())
            .append("createBy", getCreateBy())
            .append("createTime", getCreateTime())
            .append("updateBy", getUpdateBy())
            .append("updateTime", getUpdateTime())
            .toString();
    }
}
