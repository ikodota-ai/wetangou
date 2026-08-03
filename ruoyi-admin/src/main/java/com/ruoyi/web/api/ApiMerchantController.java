package com.ruoyi.web.api;

import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.biz.service.ITenantService;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.common.utils.image.ImageUrlUtils;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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
 *
 * <p>请求头 X-App-Id 缺失时兜底走 merchantId=1（默认商家 MC000001），方便本地开发。</p>
 */
@Anonymous
@RestController
@RequestMapping("/api/merchant")
public class ApiMerchantController
{
    private static final Logger log = LoggerFactory.getLogger(ApiMerchantController.class);

    /** 缺省 merchantId，仅用于本地开发/调试，避免 X-App-Id 漏传直接 401 */
    private static final long DEFAULT_MERCHANT_ID = 1L;

    @Autowired
    private ITenantService tenantService;

    /**
     * 当前商家信息
     */
    @GetMapping("/info")
    public AjaxResult info()
    {
        String appid = null;
        try
        {
            ServletRequestAttributes attrs = (ServletRequestAttributes) RequestContextHolder.currentRequestAttributes();
            HttpServletRequest req = attrs != null ? attrs.getRequest() : null;
            if (req != null)
            {
                appid = req.getHeader("X-App-Id");
            }
        }
        catch (Exception e)
        {
            log.debug("resolve X-App-Id failed: {}", e.getMessage());
        }

        Merchant merchant = null;
        if (StringUtils.isNotEmpty(appid))
        {
            merchant = tenantService.getMerchantByAppid(appid);
        }
        if (merchant == null)
        {
            // 兜底：缺省商家，避免小程序初次进入因头部问题拿到空数据
            merchant = tenantService.getMerchantById(DEFAULT_MERCHANT_ID);
        }
        if (merchant == null)
        {
            return AjaxResult.error("未匹配到商家");
        }

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("merchantId", merchant.getMerchantId());
        data.put("merchantNo", merchant.getMerchantNo());
        data.put("merchantName", merchant.getMerchantName());
        data.put("logo", safeAbsolute(merchant.getLogo()));
        data.put("intro", merchant.getIntro());
        // 商家级客服兜底信息
        data.put("servicePhone", merchant.getServicePhone());
        data.put("serviceQrcode", safeAbsolute(merchant.getServiceQrcode()));
        data.put("businessHours", merchant.getBusinessHours());
        return AjaxResult.success(data);
    }

    /**
     * 把相对路径补全为绝对 URL，防御 ImageUrlUtils 在错误恢复路径上再次抛异常。
     */
    private static String safeAbsolute(String path)
    {
        if (path == null || path.isEmpty())
        {
            return "";
        }
        try
        {
            return ImageUrlUtils.toAbsolute(path);
        }
        catch (Throwable t)
        {
            log.debug("ImageUrlUtils.toAbsolute failed for {}: {}", path, t.getMessage());
            return path;
        }
    }
}
