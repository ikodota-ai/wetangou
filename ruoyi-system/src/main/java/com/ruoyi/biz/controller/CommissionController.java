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
import com.ruoyi.biz.domain.Commission;
import com.ruoyi.biz.service.ICommissionService;
import com.ruoyi.biz.api.service.SettlementService;
import com.ruoyi.common.utils.poi.ExcelUtil;
import com.ruoyi.biz.tenant.TenantFilterHelper;
import com.ruoyi.common.core.domain.BaseEntity;
import com.ruoyi.common.core.page.TableDataInfo;

/**
 * 佣金明细Controller
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@RestController
@RequestMapping("/biz/commission")
public class CommissionController extends BaseController
{
    @Autowired
    private ICommissionService commissionService;

    @Autowired
    private SettlementService settlementService;

    /**
     * 查询佣金明细列表
     */
    @PreAuthorize("@ss.hasPermi('biz:commission:list')")
    @GetMapping("/list")
    public TableDataInfo list(Commission commission)
    {
        TenantFilterHelper.apply((BaseEntity) commission,
                                  (e, v) -> ((com.ruoyi.biz.domain.Commission) e).setMerchantId(v),
                                  e -> ((com.ruoyi.biz.domain.Commission) e).getMerchantId());
        startPage();
        List<Commission> list = commissionService.selectCommissionList(commission);
        return getDataTable(list);
    }

    /**
     * 导出佣金明细列表
     */
    @PreAuthorize("@ss.hasPermi('biz:commission:export')")
    @Log(title = "佣金明细", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, Commission commission)
    {
        TenantFilterHelper.apply((BaseEntity) commission,
                                  (e, v) -> ((com.ruoyi.biz.domain.Commission) e).setMerchantId(v),
                                  e -> ((com.ruoyi.biz.domain.Commission) e).getMerchantId());
        List<Commission> list = commissionService.selectCommissionList(commission);
        ExcelUtil<Commission> util = new ExcelUtil<Commission>(Commission.class);
        util.exportExcel(response, list, "佣金明细数据");
    }

    /**
     * 获取佣金明细详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:commission:query')")
    @GetMapping(value = "/{commissionId}")
    public AjaxResult getInfo(@PathVariable("commissionId") Long commissionId)
    {
        Commission commission = commissionService.selectCommissionByCommissionId(commissionId);
        if (commission != null)
        {
            TenantFilterHelper.assertDataScope(commission.getMerchantId());
        }
        return success(commission);
    }

    /**
     * 新增佣金明细
     */
    @PreAuthorize("@ss.hasPermi('biz:commission:add')")
    @Log(title = "佣金明细", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody Commission commission)
    {
        return toAjax(commissionService.insertCommission(commission));
    }

    /**
     * 修改佣金明细
     */
    @PreAuthorize("@ss.hasPermi('biz:commission:edit')")
    @Log(title = "佣金明细", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody Commission commission)
    {
        return toAjax(commissionService.updateCommission(commission));
    }

    /**
     * 删除佣金明细
     */
    @PreAuthorize("@ss.hasPermi('biz:commission:remove')")
    @Log(title = "佣金明细", businessType = BusinessType.DELETE)
	@DeleteMapping("/{commissionIds}")
    public AjaxResult remove(@PathVariable Long[] commissionIds)
    {
        return toAjax(commissionService.deleteCommissionByCommissionIds(commissionIds));
    }

    /**
     * 结算到期佣金：将超过冷静期的待结算佣金置为已结算，并把冻结金额转为可提现。
     */
    @PreAuthorize("@ss.hasPermi('biz:commission:edit')")
    @Log(title = "佣金结算", businessType = BusinessType.UPDATE)
    @PostMapping("/settle")
    public AjaxResult settle()
    {
        int settled = settlementService.settleMaturedCommissions();
        return AjaxResult.success("本次结算佣金 " + settled + " 笔", settled);
    }
}
