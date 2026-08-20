package com.ruoyi.biz.api.config;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Component;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.service.ISysConfigService;

/**
 * 微信支付V3配置
 *
 * <p>配置项统一存储在系统参数（sys_config）中，通过后台“微信配置”页面维护，
 * 带 Redis 缓存，修改后即时生效，无需重启或改动 application.yml。</p>
 *
 * @author dytuangou
 */
@Component
public class WxPayConfig
{
    /** 参数key：商户号 */
    public static final String KEY_MCH_ID = "wx.pay.mchId";

    /** 参数key：小程序appId（与登录appId一致） */
    public static final String KEY_APP_ID = "wx.pay.appId";

    /** 参数key：商户API证书序列号 */
    public static final String KEY_CERT_SERIAL_NO = "wx.pay.certSerialNo";

    /** 参数key：商户API私钥文件路径 */
    public static final String KEY_PRIVATE_KEY_PATH = "wx.pay.privateKeyPath";

    /** 参数key：APIv3密钥 */
    public static final String KEY_API_V3_KEY = "wx.pay.apiV3Key";

    /** 参数key：支付结果回调地址 */
    public static final String KEY_NOTIFY_URL = "wx.pay.notifyUrl";

    /** 参数key：是否开启mock支付 */
    public static final String KEY_MOCK_ENABLED = "wx.pay.mockEnabled";

    @Autowired
    @Lazy
    private ISysConfigService sysConfigService;

    @Autowired
    private org.springframework.core.env.Environment environment;

    public String getMchId()
    {
        return sysConfigService.selectConfigByKey(KEY_MCH_ID);
    }

    public String getAppId()
    {
        return sysConfigService.selectConfigByKey(KEY_APP_ID);
    }

    public String getCertSerialNo()
    {
        return sysConfigService.selectConfigByKey(KEY_CERT_SERIAL_NO);
    }

    public String getPrivateKeyPath()
    {
        return sysConfigService.selectConfigByKey(KEY_PRIVATE_KEY_PATH);
    }

    public String getApiV3Key()
    {
        return sysConfigService.selectConfigByKey(KEY_API_V3_KEY);
    }

    public String getNotifyUrl()
    {
        return sysConfigService.selectConfigByKey(KEY_NOTIFY_URL);
    }

    /**
     * 是否开启mock支付。
     *
     * <p>生产环境（{@code spring.profiles.active=prod}）强制返回 false，
     * 即便 sys_config 被误改为 true 也无效，避免生产误走 mock 导致钱收不到。
     * 本地联调请在 dev/test profile 下配置 {@code wx.pay.mockEnabled=true}。</p>
     */
    public boolean isMockEnabled()
    {
        if (isProductionProfile())
        {
            return false;
        }
        String value = sysConfigService.selectConfigByKey(KEY_MOCK_ENABLED);
        return "true".equalsIgnoreCase(StringUtils.trimToEmpty(value));
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

    /**
     * 是否配置齐全（可走真实支付）
     */
    public boolean isConfigured()
    {
        return StringUtils.isNotEmpty(getMchId())
                && StringUtils.isNotEmpty(getAppId())
                && StringUtils.isNotEmpty(getCertSerialNo())
                && StringUtils.isNotEmpty(getPrivateKeyPath())
                && StringUtils.isNotEmpty(getApiV3Key());
    }
}
