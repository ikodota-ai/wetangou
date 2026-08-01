package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.common.core.domain.model.TenantContext;

/**
 * 租户解析Service接口：负责账号归属、appid与商户的映射关系
 *
 * @author dytuangou
 */
public interface ITenantService
{
    /**
     * 按后台用户ID构建租户上下文
     *
     * @param userId 系统用户ID
     * @return 租户上下文，未配置归属时返回平台上下文
     */
    public TenantContext buildContextByUserId(Long userId);

    /**
     * 按小程序appid查询商户（带缓存）
     *
     * @param appid 小程序appid
     * @return 商户，不存在返回null
     */
    public Merchant getMerchantByAppid(String appid);

    /**
     * 按商户ID查询商户（带缓存）
     *
     * @param merchantId 商户ID
     * @return 商户，不存在返回null
     */
    public Merchant getMerchantById(Long merchantId);

    /**
     * 查询代理商名下商户ID列表
     *
     * @param agentId 代理商ID
     * @return 商户ID集合
     */
    public List<Long> getMerchantIdsByAgentId(Long agentId);

    /**
     * 清除商户缓存
     *
     * @param merchantId 商户ID
     */
    public void clearMerchantCache(Long merchantId);

    /**
     * 清除账号归属缓存
     *
     * @param userId 系统用户ID
     */
    public void clearUserCache(Long userId);
}
