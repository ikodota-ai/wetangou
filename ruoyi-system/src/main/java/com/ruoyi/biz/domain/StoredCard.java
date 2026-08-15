package com.ruoyi.biz.domain;

import java.math.BigDecimal;
import java.util.Date;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 会员储值卡 biz_member_stored_card
 *
 * @author dytuangou
 * @date 2026-08-15
 */
public class StoredCard extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    private Long cardId;
    private Long merchantId;
    private Long memberId;
    private Long productId;
    private Long orderId;
    private BigDecimal faceValue;
    private BigDecimal balance;
    private BigDecimal usedAmount;
    private BigDecimal rechargeAmount;
    private BigDecimal refundAmount;
    private Date expireAt;
    /** 状态 0=正常 1=已冻结 2=已退卡 */
    private String status;
    private String delFlag;

    public Long getCardId() { return cardId; }
    public void setCardId(Long cardId) { this.cardId = cardId; }
    public Long getMerchantId() { return merchantId; }
    public void setMerchantId(Long merchantId) { this.merchantId = merchantId; }
    public Long getMemberId() { return memberId; }
    public void setMemberId(Long memberId) { this.memberId = memberId; }
    public Long getProductId() { return productId; }
    public void setProductId(Long productId) { this.productId = productId; }
    public Long getOrderId() { return orderId; }
    public void setOrderId(Long orderId) { this.orderId = orderId; }
    public BigDecimal getFaceValue() { return faceValue; }
    public void setFaceValue(BigDecimal faceValue) { this.faceValue = faceValue; }
    public BigDecimal getBalance() { return balance; }
    public void setBalance(BigDecimal balance) { this.balance = balance; }
    public BigDecimal getUsedAmount() { return usedAmount; }
    public void setUsedAmount(BigDecimal usedAmount) { this.usedAmount = usedAmount; }
    public BigDecimal getRechargeAmount() { return rechargeAmount; }
    public void setRechargeAmount(BigDecimal rechargeAmount) { this.rechargeAmount = rechargeAmount; }
    public BigDecimal getRefundAmount() { return refundAmount; }
    public void setRefundAmount(BigDecimal refundAmount) { this.refundAmount = refundAmount; }
    public Date getExpireAt() { return expireAt; }
    public void setExpireAt(Date expireAt) { this.expireAt = expireAt; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public String getDelFlag() { return delFlag; }
    public void setDelFlag(String delFlag) { this.delFlag = delFlag; }

    @Override
    public String toString() {
        return new ToStringBuilder(this, ToStringStyle.MULTI_LINE_STYLE)
            .append("cardId", getCardId())
            .append("merchantId", getMerchantId())
            .append("memberId", getMemberId())
            .append("productId", getProductId())
            .append("orderId", getOrderId())
            .append("faceValue", getFaceValue())
            .append("balance", getBalance())
            .append("usedAmount", getUsedAmount())
            .append("rechargeAmount", getRechargeAmount())
            .append("refundAmount", getRefundAmount())
            .append("expireAt", getExpireAt())
            .append("status", getStatus())
            .append("createTime", getCreateTime())
            .toString();
    }
}
