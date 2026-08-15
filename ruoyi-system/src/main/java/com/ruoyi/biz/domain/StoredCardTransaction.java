package com.ruoyi.biz.domain;

import java.math.BigDecimal;
import java.util.Date;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 储值卡流水 biz_stored_card_transaction
 *
 * @author dytuangou
 * @date 2026-08-15
 */
public class StoredCardTransaction extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 流水ID */
    private Long txId;
    /** 储值卡ID */
    private Long cardId;
    private Long merchantId;
    private Long memberId;
    /** RECHARGE/CONSUME/REFUND/REVERSAL */
    private String txType;
    /** 本次金额（正负） */
    private BigDecimal amount;
    private BigDecimal balanceBefore;
    private BigDecimal balanceAfter;
    private Long orderId;
    /** 业务编号（幂等键） */
    private String bizNo;
    /** MEMBER/STAFF/ADMIN/SYSTEM */
    private String operatorType;
    private String operatorId;
    private Date createTime;

    public Long getTxId() { return txId; }
    public void setTxId(Long txId) { this.txId = txId; }
    public Long getCardId() { return cardId; }
    public void setCardId(Long cardId) { this.cardId = cardId; }
    public Long getMerchantId() { return merchantId; }
    public void setMerchantId(Long merchantId) { this.merchantId = merchantId; }
    public Long getMemberId() { return memberId; }
    public void setMemberId(Long memberId) { this.memberId = memberId; }
    public String getTxType() { return txType; }
    public void setTxType(String txType) { this.txType = txType; }
    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }
    public BigDecimal getBalanceBefore() { return balanceBefore; }
    public void setBalanceBefore(BigDecimal balanceBefore) { this.balanceBefore = balanceBefore; }
    public BigDecimal getBalanceAfter() { return balanceAfter; }
    public void setBalanceAfter(BigDecimal balanceAfter) { this.balanceAfter = balanceAfter; }
    public Long getOrderId() { return orderId; }
    public void setOrderId(Long orderId) { this.orderId = orderId; }
    public String getBizNo() { return bizNo; }
    public void setBizNo(String bizNo) { this.bizNo = bizNo; }
    public String getOperatorType() { return operatorType; }
    public void setOperatorType(String operatorType) { this.operatorType = operatorType; }
    public String getOperatorId() { return operatorId; }
    public void setOperatorId(String operatorId) { this.operatorId = operatorId; }
    public Date getCreateTime() { return createTime; }
    public void setCreateTime(Date createTime) { this.createTime = createTime; }

    @Override
    public String toString() {
        return new ToStringBuilder(this, ToStringStyle.MULTI_LINE_STYLE)
            .append("txId", getTxId())
            .append("cardId", getCardId())
            .append("txType", getTxType())
            .append("amount", getAmount())
            .append("balanceAfter", getBalanceAfter())
            .append("createTime", getCreateTime())
            .toString();
    }
}
