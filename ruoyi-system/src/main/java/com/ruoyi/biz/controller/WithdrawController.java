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
import com.ruoyi.biz.domain.Withdraw;
import com.ruoyi.biz.service.IWithdrawService;
import com.ruoyi.biz.api.service.SettlementService;
import com.ruoyi.common.utils.poi.ExcelUtil;
import com.ruoyi.common.core.page.TableDataInfo;

/**
 * 提现记录Controller
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@RestController
@RequestMapping("/biz/withdraw")
public class WithdrawController extends BaseController
{
    @Autowired
    private IWithdrawService withdrawService;

    @Autowired
    private SettlementService settlementService;

    /**
     * 查询提现记录列表
     */
    @PreAuthorize("@ss.hasPermi('biz:withdraw:list')")
    @GetMapping("/list")
    public TableDataInfo list(Withdraw withdraw)
    {
        startPage();
        List<Withdraw> list = withdrawService.selectWithdrawList(withdraw);
        return getDataTable(list);
    }

    /**
     * 导出提现记录列表
     */
    @PreAuthorize("@ss.hasPermi('biz:withdraw:export')")
    @Log(title = "提现记录", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, Withdraw withdraw)
    {
        List<Withdraw> list = withdrawService.selectWithdrawList(withdraw);
        ExcelUtil<Withdraw> util = new ExcelUtil<Withdraw>(Withdraw.class);
        util.exportExcel(response, list, "提现记录数据");
    }

    /**
     * 获取提现记录详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:withdraw:query')")
    @GetMapping(value = "/{withdrawId}")
    public AjaxResult getInfo(@PathVariable("withdrawId") Long withdrawId)
    {
        return success(withdrawService.selectWithdrawByWithdrawId(withdrawId));
    }

    /**
     * 新增提现记录
     */
    @PreAuthorize("@ss.hasPermi('biz:withdraw:add')")
    @Log(title = "提现记录", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody Withdraw withdraw)
    {
        return toAjax(withdrawService.insertWithdraw(withdraw));
    }

    /**
     * 修改提现记录
     */
    @PreAuthorize("@ss.hasPermi('biz:withdraw:edit')")
    @Log(title = "提现记录", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody Withdraw withdraw)
    {
        return toAjax(withdrawService.updateWithdraw(withdraw));
    }

    /**
     * 删除提现记录
     */
    @PreAuthorize("@ss.hasPermi('biz:withdraw:remove')")
    @Log(title = "提现记录", businessType = BusinessType.DELETE)
	@DeleteMapping("/{withdrawIds}")
    public AjaxResult remove(@PathVariable Long[] withdrawIds)
    {
        return toAjax(withdrawService.deleteWithdrawByWithdrawIds(withdrawIds));
    }

    /**
     * 提现审核：通过或驳回。
     * status=1 通过，累计已提现金额；status=2 驳回，退回可提现余额。
     */
    @PreAuthorize("@ss.hasPermi('biz:withdraw:edit')")
    @Log(title = "提现审核", businessType = BusinessType.UPDATE)
    @PostMapping("/audit")
    public AjaxResult audit(@RequestBody Withdraw withdraw)
    {
        if (withdraw.getWithdrawId() == null)
        {
            return error("提现记录ID不能为空");
        }
        if ("1".equals(withdraw.getStatus()))
        {
            settlementService.approveWithdraw(withdraw.getWithdrawId());
            return success("审核通过");
        }
        else if ("2".equals(withdraw.getStatus()))
        {
            settlementService.rejectWithdraw(withdraw.getWithdrawId(), withdraw.getFailReason());
            return success("已驳回");
        }
        return error("非法的审核状态，1=通过 2=驳回");
    }
}
