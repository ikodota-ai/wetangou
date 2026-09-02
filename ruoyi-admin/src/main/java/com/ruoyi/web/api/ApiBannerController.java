package com.ruoyi.web.api;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.utils.image.ImageUrlUtils;
import com.ruoyi.biz.domain.Banner;
import com.ruoyi.biz.service.IBannerService;

/**
 * 小程序-首页 Banner（匿名）
 *
 * @author dytuangou
 * @date 2026-08-02
 */
@Anonymous
@RestController
@RequestMapping("/api/banner")
public class ApiBannerController
{
    @Autowired
    private IBannerService bannerService;

    /**
     * 拉取启用中的 banner
     *
     * @param position  位置（home/agent/distributor）
     * @param merchantId 商户ID（不传=平台通用）
     */
    @GetMapping("/list")
    public AjaxResult list(@RequestParam(value = "position", required = false) String position,
                           @RequestParam(value = "merchantId", required = false) Long merchantId)
    {
        Banner q = new Banner();
        q.setPosition(position == null ? "home" : position);
        q.setStatus("0");
        if (merchantId != null) {
            q.setMerchantId(merchantId);
        }
        List<Banner> list = bannerService.selectActiveBanners(q);
        // banner 图同样可能是 /profile/ 相对路径。小程序首页 <image src> 拿到
        // 相对路径会 404，页面上就是「后台配了轮播图但首页顶部空白」。
        if (list != null)
        {
            for (Banner b : list)
            {
                b.setImageUrl(ImageUrlUtils.toAbsolute(b.getImageUrl()));
            }
        }
        return AjaxResult.success(list);
    }
}
