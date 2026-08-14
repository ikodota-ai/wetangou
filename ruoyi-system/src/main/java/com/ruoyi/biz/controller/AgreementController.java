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
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.biz.domain.Agreement;
import com.ruoyi.biz.service.IAgreementService;
import com.ruoyi.common.utils.poi.ExcelUtil;
import com.ruoyi.biz.tenant.TenantFilterHelper;
import com.ruoyi.common.core.domain.BaseEntity;
import com.ruoyi.common.core.page.TableDataInfo;

/**
 * 协议Controller
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@RestController
@RequestMapping("/biz/agreement")
public class AgreementController extends BaseController
{
    @Autowired
    private IAgreementService agreementService;

    /**
     * 查询协议列表
     */
    @PreAuthorize("@ss.hasPermi('biz:agreement:list')")
    @GetMapping("/list")
    public TableDataInfo list(Agreement agreement)
    {
        TenantFilterHelper.apply((BaseEntity) agreement,
                                  (e, v) -> ((com.ruoyi.biz.domain.Agreement) e).setMerchantId(v),
                                  e -> ((com.ruoyi.biz.domain.Agreement) e).getMerchantId());
        startPage();
        List<Agreement> list = agreementService.selectAgreementList(agreement);
        return getDataTable(list);
    }

    /**
     * 导出协议列表
     */
    @PreAuthorize("@ss.hasPermi('biz:agreement:export')")
    @Log(title = "协议", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, Agreement agreement)
    {
        TenantFilterHelper.apply((BaseEntity) agreement,
                                  (e, v) -> ((com.ruoyi.biz.domain.Agreement) e).setMerchantId(v),
                                  e -> ((com.ruoyi.biz.domain.Agreement) e).getMerchantId());
        List<Agreement> list = agreementService.selectAgreementList(agreement);
        ExcelUtil<Agreement> util = new ExcelUtil<Agreement>(Agreement.class);
        util.exportExcel(response, list, "协议数据");
    }

    /**
     * 获取协议详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:agreement:query')")
    @GetMapping(value = "/{agreementId}")
    public AjaxResult getInfo(@PathVariable("agreementId") Long agreementId)
    {
        return success(agreementService.selectAgreementByAgreementId(agreementId));
    }

    /**
     * 新增协议
     */
    @PreAuthorize("@ss.hasPermi('biz:agreement:add')")
    @Log(title = "协议", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody Agreement agreement)
    {
        return toAjax(agreementService.insertAgreement(agreement));
    }

    /**
     * 修改协议
     */
    @PreAuthorize("@ss.hasPermi('biz:agreement:edit')")
    @Log(title = "协议", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody Agreement agreement)
    {
        return toAjax(agreementService.updateAgreement(agreement));
    }

    /**
     * 删除协议
     */
    @PreAuthorize("@ss.hasPermi('biz:agreement:remove')")
    @Log(title = "协议", businessType = BusinessType.DELETE)
	@DeleteMapping("/{agreementIds}")
    public AjaxResult remove(@PathVariable Long[] agreementIds)
    {
        return toAjax(agreementService.deleteAgreementByAgreementIds(agreementIds));
    }
}
