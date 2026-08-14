package com.ruoyi.biz.controller;

import java.util.Date;
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
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.biz.tenant.TenantFilterHelper;
import com.ruoyi.common.core.domain.BaseEntity;
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
        TenantFilterHelper.apply((BaseEntity) payBill,
                                  (e, v) -> ((com.ruoyi.biz.domain.PayBill) e).setMerchantId(v),
                                  e -> ((com.ruoyi.biz.domain.PayBill) e).getMerchantId());
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
        TenantFilterHelper.apply((BaseEntity) payBill,
                                  (e, v) -> ((com.ruoyi.biz.domain.PayBill) e).setMerchantId(v),
                                  e -> ((com.ruoyi.biz.domain.PayBill) e).getMerchantId());
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
        PayBill payBill = payBillService.selectPayBillByBillId(billId);
        if (payBill != null)
        {
            TenantFilterHelper.assertDataScope(payBill.getMerchantId());
        }
        return success(payBill);
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

    /**
     * 确认买单（后台 web 端：店长/收银员确认消费金额并开单）
     *
     * <p>把买单 status 0→1，写入 confirm_user=当前 sys_user / confirm_time=now。
     * 不强制 storeId 等于 sys_user.dept 关联门店：商户/平台账号都有 biz:bill:confirm 权限。</p>
     */
    @PreAuthorize("@ss.hasPermi('biz:bill:confirm')")
    @Log(title = "买单流水", businessType = BusinessType.UPDATE)
    @PostMapping("/confirm/{billId}")
    public AjaxResult confirm(@PathVariable Long billId)
    {
        PayBill bill = payBillService.selectPayBillByBillId(billId);
        if (bill == null || !"0".equals(bill.getStatus()))
        {
            throw new ServiceException("买单不存在或状态不允许确认");
        }
        bill.setStatus("1");
        try
        {
            bill.setConfirmUser(SecurityUtils.getUsername());
        }
        catch (Exception ignore)
        {
        }
        bill.setConfirmTime(new Date());
        return toAjax(payBillService.updatePayBill(bill));
    }
}
