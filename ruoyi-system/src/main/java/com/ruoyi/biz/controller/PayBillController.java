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
import com.ruoyi.biz.domain.PayBill;
import com.ruoyi.biz.service.IPayBillService;
import com.ruoyi.common.utils.poi.ExcelUtil;
import com.ruoyi.common.core.page.TableDataInfo;

/**
 * 买单流水Controller
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@RestController
@RequestMapping("/biz/bill")
public class PayBillController extends BaseController
{
    @Autowired
    private IPayBillService payBillService;

    /**
     * 查询买单流水列表
     */
    @PreAuthorize("@ss.hasPermi('biz:bill:list')")
    @GetMapping("/list")
    public TableDataInfo list(PayBill payBill)
    {
        startPage();
        List<PayBill> list = payBillService.selectPayBillList(payBill);
        return getDataTable(list);
    }

    /**
     * 导出买单流水列表
     */
    @PreAuthorize("@ss.hasPermi('biz:bill:export')")
    @Log(title = "买单流水", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, PayBill payBill)
    {
        List<PayBill> list = payBillService.selectPayBillList(payBill);
        ExcelUtil<PayBill> util = new ExcelUtil<PayBill>(PayBill.class);
        util.exportExcel(response, list, "买单流水数据");
    }

    /**
     * 获取买单流水详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:bill:query')")
    @GetMapping(value = "/{billId}")
    public AjaxResult getInfo(@PathVariable("billId") Long billId)
    {
        return success(payBillService.selectPayBillByBillId(billId));
    }

    /**
     * 新增买单流水
     */
    @PreAuthorize("@ss.hasPermi('biz:bill:add')")
    @Log(title = "买单流水", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody PayBill payBill)
    {
        return toAjax(payBillService.insertPayBill(payBill));
    }

    /**
     * 修改买单流水
     */
    @PreAuthorize("@ss.hasPermi('biz:bill:edit')")
    @Log(title = "买单流水", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody PayBill payBill)
    {
        return toAjax(payBillService.updatePayBill(payBill));
    }

    /**
     * 删除买单流水
     */
    @PreAuthorize("@ss.hasPermi('biz:bill:remove')")
    @Log(title = "买单流水", businessType = BusinessType.DELETE)
	@DeleteMapping("/{billIds}")
    public AjaxResult remove(@PathVariable Long[] billIds)
    {
        return toAjax(payBillService.deletePayBillByBillIds(billIds));
    }
}
