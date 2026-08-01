package com.ruoyi.biz.api.config;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Component;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.service.ISysConfigService;

/**
 * 微信开放平台第三方平台配置（平台级唯一，由「小程序平台配置」页维护）
 */
@Component
public class WxOpenConfig
{
    public static final String KEY_COMPONENT_APP_ID = "wx.open.componentAppId";
    public static final String KEY_COMPONENT_SECRET = "wx.open.componentSecret";
    public static final String KEY_VERIFY_TICKET = "wx.open.componentVerifyTicket";
    public static final String KEY_TEMPLATE_ID = "wx.open.templateId";

    @Autowired
    @Lazy
    private ISysConfigService sysConfigService;

    public String getComponentAppId() { return sysConfigService.selectConfigByKey(KEY_COMPONENT_APP_ID); }
    public String getComponentSecret() { return sysConfigService.selectConfigByKey(KEY_COMPONENT_SECRET); }
    public String getComponentVerifyTicket() { return sysConfigService.selectConfigByKey(KEY_VERIFY_TICKET); }
    public String getTemplateId() { return sysConfigService.selectConfigByKey(KEY_TEMPLATE_ID); }
}
