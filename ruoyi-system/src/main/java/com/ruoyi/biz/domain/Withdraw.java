package com.ruoyi.biz.domain;

import java.math.BigDecimal;
import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 提现记录对象 biz_withdraw
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public class Withdraw extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 商户ID（多商户隔离字段） */
    private Long merchantId;

    /** 提现ID */
    private Long withdrawId;

    /** 提现单号 */
    @Excel(name = "提现单号")
    private String withdrawNo;

    /** 推客ID */
    @Excel(name = "推客ID")
    private Long distributorId;

    /** 推客会员昵称（展示用，非表字段） */
    private String memberName;

    /** 提现金额 */
    @Excel(name = "提现金额")
    private BigDecimal amount;

    /** 方式（0微信 1支付宝 2银行卡） */
    @Excel(name = "方式", readConverterExp = "0=微信,1=支付宝,2=银行卡")
    private String withdrawType;

    /** 收款账户 */
    @Excel(name = "收款账户")
    private String account;

    /** 收款人姓名 */
    @Excel(name = "收款人姓名")
    private String accountName;

    /** 状态（0处理中 1成功 2失败） */
    @Excel(name = "状态", readConverterExp = "0=处理中,1=成功,2=失败")
    private String status;

    /** 申请时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    @Excel(name = "申请时间", width = 30, dateFormat = "yyyy-MM-dd")
    private Date applyTime;

    /** 完成时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    @Excel(name = "完成时间", width = 30, dateFormat = "yyyy-MM-dd")
    private Date finishTime;

    /** 失败原因 */
    @Excel(name = "失败原因")
    private String failReason;

    public void setWithdrawId(Long withdrawId) 
    {
        this.withdrawId = withdrawId;
    }

    public Long getWithdrawId() 
    {
        return withdrawId;
    }

    public void setWithdrawNo(String withdrawNo) 
    {
        this.withdrawNo = withdrawNo;
    }

    public String getWithdrawNo() 
    {
        return withdrawNo;
    }

    public void setDistributorId(Long distributorId) 
    {
        this.distributorId = distributorId;
    }

    public Long getDistributorId() 
    {
        return distributorId;
    }

    public void setMemberName(String memberName) { this.memberName = memberName; }

    public String getMemberName() { return memberName; }

    public void setAmount(BigDecimal amount) 
    {
        this.amount = amount;
    }

    public BigDecimal getAmount() 
    {
        return amount;
    }

    public void setWithdrawType(String withdrawType) 
    {
        this.withdrawType = withdrawType;
    }

    public String getWithdrawType() 
    {
        return withdrawType;
    }

    public void setAccount(String account) 
    {
        this.account = account;
    }

    public String getAccount() 
    {
        return account;
    }

    public void setAccountName(String accountName) 
    {
        this.accountName = accountName;
    }

    public String getAccountName() 
    {
        return accountName;
    }

    public void setStatus(String status) 
    {
        this.status = status;
    }

    public String getStatus() 
    {
        return status;
    }

    public void setApplyTime(Date applyTime) 
    {
        this.applyTime = applyTime;
    }

    public Date getApplyTime() 
    {
        return applyTime;
    }

    public void setFinishTime(Date finishTime) 
    {
        this.finishTime = finishTime;
    }

    public Date getFinishTime() 
    {
        return finishTime;
    }

    public void setFailReason(String failReason) 
    {
        this.failReason = failReason;
    }

    public String getFailReason() 
    {
        return failReason;
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
            .append("withdrawId", getWithdrawId())
            .append("withdrawNo", getWithdrawNo())
            .append("distributorId", getDistributorId())
            .append("amount", getAmount())
            .append("withdrawType", getWithdrawType())
            .append("account", getAccount())
            .append("accountName", getAccountName())
            .append("status", getStatus())
            .append("applyTime", getApplyTime())
            .append("finishTime", getFinishTime())
            .append("failReason", getFailReason())
            .append("createTime", getCreateTime())
            .toString();
    }
}
