package com.ruoyi.web.api;

import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.biz.service.ITenantService;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.constant.HttpStatus;
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
 * <p>多租户契约：一个 appid 对应唯一商户。请求头 X-App-Id 缺失或未匹配到商家
 * 一律返回 400 "未匹配到商家"，不再静默兜底到默认商户，避免前端忘带 header 时
 * 拿到别人家的数据而 bug 难以暴露。</p>
 */
@Anonymous
@RestController
@RequestMapping("/api/merchant")
public class ApiMerchantController
{
    private static final Logger log = LoggerFactory.getLogger(ApiMerchantController.class);

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

        if (StringUtils.isEmpty(appid))
        {
            return AjaxResult.error(HttpStatus.BAD_REQUEST, "缺少 X-App-Id 请求头");
        }
        Merchant merchant = tenantService.getMerchantByAppid(appid);
        if (merchant == null)
        {
            return AjaxResult.error(HttpStatus.BAD_REQUEST, "未匹配到商家");
        }

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("merchantId", merchant.getMerchantId());
        data.put("merchantNo", merchant.getMerchantNo());
        data.put("merchantName", merchant.getMerchantName());
        data.put("logo", safeAbsolute(merchant.getLogo()));
        data.put("intro", merchant.getIntro());
        // 商家级客服兜底信息。
        // phone 和 servicePhone 是两码事，都要返：
        //   phone        商家对外电话 —— 门店没填门店电话时，「拨打电话」降级用它
        //   servicePhone 商家客服热线 —— 门店没填客服电话时，「在线咨询」降级用它
        // 之前只返了 servicePhone，导致门店电话为空时前端无从降级，
        // 表现为「明明后台填了商家电话，小程序仍提示没有设置」。
        data.put("phone", merchant.getPhone());
        data.put("servicePhone", merchant.getServicePhone());
        data.put("serviceQrcode", safeAbsolute(merchant.getServiceQrcode()));
        data.put("businessHours", merchant.getBusinessHours());
        data.put("serviceHours", merchant.getServiceHours());
        // 推客总开关。必须兜底成 '1'（启用）而不是直接透传：
        // 商户缓存（merchant:appid:*）是永不过期的 fastjson 序列化对象，
        // 新增 promoter_enabled 列前写进 Redis 的那份快照里根本没这个 key，
        // 反序列化回来就是 null —— 实测本地 merchant 1 库里是 '1'，
        // 接口却返 null，小程序据此判定未开通，已开通商户的推客入口凭空消失。
        // 加了列之后老缓存不会自动失效（没 TTL，只有编辑商户才 evict），
        // 所以这个兜底在生产上线那一刻就会生效，不能省。
        String promoterEnabled = merchant.getPromoterEnabled();
        data.put("promoterEnabled", StringUtils.isEmpty(promoterEnabled) ? "1" : promoterEnabled);
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
