package com.ruoyi.web.api;

import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.biz.service.ITenantService;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.common.utils.image.ImageUrlUtils;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 小程序-商家公开信息
 *
 * <p>匿名接口（不要求登录），根据请求头 X-App-Id 解析当前商家，
 * 返回小程序需要的商家基础信息：商家名、logo、客服电话、客服二维码、营业时间、简介。
 * 登录页/我的页/联系客服等需要展示商家信息的地方都走这里。</p>
 */
@Anonymous
@RestController
@RequestMapping("/api/merchant")
public class ApiMerchantController
{
    @Autowired
    private ITenantService tenantService;

    /**
     * 当前商家信息
     */
    @GetMapping("/info")
    public AjaxResult info()
    {
        HttpServletRequest req = ((ServletRequestAttributes) RequestContextHolder.currentRequestAttributes()).getRequest();
        String appid = req.getHeader("X-App-Id");
        Merchant merchant = null;
        if (StringUtils.isNotEmpty(appid)) {
            merchant = tenantService.getMerchantByAppid(appid);
        }
        if (merchant == null) {
            return AjaxResult.error("未匹配到商家");
        }
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("merchantId", merchant.getMerchantId());
        data.put("merchantNo", merchant.getMerchantNo());
        data.put("merchantName", merchant.getMerchantName());
        data.put("logo", merchant.getLogo() != null ? ImageUrlUtils.toAbsolute(merchant.getLogo()) : "");
        data.put("intro", merchant.getIntro());
        // 商家级客服兜底信息
        data.put("servicePhone", merchant.getServicePhone());
        data.put("serviceQrcode", merchant.getServiceQrcode() != null ? ImageUrlUtils.toAbsolute(merchant.getServiceQrcode()) : "");
        data.put("businessHours", merchant.getBusinessHours());
        return AjaxResult.success(data);
    }
}
