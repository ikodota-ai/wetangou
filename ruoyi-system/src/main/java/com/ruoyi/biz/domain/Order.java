package com.ruoyi.biz.domain;

import java.math.BigDecimal;
import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 订单对象 biz_order
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public class Order extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 商户ID（多商户隔离字段） */
    private Long merchantId;

    /** 订单ID */
    private Long orderId;

    /** 订单编号 */
    @Excel(name = "订单编号")
    private String orderNo;

    /** 门店ID */
    @Excel(name = "门店ID")
    private Long storeId;

    /** 会员ID */
    @Excel(name = "会员ID")
    private Long memberId;

    /** 商品ID */
    @Excel(name = "商品ID")
    private Long productId;

    /** 门店名称（展示用，非表字段） */
    @Excel(name = "门店")
    private String storeName;

    /** 会员昵称（展示用，非表字段） */
    @Excel(name = "会员")
    private String memberName;

    /** 商品名称快照 */
    @Excel(name = "商品名称快照")
    private String productName;

    /** 商品封面快照 */
    @Excel(name = "商品封面快照")
    private String productCover;

    /** 类型（0到店自取 1到店买单） */
    @Excel(name = "类型", readConverterExp = "0=到店自取,1=到店买单")
    private String orderType;

    /** 单价 */
    @Excel(name = "单价")
    private BigDecimal price;

    /** 数量 */
    @Excel(name = "数量")
    private Long num;

    /** 订单金额 */
    @Excel(name = "订单金额")
    private BigDecimal totalAmount;

    /** 优惠金额（代金券） */
    @Excel(name = "优惠金额", readConverterExp = "代=金券")
    private BigDecimal discountAmount;

    /** 实付金额 */
    @Excel(name = "实付金额")
    private BigDecimal payAmount;

    /** 使用的会员代金券ID */
    @Excel(name = "使用的会员代金券ID")
    private Long memberVoucherId;

    /** 推客ID（分销来源） */
    @Excel(name = "推客ID", readConverterExp = "分=销来源")
    private Long distributorId;

    /** 状态（0待付款 1待使用 2已完成 3已退款 4已取消） */
    @Excel(name = "状态", readConverterExp = "0=待付款,1=待使用,2=已完成,3=已退款,4=已取消")
    private String status;

    /** 核销码 */
    @Excel(name = "核销码")
    private String verifyCode;

    /** 核销时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    @Excel(name = "核销时间", width = 30, dateFormat = "yyyy-MM-dd")
    private Date verifyTime;

    /** 核销人 */
    @Excel(name = "核销人")
    private String verifyUser;

    /** 支付时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    @Excel(name = "支付时间", width = 30, dateFormat = "yyyy-MM-dd")
    private Date payTime;

    /** 微信支付单号 */
    @Excel(name = "微信支付单号")
    private String payNo;

    /** 核销有效期 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    @Excel(name = "核销有效期", width = 30, dateFormat = "yyyy-MM-dd")
    private Date expireTime;

    public void setOrderId(Long orderId) 
    {
        this.orderId = orderId;
    }

    public Long getOrderId() 
    {
        return orderId;
    }

    public void setOrderNo(String orderNo) 
    {
        this.orderNo = orderNo;
    }

    public String getOrderNo() 
    {
        return orderNo;
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

    public void setProductId(Long productId) 
    {
        this.productId = productId;
    }

    public Long getProductId() 
    {
        return productId;
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

    public void setProductName(String productName) 
    {
        this.productName = productName;
    }

    public String getProductName() 
    {
        return productName;
    }

    public void setProductCover(String productCover) 
    {
        this.productCover = productCover;
    }

    public String getProductCover() 
    {
        return productCover;
    }

    public void setOrderType(String orderType) 
    {
        this.orderType = orderType;
    }

    public String getOrderType() 
    {
        return orderType;
    }

    public void setPrice(BigDecimal price) 
    {
        this.price = price;
    }

    public BigDecimal getPrice() 
    {
        return price;
    }

    public void setNum(Long num) 
    {
        this.num = num;
    }

    public Long getNum() 
    {
        return num;
    }

    public void setTotalAmount(BigDecimal totalAmount) 
    {
        this.totalAmount = totalAmount;
    }

    public BigDecimal getTotalAmount() 
    {
        return totalAmount;
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

    public void setMemberVoucherId(Long memberVoucherId) 
    {
        this.memberVoucherId = memberVoucherId;
    }

    public Long getMemberVoucherId() 
    {
        return memberVoucherId;
    }

    public void setDistributorId(Long distributorId) 
    {
        this.distributorId = distributorId;
    }

    public Long getDistributorId() 
    {
        return distributorId;
    }

    public void setStatus(String status) 
    {
        this.status = status;
    }

    public String getStatus() 
    {
        return status;
    }

    public void setVerifyCode(String verifyCode) 
    {
        this.verifyCode = verifyCode;
    }

    public String getVerifyCode() 
    {
        return verifyCode;
    }

    public void setVerifyTime(Date verifyTime) 
    {
        this.verifyTime = verifyTime;
    }

    public Date getVerifyTime() 
    {
        return verifyTime;
    }

    public void setVerifyUser(String verifyUser) 
    {
        this.verifyUser = verifyUser;
    }

    public String getVerifyUser() 
    {
        return verifyUser;
    }

    public void setPayTime(Date payTime) 
    {
        this.payTime = payTime;
    }

    public Date getPayTime() 
    {
        return payTime;
    }

    public void setPayNo(String payNo) 
    {
        this.payNo = payNo;
    }

    public String getPayNo() 
    {
        return payNo;
    }

    public void setExpireTime(Date expireTime) 
    {
        this.expireTime = expireTime;
    }

    public Date getExpireTime() 
    {
        return expireTime;
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
            .append("orderId", getOrderId())
            .append("orderNo", getOrderNo())
            .append("storeId", getStoreId())
            .append("memberId", getMemberId())
            .append("productId", getProductId())
            .append("productName", getProductName())
            .append("productCover", getProductCover())
            .append("orderType", getOrderType())
            .append("price", getPrice())
            .append("num", getNum())
            .append("totalAmount", getTotalAmount())
            .append("discountAmount", getDiscountAmount())
            .append("payAmount", getPayAmount())
            .append("memberVoucherId", getMemberVoucherId())
            .append("distributorId", getDistributorId())
            .append("status", getStatus())
            .append("verifyCode", getVerifyCode())
            .append("verifyTime", getVerifyTime())
            .append("verifyUser", getVerifyUser())
            .append("payTime", getPayTime())
            .append("payNo", getPayNo())
            .append("expireTime", getExpireTime())
            .append("createBy", getCreateBy())
            .append("createTime", getCreateTime())
            .append("updateBy", getUpdateBy())
            .append("updateTime", getUpdateTime())
            .append("remark", getRemark())
            .toString();
    }
}
