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
}
