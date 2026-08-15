package com.ruoyi.biz.domain;

import java.math.BigDecimal;
import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.annotation.Sensitive;
import com.ruoyi.common.enums.DesensitizedType;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 代理商对象 biz_agent
 *
 * <p>代理商向平台缴费换取商户开通额度，可自行开通并向商户收费。</p>
 *
 * @author dytuangou
 */
public class Agent extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 代理商ID */
    private Long agentId;
    private Long userId;

    /** 代理商编号 */
    @Excel(name = "代理商编号")
    private String agentNo;

    /** 代理商名称 */
    @Excel(name = "代理商名称")
    private String agentName;

    /** 对应部门ID */
    private Long deptId;

    /** 联系人 */
    @Excel(name = "联系人")
    private String contact;

    /** 联系电话 */
    @Sensitive(desensitizedType = DesensitizedType.PHONE)
    @Excel(name = "联系电话")
    private String phone;

    /** 邮箱 */
    private String email;

    /** 代理区域 */
    @Excel(name = "代理区域")
    private String region;

    /** 可开通商户额度 */
    @Excel(name = "商户额度")
    private Integer merchantQuota;

    /** 已使用商户额度 */
    @Excel(name = "已用额度")
    private Integer usedQuota;

    /** 可开门店额度（0=不限）；名下所有商户的门店总数不得超过此值 */
    @Excel(name = "门店额度")
    private Integer storeQuota;

    /** 当前已用门店数（不存库，由 AgentService 实时计算后塞入） */
    /** 累计缴费金额 */
    private BigDecimal paidAmount;

    /** 代理资格到期时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date expireTime;

    /** 状态（0正常 1停用） */
    @Excel(name = "状态", readConverterExp = "0=正常,1=停用")
    private String status;

    /** 删除标志（0存在 2删除） */
    private String delFlag;

    public Long getAgentId()
    {
        return agentId;
    }

    public void setAgentId(Long agentId)
    {
        this.agentId = agentId;
    }

    public Long getUserId()
    {
        return userId;
    }

    public void setUserId(Long userId)
    {
        this.userId = userId;
    }

    public String getAgentNo()
    {
        return agentNo;
    }

    public void setAgentNo(String agentNo)
    {
        this.agentNo = agentNo;
    }

    public String getAgentName()
    {
        return agentName;
    }

    public void setAgentName(String agentName)
    {
        this.agentName = agentName;
    }

    public Long getDeptId()
    {
        return deptId;
    }

    public void setDeptId(Long deptId)
    {
        this.deptId = deptId;
    }

    public String getContact()
    {
        return contact;
    }

    public void setContact(String contact)
    {
        this.contact = contact;
    }

    public String getPhone()
    {
        return phone;
    }

    public void setPhone(String phone)
    {
        this.phone = phone;
    }

    public String getEmail()
    {
        return email;
    }

    public void setEmail(String email)
    {
        this.email = email;
    }

    public String getRegion()
    {
        return region;
    }

    public void setRegion(String region)
    {
        this.region = region;
    }

    public Integer getMerchantQuota()
    {
        return merchantQuota;
    }

    public void setMerchantQuota(Integer merchantQuota)
    {
        this.merchantQuota = merchantQuota;
    }

    public Integer getUsedQuota()
    {
        return usedQuota;
    }

    public void setUsedQuota(Integer usedQuota)
    {
        this.usedQuota = usedQuota;
    }

    public Integer getStoreQuota() { return storeQuota; }
    public void setStoreQuota(Integer storeQuota) { this.storeQuota = storeQuota; }

    /** 当前已用门店数（不存库，由 AgentService 实时计算后塞入） */
    private Integer usedStoreCount;

    public Integer getUsedStoreCount() { return usedStoreCount; }
    public void setUsedStoreCount(Integer usedStoreCount) { this.usedStoreCount = usedStoreCount; }

    public BigDecimal getPaidAmount()
    {
        return paidAmount;
    }

    public void setPaidAmount(BigDecimal paidAmount)
    {
        this.paidAmount = paidAmount;
    }

    public Date getExpireTime()
    {
        return expireTime;
    }

    public void setExpireTime(Date expireTime)
    {
        this.expireTime = expireTime;
    }

    public String getStatus()
    {
        return status;
    }

    public void setStatus(String status)
    {
        this.status = status;
    }

    public String getDelFlag()
    {
        return delFlag;
    }

    public void setDelFlag(String delFlag)
    {
        this.delFlag = delFlag;
    }

    @Override
    public String toString()
    {
        return new ToStringBuilder(this, ToStringStyle.MULTI_LINE_STYLE)
            .append("agentId", getAgentId())
            .append("userId", getUserId())
            .append("agentNo", getAgentNo())
            .append("agentName", getAgentName())
            .append("merchantQuota", getMerchantQuota())
            .append("usedQuota", getUsedQuota())
            .append("status", getStatus())
            .toString();
    }
}
