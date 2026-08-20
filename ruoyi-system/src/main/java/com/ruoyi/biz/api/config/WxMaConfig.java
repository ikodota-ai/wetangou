package com.ruoyi.biz.api.config;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Component;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.service.ISysConfigService;
import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.biz.service.ITenantService;

/**
 * 微信小程序配置
 *
 * <p>配置项统一存储在系统参数（sys_config）中，通过后台“微信配置”页面维护，
 * 带 Redis 缓存，修改后即时生效，无需重启或改动 application.yml。</p>
 *
 * @author dytuangou
 */
@Component
public class WxMaConfig
{
    /** 参数key：小程序appId */
    public static final String KEY_APP_ID = "wx.miniapp.appId";

    /** 参数key：小程序appSecret */
    public static final String KEY_SECRET = "wx.miniapp.secret";

    /** 参数key：是否开启mock登录 */
    public static final String KEY_MOCK_ENABLED = "wx.miniapp.mockEnabled";

    @Autowired
    @Lazy
    private ISysConfigService sysConfigService;

    @Autowired
    @Lazy
    private ITenantService tenantService;

    @Autowired
    private org.springframework.core.env.Environment environment;

    public String getAppId()
    {
        return sysConfigService.selectConfigByKey(KEY_APP_ID);
    }

    public String getSecret()
    {
        return sysConfigService.selectConfigByKey(KEY_SECRET);
    }

    /**
     * 获取指定商户的小程序appId，商户未配置时回退到全局参数
     *
     * @param merchantId 商户ID
     * @return appId
     */
    public String getAppId(Long merchantId)
    {
        Merchant merchant = getMerchant(merchantId);
        if (merchant != null && StringUtils.isNotEmpty(merchant.getAppid()))
        {
            return merchant.getAppid();
        }
        return getAppId();
    }

    /**
     * 获取指定商户的小程序appSecret，商户未配置时回退到全局参数
     *
     * @param merchantId 商户ID
     * @return appSecret
     */
    public String getSecret(Long merchantId)
    {
        Merchant merchant = getMerchant(merchantId);
        if (merchant != null && StringUtils.isNotEmpty(merchant.getAppSecret()))
        {
            return merchant.getAppSecret();
        }
        return getSecret();
    }

    /**
     * 指定商户是否开启mock登录（商户配置优先，mock_enabled为'0'表示开启）
     *
     * @param merchantId 商户ID
     * @return 是否开启mock
     */
    public boolean isMockEnabled(Long merchantId)
    {
        // 生产环境强制关闭，与无参版本保持一致
        if (isProductionProfile())
        {
            return false;
        }
        Merchant merchant = getMerchant(merchantId);
        if (merchant != null && StringUtils.isNotEmpty(merchant.getMockEnabled()))
        {
            return "0".equals(merchant.getMockEnabled());
        }
        return isMockEnabled();
    }

    /**
     * 读取商户配置，商户ID为空时返回null
     */
    private Merchant getMerchant(Long merchantId)
    {
        return merchantId == null ? null : tenantService.getMerchantById(merchantId);
    }

    /**
     * 是否开启mock登录（无真实凭证时用于本地联调，用code直接作为openid）
     *
     * <p>生产环境（{@code spring.profiles.active=prod}）强制返回 false，
     * 即便 sys_config 被误改也无效；本地 dev/test profile 下才读 sys_config。</p>
     */
    public boolean isMockEnabled()
    {
        if (isProductionProfile())
        {
            return false;
        }
        String value = sysConfigService.selectConfigByKey(KEY_MOCK_ENABLED);
        return StringUtils.isNotEmpty(value) && "true".equalsIgnoreCase(value.trim());
    }

    /** 视为生产环境的 profile 名（一律强制关闭 mock） */
    private static final java.util.Set<String> PRODUCTION_PROFILES =
            new java.util.HashSet<>(java.util.Arrays.asList("prod", "production", "aliyun-oss", "oss", "minio", "cos", "qiniu"));

    /**
     * 是否处于「生产语义」的 profile。
     *
     * <p>除了 {@code prod}，还认 {@code aliyun-oss}（以及其他真实云存储 profile）：
     * 部署文档教的是 {@code -Dspring.profiles.active=aliyun-oss}，如果只认 prod，
     * 这种启法下 mock 开关会退回读 sys_config —— 而库里存量值可能是 true，
     * 生产就会走 mock 支付/mock 登录（钱收不到、任何 code 都能登录）。</p>
     */
    private boolean isProductionProfile()
    {
        String[] profiles = environment.getActiveProfiles();
        if (profiles == null) return false;
        for (String p : profiles)
        {
            if (p == null) continue;
            if (PRODUCTION_PROFILES.contains(p.trim().toLowerCase())) return true;
        }
        return false;
    }
}
