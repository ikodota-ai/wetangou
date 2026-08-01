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
 * 小程序平台配置Controller（微信开放平台第三方平台参数，平台级唯一）
 *
 * 这些参数原先只能在「系统参数」里按 key 逐条修改，改为独立页面集中维护，
 * 小程序代发布与 ext.json 生成均从此处读取。
 *
 * @author dytuangou
 */
@RestController
@RequestMapping("/biz/mpconfig")
public class MpConfigController extends BaseSysConfigController
{
    /** 该功能维护的参数键（key -> 参数名称） */
    private static final Map<String, String> KEY_NAMES = new LinkedHashMap<String, String>();
    static
    {
        KEY_NAMES.put("wx.open.componentAppId", "开放平台第三方AppId");
        KEY_NAMES.put("wx.open.componentSecret", "开放平台第三方Secret");
        KEY_NAMES.put("wx.open.componentToken", "开放平台消息校验Token");
        KEY_NAMES.put("wx.open.componentAesKey", "开放平台消息加密Key");
        KEY_NAMES.put("wx.open.templateId", "小程序代码模板ID");
        KEY_NAMES.put("wx.open.redirectDomain", "授权回调域名");
        KEY_NAMES.put("wx.open.apiBaseUrl", "小程序接口域名");
    }

    @Override
    protected Map<String, String> keyNames()
    {
        return KEY_NAMES;
    }

    @Override
    protected String configRemark()
    {
        return "小程序代发布";
    }

    /**
     * 获取小程序平台配置
     */
    @PreAuthorize("@ss.hasPermi('biz:mpconfig:query')")
    @GetMapping
    public AjaxResult get()
    {
        return AjaxResult.success(readConfigs());
    }

    /**
     * 保存小程序平台配置
     */
    @PreAuthorize("@ss.hasPermi('biz:mpconfig:edit')")
    @Log(title = "小程序平台配置", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult save(@RequestBody Map<String, String> body)
    {
        writeConfigs(body);
        return AjaxResult.success();
    }
}
