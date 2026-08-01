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
     * <p>所有环境（含 dev/prod）默认关闭；只有显式配置 {@code wx.pay.mockEnabled=true} 时才开启，
     * 避免本地缺凭证时支付流程误走 mock 被告知「支付成功」实际没落库。
     * 本地联调请按需临时打开，并确认不会发布到生产环境。</p>
     */
    public boolean isMockEnabled()
    {
        String value = sysConfigService.selectConfigByKey(KEY_MOCK_ENABLED);
        // 未配置时默认关闭 mock；只接受显式 true（兼容历史 true/false 大小写）
        return "true".equalsIgnoreCase(StringUtils.trimToEmpty(value));
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
