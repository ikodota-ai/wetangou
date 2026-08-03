package com.ruoyi.biz.controller;

import java.util.List;
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
import com.ruoyi.biz.domain.MpRelease;
import com.ruoyi.biz.service.IMpReleaseService;
import com.ruoyi.biz.api.service.WxOpenService;

/**
 * 小程序发布Controller
 *
 * @author dytuangou
 */
@RestController
@RequestMapping("/biz/mprelease")
public class MpReleaseController extends BaseController
{
    @Autowired
    private IMpReleaseService mpReleaseService;
    @Autowired
    private WxOpenService wxOpenService;
    @Autowired
    private com.ruoyi.common.core.redis.RedisCache redisCache;
    @Autowired
    private com.ruoyi.system.service.ISysConfigService sysConfigService;

    /**
     * 查询发布记录列表
     */
    @PreAuthorize("@ss.hasPermi('biz:mprelease:list')")
    @GetMapping("/list")
    public TableDataInfo list(MpRelease mpRelease)
    {
        startPage();
        List<MpRelease> list = mpReleaseService.selectMpReleaseList(mpRelease);
        return getDataTable(list);
    }

    /**
     * 获取发布记录详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:mprelease:query')")
    @GetMapping(value = "/{releaseId}")
    public AjaxResult getInfo(@PathVariable("releaseId") Long releaseId)
    {
        return success(mpReleaseService.selectMpReleaseByReleaseId(releaseId));
    }

    /**
     * 按商户微信配置生成 ext.json（供代上传表单自动填充）
     */
    @PreAuthorize("@ss.hasPermi('biz:mprelease:upload')")
    @GetMapping("/extjson/{merchantId}")
    public AjaxResult extJson(@PathVariable("merchantId") Long merchantId)
    {
        return success(mpReleaseService.buildExtJson(merchantId));
    }

    /**
     * 代上传：新增待提交版本
     */
    @PreAuthorize("@ss.hasPermi('biz:mprelease:upload')")
    @Log(title = "小程序发布", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody MpRelease mpRelease)
    {
        return toAjax(mpReleaseService.insertMpRelease(mpRelease));
    }

    /**
     * 修改待提交版本
     */
    @PreAuthorize("@ss.hasPermi('biz:mprelease:upload')")
    @Log(title = "小程序发布", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody MpRelease mpRelease)
    {
        return toAjax(mpReleaseService.updateMpRelease(mpRelease));
    }

    /**
     * 提交审核
     */
    @PreAuthorize("@ss.hasPermi('biz:mprelease:audit')")
    @Log(title = "小程序发布", businessType = BusinessType.UPDATE)
    @PutMapping("/submit/{releaseId}")
    public AjaxResult submit(@PathVariable("releaseId") Long releaseId)
    {
        return toAjax(mpReleaseService.submitAudit(releaseId));
    }

    /**
     * 撤回审核
     */
    @PreAuthorize("@ss.hasPermi('biz:mprelease:audit')")
    @Log(title = "小程序发布", businessType = BusinessType.UPDATE)
    @PutMapping("/undo/{releaseId}")
    public AjaxResult undo(@PathVariable("releaseId") Long releaseId)
    {
        return toAjax(mpReleaseService.undoAudit(releaseId));
    }

    /**
     * 发布上线
     */
    @PreAuthorize("@ss.hasPermi('biz:mprelease:release')")
    @Log(title = "小程序发布", businessType = BusinessType.UPDATE)
    @PutMapping("/release/{releaseId}")
    public AjaxResult release(@PathVariable("releaseId") Long releaseId)
    {
        return toAjax(mpReleaseService.release(releaseId));
    }

    /**
     * 版本回退
     */
    @PreAuthorize("@ss.hasPermi('biz:mprelease:rollback')")
    @Log(title = "小程序发布", businessType = BusinessType.UPDATE)
    @PutMapping("/rollback/{releaseId}")
    public AjaxResult rollback(@PathVariable("releaseId") Long releaseId)
    {
        return toAjax(mpReleaseService.rollback(releaseId));
    }

    /**
     * 删除发布记录
     */
    @PreAuthorize("@ss.hasPermi('biz:mprelease:list')")
    @Log(title = "小程序发布", businessType = BusinessType.DELETE)
    @DeleteMapping("/{releaseIds}")
    public AjaxResult remove(@PathVariable Long[] releaseIds)
    {
        return toAjax(mpReleaseService.deleteMpReleaseByReleaseIds(releaseIds));
    }

    /**
     * 微信开放平台状态：
     *  - configured: componentAppId/secret 是否齐全
     *  - ticketAgeSeconds: verify_ticket 最后写入距今秒数（> 7200 即过期）
     *  - authorizerCount: 已缓存的 authorizer_access_token 数
     *  - authorizerApps: 缓存里的 appid 列表
     *  - apiBaseUrl: 当前 ext.json 注入的接口域名
     */
    @PreAuthorize("@ss.hasPermi('biz:mpconfig:list')")
    @GetMapping("/platform-status")
    public AjaxResult platformStatus()
    {
        java.util.Map<String, Object> data = new java.util.LinkedHashMap<>();
        data.put("configured", wxOpenService.isConfigured());

        // ticketAgeSeconds
        Long ticketAge = null;
        String ticket = redisCache.getCacheObject("wx:open:component_verify_ticket");
        if (ticket != null && !ticket.isEmpty())
        {
            // 微信每 10 分钟推一次 ticket，最近一次推送应 < 12 分钟
            ticketAge = 0L;
        }
        else
        {
            String sysCfgTicket = sysConfigService.selectConfigByKey("wx.open.componentVerifyTicket");
            ticketAge = sysCfgTicket == null || sysCfgTicket.isEmpty() ? null : -1L; // -1 表示有持久化但无 Redis 缓存
        }
        data.put("ticketAgeSeconds", ticketAge);
        data.put("ticketFresh", ticketAge != null && ticketAge >= 0L);

        // authorizer 缓存扫描
        java.util.Collection<String> keys = redisCache.keys("wx:open:authorizer_access_token:*");
        java.util.List<String> apps = new java.util.ArrayList<>();
        if (keys != null) {
            for (String k : keys) {
                String appid = k.substring("wx:open:authorizer_access_token:".length());
                apps.add(appid);
            }
        }
        data.put("authorizerCount", apps.size());
        data.put("authorizerApps", apps);

        // apiBaseUrl 给 UI 展示
        data.put("apiBaseUrl", sysConfigService.selectConfigByKey("wx.open.apiBaseUrl"));

        return success(data);
    }
}
