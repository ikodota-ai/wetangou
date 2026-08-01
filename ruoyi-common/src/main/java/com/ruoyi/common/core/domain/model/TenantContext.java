package com.ruoyi.common.core.domain.model;

import java.io.Serializable;
import java.util.Collections;
import java.util.List;
import com.ruoyi.common.constant.TenantConstants;

/**
 * 租户上下文：描述当前请求归属的平台/代理商/商户身份
 *
 * @author dytuangou
 */
public class TenantContext implements Serializable
{
    private static final long serialVersionUID = 1L;

    /** 账号类型（0平台 1代理商 2商户），见 {@link TenantConstants} */
    private String userType = TenantConstants.USER_TYPE_MERCHANT;

    /** 商户ID（商户账号/小程序端有值） */
    private Long merchantId;

    /** 代理商ID（代理商账号有值） */
    private Long agentId;

    /** 代理商名下可见商户ID集合（代理商账号有值） */
    private List<Long> merchantIds = Collections.emptyList();

    public TenantContext()
    {
    }

    /**
     * 构造平台上下文（不受商户过滤）
     */
    public static TenantContext ofPlatform()
    {
        TenantContext context = new TenantContext();
        context.setUserType(TenantConstants.USER_TYPE_PLATFORM);
        return context;
    }

    /**
     * 构造商户上下文
     */
    public static TenantContext ofMerchant(Long merchantId)
    {
        TenantContext context = new TenantContext();
        context.setUserType(TenantConstants.USER_TYPE_MERCHANT);
        context.setMerchantId(merchantId);
        return context;
    }

    /**
     * 构造代理商上下文
     */
    public static TenantContext ofAgent(Long agentId, List<Long> merchantIds)
    {
        TenantContext context = new TenantContext();
        context.setUserType(TenantConstants.USER_TYPE_AGENT);
        context.setAgentId(agentId);
        context.setMerchantIds(merchantIds);
        return context;
    }

    /**
     * 是否平台账号（不做商户过滤）
     */
    public boolean isPlatform()
    {
        return TenantConstants.USER_TYPE_PLATFORM.equals(userType);
    }

    /**
     * 是否代理商账号
     */
    public boolean isAgent()
    {
        return TenantConstants.USER_TYPE_AGENT.equals(userType);
    }

    /**
     * 是否商户账号
     */
    public boolean isMerchant()
    {
        return TenantConstants.USER_TYPE_MERCHANT.equals(userType);
    }

    public String getUserType()
    {
        return userType;
    }

    public void setUserType(String userType)
    {
        this.userType = userType;
    }

    public Long getMerchantId()
    {
        return merchantId;
    }

    public void setMerchantId(Long merchantId)
    {
        this.merchantId = merchantId;
    }

    public Long getAgentId()
    {
        return agentId;
    }

    public void setAgentId(Long agentId)
    {
        this.agentId = agentId;
    }

    public List<Long> getMerchantIds()
    {
        return merchantIds;
    }

    public void setMerchantIds(List<Long> merchantIds)
    {
        this.merchantIds = merchantIds == null ? Collections.<Long> emptyList() : merchantIds;
    }
}
