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
import com.ruoyi.biz.domain.SettleRecord;
import com.ruoyi.biz.service.ISettleRecordService;
import com.ruoyi.common.utils.poi.ExcelUtil;
import com.ruoyi.biz.tenant.TenantFilterHelper;
import com.ruoyi.common.core.page.TableDataInfo;

/**
 * 分账明细Controller
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@RestController
@RequestMapping("/biz/record")
public class SettleRecordController extends BaseController
{
    @Autowired
    private ISettleRecordService settleRecordService;

    /**
     * 查询分账明细列表
     */
    @PreAuthorize("@ss.hasPermi('biz:record:list')")
    @GetMapping("/list")
    public TableDataInfo list(SettleRecord settleRecord)
    {
        startPage();
        List<SettleRecord> list = settleRecordService.selectSettleRecordList(settleRecord);
        return getDataTable(list);
    }

    /**
     * 导出分账明细列表
     */
    @PreAuthorize("@ss.hasPermi('biz:record:export')")
    @Log(title = "分账明细", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, SettleRecord settleRecord)
    {
        List<SettleRecord> list = settleRecordService.selectSettleRecordList(settleRecord);
        ExcelUtil<SettleRecord> util = new ExcelUtil<SettleRecord>(SettleRecord.class);
        util.exportExcel(response, list, "分账明细数据");
    }

    /**
     * 获取分账明细详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:record:query')")
    @GetMapping(value = "/{recordId}")
    public AjaxResult getInfo(@PathVariable("recordId") Long recordId)
    {
        SettleRecord settleRecord = settleRecordService.selectSettleRecordByRecordId(recordId);
        if (settleRecord != null)
        {
            TenantFilterHelper.assertDataScope(settleRecord.getMerchantId());
        }
        return success(settleRecord);
    }

    /**
     * 新增分账明细
     */
    @PreAuthorize("@ss.hasPermi('biz:record:add')")
    @Log(title = "分账明细", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody SettleRecord settleRecord)
    {
        return toAjax(settleRecordService.insertSettleRecord(settleRecord));
    }

    /**
     * 修改分账明细
     */
    @PreAuthorize("@ss.hasPermi('biz:record:edit')")
    @Log(title = "分账明细", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody SettleRecord settleRecord)
    {
        return toAjax(settleRecordService.updateSettleRecord(settleRecord));
    }

    /**
     * 删除分账明细
     */
    @PreAuthorize("@ss.hasPermi('biz:record:remove')")
    @Log(title = "分账明细", businessType = BusinessType.DELETE)
	@DeleteMapping("/{recordIds}")
    public AjaxResult remove(@PathVariable Long[] recordIds)
    {
        return toAjax(settleRecordService.deleteSettleRecordByRecordIds(recordIds));
    }
}
