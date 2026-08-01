package com.ruoyi.biz.domain;

import java.math.BigDecimal;
import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 推客对象 biz_distributor
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public class Distributor extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 商户ID（多商户隔离字段） */
    private Long merchantId;

    /** 推客ID */
    private Long distributorId;

    /** 会员ID */
    @Excel(name = "会员ID")
    private Long memberId;

    /** 会员昵称（展示用，非表字段） */
    private String memberName;

    /** 推客等级 */
    @Excel(name = "推客等级")
    private Integer level;

    /** 累计佣金 */
    @Excel(name = "累计佣金")
    private BigDecimal totalCommission;

    /** 可提现金额 */
    @Excel(name = "可提现金额")
    private BigDecimal availableAmount;

    /** 冻结金额 */
    @Excel(name = "冻结金额")
    private BigDecimal frozenAmount;

    /** 已提现金额 */
    @Excel(name = "已提现金额")
    private BigDecimal withdrawAmount;

    /** 状态（0正常 1停用） */
    @Excel(name = "状态", readConverterExp = "0=正常,1=停用")
    private String status;

    /** 成为推客时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    @Excel(name = "成为推客时间", width = 30, dateFormat = "yyyy-MM-dd")
    private Date joinTime;

    public void setDistributorId(Long distributorId) 
    {
        this.distributorId = distributorId;
    }

    public Long getDistributorId() 
    {
        return distributorId;
    }

    public void setMemberId(Long memberId) 
    {
        this.memberId = memberId;
    }

    public Long getMemberId() 
    {
        return memberId;
    }

    public void setMemberName(String memberName)
    {
        this.memberName = memberName;
    }

    public String getMemberName()
    {
        return memberName;
    }

    public void setLevel(Integer level) 
    {
        this.level = level;
    }

    public Integer getLevel() 
    {
        return level;
    }

    public void setTotalCommission(BigDecimal totalCommission) 
    {
        this.totalCommission = totalCommission;
    }

    public BigDecimal getTotalCommission() 
    {
        return totalCommission;
    }

    public void setAvailableAmount(BigDecimal availableAmount) 
    {
        this.availableAmount = availableAmount;
    }

    public BigDecimal getAvailableAmount() 
    {
        return availableAmount;
    }

    public void setFrozenAmount(BigDecimal frozenAmount) 
    {
        this.frozenAmount = frozenAmount;
    }

    public BigDecimal getFrozenAmount() 
    {
        return frozenAmount;
    }

    public void setWithdrawAmount(BigDecimal withdrawAmount) 
    {
        this.withdrawAmount = withdrawAmount;
    }

    public BigDecimal getWithdrawAmount() 
    {
        return withdrawAmount;
    }

    public void setStatus(String status) 
    {
        this.status = status;
    }

    public String getStatus() 
    {
        return status;
    }

    public void setJoinTime(Date joinTime) 
    {
        this.joinTime = joinTime;
    }

    public Date getJoinTime() 
    {
        return joinTime;
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
            .append("distributorId", getDistributorId())
            .append("memberId", getMemberId())
            .append("memberName", getMemberName())
            .append("level", getLevel())
            .append("totalCommission", getTotalCommission())
            .append("availableAmount", getAvailableAmount())
            .append("frozenAmount", getFrozenAmount())
            .append("withdrawAmount", getWithdrawAmount())
            .append("status", getStatus())
            .append("joinTime", getJoinTime())
            .append("createTime", getCreateTime())
            .append("updateTime", getUpdateTime())
            .toString();
    }
}
