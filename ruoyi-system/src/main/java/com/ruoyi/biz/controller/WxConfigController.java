package com.ruoyi.biz.controller;

import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.enums.BusinessType;

/**
 * 微信配置Controller（默认商户的小程序登录/支付凭证，存储于sys_config）
 *
 * 多商户模式下各商户凭证维护在「商户管理」中，此处为平台默认商户的兜底配置。
 *
 * @author dytuangou
 */
@RestController
@RequestMapping("/biz/wxconfig")
public class WxConfigController extends BaseSysConfigController
{
    /** 该功能维护的参数键（key -> 参数名称） */
    private static final Map<String, String> KEY_NAMES = new LinkedHashMap<String, String>();
    static
    {
        KEY_NAMES.put("wx.miniapp.appId", "小程序AppId");
        KEY_NAMES.put("wx.miniapp.secret", "小程序AppSecret");
        KEY_NAMES.put("wx.miniapp.mockEnabled", "小程序mock登录开关");
        KEY_NAMES.put("wx.miniapp.envVersion", "小程序码指向版本");
        KEY_NAMES.put("wx.pay.mchId", "微信支付商户号");
        KEY_NAMES.put("wx.pay.appId", "微信支付AppId");
        KEY_NAMES.put("wx.pay.certSerialNo", "微信支付证书序列号");
        KEY_NAMES.put("wx.pay.privateKeyPath", "微信支付私钥路径");
        KEY_NAMES.put("wx.pay.apiV3Key", "微信支付APIv3密钥");
        KEY_NAMES.put("wx.pay.notifyUrl", "微信支付回调地址");
        KEY_NAMES.put("wx.pay.mockEnabled", "微信支付mock开关");
    }

    @Override
    protected Map<String, String> keyNames()
    {
        return KEY_NAMES;
    }

    @Override
    protected String configRemark()
    {
        return "微信配置";
    }

    /**
     * 获取微信配置
     */
    @PreAuthorize("@ss.hasPermi('biz:wxconfig:query')")
    @GetMapping
    public AjaxResult get()
    {
        return AjaxResult.success(readConfigs());
    }

    /**
     * 保存微信配置
     */
    @PreAuthorize("@ss.hasPermi('biz:wxconfig:edit')")
    @Log(title = "微信配置", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult save(@RequestBody Map<String, String> body)
    {
        writeConfigs(body);
        return AjaxResult.success();
    }
}
