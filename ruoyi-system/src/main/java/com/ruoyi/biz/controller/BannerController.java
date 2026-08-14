package com.ruoyi.biz.controller;

import java.util.List;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.common.utils.poi.ExcelUtil;
import com.ruoyi.biz.tenant.TenantFilterHelper;
import com.ruoyi.biz.domain.Banner;
import com.ruoyi.biz.service.IBannerService;

/**
 * 首页轮播图 Controller
 *
 * @author dytuangou
 * @date 2026-08-02
 */
@RestController
@RequestMapping("/biz/banner")
public class BannerController extends BaseController
{
    @Autowired
    private IBannerService bannerService;

    @PreAuthorize("@ss.hasPermi('biz:banner:list')")
    @GetMapping("/list")
    public TableDataInfo list(Banner banner)
    {
        startPage();
        List<Banner> list = bannerService.selectBannerList(banner);
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('biz:banner:export')")
    @Log(title = "首页轮播图", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, Banner banner)
    {
        List<Banner> list = bannerService.selectBannerList(banner);
        ExcelUtil<Banner> util = new ExcelUtil<Banner>(Banner.class);
        util.exportExcel(response, list, "首页轮播图数据");
    }

    @PreAuthorize("@ss.hasPermi('biz:banner:query')")
    @GetMapping(value = "/{bannerId}")
    public AjaxResult getInfo(@PathVariable("bannerId") Long bannerId)
    {
        Banner banner = bannerService.selectBannerByBannerId(bannerId);
        if (banner != null)
        {
            TenantFilterHelper.assertDataScope(banner.getMerchantId());
        }
        return success(banner);
    }

    @PreAuthorize("@ss.hasPermi('biz:banner:add')")
    @Log(title = "首页轮播图", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody Banner banner)
    {
        return toAjax(bannerService.insertBanner(banner));
    }

    @PreAuthorize("@ss.hasPermi('biz:banner:edit')")
    @Log(title = "首页轮播图", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody Banner banner)
    {
        return toAjax(bannerService.updateBanner(banner));
    }

    @PreAuthorize("@ss.hasPermi('biz:banner:remove')")
    @Log(title = "首页轮播图", businessType = BusinessType.DELETE)
    @DeleteMapping("/{bannerIds}")
    public AjaxResult remove(@PathVariable Long[] bannerIds)
    {
        return toAjax(bannerService.deleteBannerByBannerIds(bannerIds));
    }
}
