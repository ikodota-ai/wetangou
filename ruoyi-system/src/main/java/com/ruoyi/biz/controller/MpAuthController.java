package com.ruoyi.biz.controller;

import java.util.List;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
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
import com.ruoyi.biz.domain.MpAuth;
import com.ruoyi.biz.service.IMpAuthService;

@RestController
@RequestMapping("/biz/mpauth")
public class MpAuthController extends BaseController
{
    @Autowired
    private IMpAuthService mpAuthService;

    @PreAuthorize("@ss.hasPermi('biz:mpauth:list')")
    @GetMapping("/list")
    public TableDataInfo list(MpAuth mpAuth)
    {
        startPage();
        List<MpAuth> list = mpAuthService.selectMpAuthList(mpAuth);
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('biz:mpauth:export')")
    @Log(title = "小程序授权", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, MpAuth mpAuth)
    {
        List<MpAuth> list = mpAuthService.selectMpAuthList(mpAuth);
        ExcelUtil<MpAuth> util = new ExcelUtil<MpAuth>(MpAuth.class);
        util.exportExcel(response, list, "小程序授权数据");
    }

    @PreAuthorize("@ss.hasPermi('biz:mpauth:query')")
    @GetMapping(value = "/{authId}")
    public AjaxResult getInfo(@PathVariable("authId") Long authId)
    {
        MpAuth mpAuth = mpAuthService.selectMpAuthByAuthId(authId);
        if (mpAuth != null)
        {
            TenantFilterHelper.assertDataScope(mpAuth.getMerchantId());
        }
        return AjaxResult.success(mpAuth);
    }

    /**
     * 按 appid 查授权记录
     *
     * <p>前端 api/biz/mprelease.js 的 getMpAuth(appid) 调的是本端点。
     * 必须声明在 /{authId} 之后无效——Spring 按精确度匹配，
     * 但 /appid/{appid} 多一段路径，不会与 /{authId} 冲突。
     * 此前缺失该端点时，请求会落到 /{authId} 上，
     * appid 字符串转 Long 失败直接 500。</p>
     */
    @PreAuthorize("@ss.hasPermi('biz:mpauth:query')")
    @GetMapping("/appid/{appid}")
    public AjaxResult getInfoByAppid(@PathVariable("appid") String appid)
    {
        MpAuth mpAuth = mpAuthService.selectMpAuthByAppid(appid);
        if (mpAuth != null)
        {
            TenantFilterHelper.assertDataScope(mpAuth.getMerchantId());
        }
        return AjaxResult.success(mpAuth);
    }

    @PreAuthorize("@ss.hasPermi('biz:mpauth:add')")
    @Log(title = "小程序授权", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody MpAuth mpAuth)
    {
        return toAjax(mpAuthService.insertMpAuth(mpAuth));
    }

    @PreAuthorize("@ss.hasPermi('biz:mpauth:edit')")
    @Log(title = "小程序授权", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody MpAuth mpAuth)
    {
        return toAjax(mpAuthService.updateMpAuth(mpAuth));
    }

    @PreAuthorize("@ss.hasPermi('biz:mpauth:remove')")
    @Log(title = "小程序授权", businessType = BusinessType.DELETE)
    @DeleteMapping("/{authIds}")
    public AjaxResult remove(@PathVariable Long[] authIds)
    {
        return toAjax(mpAuthService.deleteMpAuthByAuthIds(authIds));
    }
}
