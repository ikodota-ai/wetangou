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
import com.ruoyi.biz.domain.MerchantFee;
import com.ruoyi.biz.service.IMerchantFeeService;

/**
 * 商户收费Controller
 *
 * @author dytuangou
 */
@RestController
@RequestMapping("/biz/merchantfee")
public class MerchantFeeController extends BaseController
{
    @Autowired
    private IMerchantFeeService merchantFeeService;

    /**
     * 查询商户收费列表
     */
    @PreAuthorize("@ss.hasPermi('biz:merchantfee:list')")
    @GetMapping("/list")
    public TableDataInfo list(MerchantFee merchantFee)
    {
        startPage();
        List<MerchantFee> list = merchantFeeService.selectMerchantFeeList(merchantFee);
        return getDataTable(list);
    }

    /**
     * 导出商户收费列表
     */
    @PreAuthorize("@ss.hasPermi('biz:merchantfee:list')")
    @Log(title = "商户收费", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, MerchantFee merchantFee)
    {
        List<MerchantFee> list = merchantFeeService.selectMerchantFeeList(merchantFee);
        ExcelUtil<MerchantFee> util = new ExcelUtil<MerchantFee>(MerchantFee.class);
        util.exportExcel(response, list, "商户收费数据");
    }

    /**
     * 获取商户收费详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:merchantfee:query')")
    @GetMapping(value = "/{feeId}")
    public AjaxResult getInfo(@PathVariable("feeId") Long feeId)
    {
        return success(merchantFeeService.selectMerchantFeeByFeeId(feeId));
    }

    /**
     * 新增商户收费
     */
    @PreAuthorize("@ss.hasPermi('biz:merchantfee:add')")
    @Log(title = "商户收费", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody MerchantFee merchantFee)
    {
        return toAjax(merchantFeeService.insertMerchantFee(merchantFee));
    }

    /**
     * 修改商户收费
     */
    @PreAuthorize("@ss.hasPermi('biz:merchantfee:edit')")
    @Log(title = "商户收费", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody MerchantFee merchantFee)
    {
        return toAjax(merchantFeeService.updateMerchantFee(merchantFee));
    }

    /**
     * 确认收款：同步商户服务到期时间
     */
    @PreAuthorize("@ss.hasPermi('biz:merchantfee:edit')")
    @Log(title = "商户收费", businessType = BusinessType.UPDATE)
    @PutMapping("/confirm/{feeId}")
    public AjaxResult confirm(@PathVariable("feeId") Long feeId)
    {
        return toAjax(merchantFeeService.confirmMerchantFee(feeId));
    }

    /**
     * 删除商户收费
     */
    @PreAuthorize("@ss.hasPermi('biz:merchantfee:remove')")
    @Log(title = "商户收费", businessType = BusinessType.DELETE)
    @DeleteMapping("/{feeIds}")
    public AjaxResult remove(@PathVariable Long[] feeIds)
    {
        return toAjax(merchantFeeService.deleteMerchantFeeByFeeIds(feeIds));
    }
}
