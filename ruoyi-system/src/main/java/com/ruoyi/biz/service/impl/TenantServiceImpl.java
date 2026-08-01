package com.ruoyi.biz.service.impl;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.biz.domain.MerchantUser;
import com.ruoyi.biz.mapper.MerchantMapper;
import com.ruoyi.biz.mapper.MerchantUserMapper;
import com.ruoyi.biz.service.ITenantService;
import com.ruoyi.common.constant.TenantConstants;
import com.ruoyi.common.core.domain.model.TenantContext;
import com.ruoyi.common.core.redis.RedisCache;
import com.ruoyi.common.utils.StringUtils;

/**
 * 租户解析Service业务层处理
 *
 * @author dytuangou
 */
@Service
public class TenantServiceImpl implements ITenantService
{
    @Autowired
    private MerchantMapper merchantMapper;

    @Autowired
    private MerchantUserMapper merchantUserMapper;

    @Autowired
    private RedisCache redisCache;

    /**
     * 按后台用户ID构建租户上下文
     *
     * <p>未在 biz_merchant_user 配置归属的账号（如初始 admin）按平台账号处理，
     * 保证升级后老账号行为不变。</p>
     */
    @Override
    public TenantContext buildContextByUserId(Long userId)
    {
        if (userId == null)
        {
            return TenantContext.ofPlatform();
        }
        MerchantUser merchantUser = merchantUserMapper.selectMerchantUserByUserId(userId);
        if (merchantUser == null || StringUtils.isEmpty(merchantUser.getUserType()))
        {
            return TenantContext.ofPlatform();
        }
        String userType = merchantUser.getUserType();
        if (TenantConstants.USER_TYPE_PLATFORM.equals(userType))
        {
            return TenantContext.ofPlatform();
        }
        if (TenantConstants.USER_TYPE_AGENT.equals(userType))
        {
            Long agentId = merchantUser.getAgentId();
            return TenantContext.ofAgent(agentId, getMerchantIdsByAgentId(agentId));
        }
        return TenantContext.ofMerchant(merchantUser.getMerchantId());
    }

    /**
     * 按小程序appid查询商户（带缓存）
     */
    @Override
    public Merchant getMerchantByAppid(String appid)
    {
        if (StringUtils.isEmpty(appid))
        {
            return null;
        }
        String cacheKey = TenantConstants.MERCHANT_APPID_KEY + appid;
        Merchant cached = redisCache.getCacheObject(cacheKey);
        if (cached != null)
        {
            return cached;
        }
        Merchant merchant = merchantMapper.selectMerchantByAppid(appid);
        if (merchant != null)
        {
            redisCache.setCacheObject(cacheKey, merchant);
        }
        return merchant;
    }

    /**
     * 按商户ID查询商户（带缓存）
     */
    @Override
    public Merchant getMerchantById(Long merchantId)
    {
        if (merchantId == null)
        {
            return null;
        }
        String cacheKey = TenantConstants.MERCHANT_ID_KEY + merchantId;
        Merchant cached = redisCache.getCacheObject(cacheKey);
        if (cached != null)
        {
            return cached;
        }
        Merchant merchant = merchantMapper.selectMerchantByMerchantId(merchantId);
        if (merchant != null)
        {
            redisCache.setCacheObject(cacheKey, merchant);
        }
        return merchant;
    }

    /**
     * 查询代理商名下商户ID列表
     */
    @Override
    public List<Long> getMerchantIdsByAgentId(Long agentId)
    {
        if (agentId == null)
        {
            return java.util.Collections.emptyList();
        }
        return merchantMapper.selectMerchantIdsByAgentId(agentId);
    }

    /**
     * 清除商户缓存（appid变更时需同时清除appid维度缓存）
     */
    @Override
    public void clearMerchantCache(Long merchantId)
    {
        if (merchantId == null)
        {
            return;
        }
        Merchant merchant = merchantMapper.selectMerchantByMerchantId(merchantId);
        if (merchant != null && StringUtils.isNotEmpty(merchant.getAppid()))
        {
            redisCache.deleteObject(TenantConstants.MERCHANT_APPID_KEY + merchant.getAppid());
        }
        redisCache.deleteObject(TenantConstants.MERCHANT_ID_KEY + merchantId);
    }

    /**
     * 清除账号归属缓存
     */
    @Override
    public void clearUserCache(Long userId)
    {
        if (userId != null)
        {
            redisCache.deleteObject(TenantConstants.MERCHANT_USER_KEY + userId);
        }
    }
}
