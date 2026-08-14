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
import com.ruoyi.biz.domain.Voucher;
import com.ruoyi.biz.service.IVoucherService;
import com.ruoyi.common.utils.poi.ExcelUtil;
import com.ruoyi.biz.tenant.TenantFilterHelper;
import com.ruoyi.common.core.domain.BaseEntity;
import com.ruoyi.common.core.page.TableDataInfo;

/**
 * 代金券模板Controller
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@RestController
@RequestMapping("/biz/voucher")
public class VoucherController extends BaseController
{
    @Autowired
    private IVoucherService voucherService;

    /**
     * 查询代金券模板列表
     */
    @PreAuthorize("@ss.hasPermi('biz:voucher:list')")
    @GetMapping("/list")
    public TableDataInfo list(Voucher voucher)
    {
        TenantFilterHelper.apply((BaseEntity) voucher,
                                  (e, v) -> ((com.ruoyi.biz.domain.Voucher) e).setMerchantId(v),
                                  e -> ((com.ruoyi.biz.domain.Voucher) e).getMerchantId());
        startPage();
        List<Voucher> list = voucherService.selectVoucherList(voucher);
        return getDataTable(list);
    }

    /**
     * 导出代金券模板列表
     */
    @PreAuthorize("@ss.hasPermi('biz:voucher:export')")
    @Log(title = "代金券模板", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, Voucher voucher)
    {
        TenantFilterHelper.apply((BaseEntity) voucher,
                                  (e, v) -> ((com.ruoyi.biz.domain.Voucher) e).setMerchantId(v),
                                  e -> ((com.ruoyi.biz.domain.Voucher) e).getMerchantId());
        List<Voucher> list = voucherService.selectVoucherList(voucher);
        ExcelUtil<Voucher> util = new ExcelUtil<Voucher>(Voucher.class);
        util.exportExcel(response, list, "代金券模板数据");
    }

    /**
     * 获取代金券模板详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:voucher:query')")
    @GetMapping(value = "/{voucherId}")
    public AjaxResult getInfo(@PathVariable("voucherId") Long voucherId)
    {
        return success(voucherService.selectVoucherByVoucherId(voucherId));
    }

    /**
     * 新增代金券模板
     */
    @PreAuthorize("@ss.hasPermi('biz:voucher:add')")
    @Log(title = "代金券模板", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody Voucher voucher)
    {
        return toAjax(voucherService.insertVoucher(voucher));
    }

    /**
     * 修改代金券模板
     */
    @PreAuthorize("@ss.hasPermi('biz:voucher:edit')")
    @Log(title = "代金券模板", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody Voucher voucher)
    {
        return toAjax(voucherService.updateVoucher(voucher));
    }

    /**
     * 删除代金券模板
     */
    @PreAuthorize("@ss.hasPermi('biz:voucher:remove')")
    @Log(title = "代金券模板", businessType = BusinessType.DELETE)
	@DeleteMapping("/{voucherIds}")
    public AjaxResult remove(@PathVariable Long[] voucherIds)
    {
        return toAjax(voucherService.deleteVoucherByVoucherIds(voucherIds));
    }
}
