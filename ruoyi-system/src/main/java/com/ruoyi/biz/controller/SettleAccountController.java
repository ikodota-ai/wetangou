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
import com.ruoyi.biz.domain.SettleAccount;
import com.ruoyi.biz.service.ISettleAccountService;
import com.ruoyi.common.utils.poi.ExcelUtil;
import com.ruoyi.biz.tenant.TenantFilterHelper;
import com.ruoyi.common.core.page.TableDataInfo;

/**
 * 分账接收方Controller
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@RestController
@RequestMapping("/biz/account")
public class SettleAccountController extends BaseController
{
    @Autowired
    private ISettleAccountService settleAccountService;

    /**
     * 查询分账接收方列表
     */
    @PreAuthorize("@ss.hasPermi('biz:account:list')")
    @GetMapping("/list")
    public TableDataInfo list(SettleAccount settleAccount)
    {
        startPage();
        List<SettleAccount> list = settleAccountService.selectSettleAccountList(settleAccount);
        return getDataTable(list);
    }

    /**
     * 导出分账接收方列表
     */
    @PreAuthorize("@ss.hasPermi('biz:account:export')")
    @Log(title = "分账接收方", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, SettleAccount settleAccount)
    {
        List<SettleAccount> list = settleAccountService.selectSettleAccountList(settleAccount);
        ExcelUtil<SettleAccount> util = new ExcelUtil<SettleAccount>(SettleAccount.class);
        util.exportExcel(response, list, "分账接收方数据");
    }

    /**
     * 获取分账接收方详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:account:query')")
    @GetMapping(value = "/{accountId}")
    public AjaxResult getInfo(@PathVariable("accountId") Long accountId)
    {
        SettleAccount settleAccount = settleAccountService.selectSettleAccountByAccountId(accountId);
        if (settleAccount != null)
        {
            TenantFilterHelper.assertDataScope(settleAccount.getMerchantId());
        }
        return success(settleAccount);
    }

    /**
     * 新增分账接收方
     */
    @PreAuthorize("@ss.hasPermi('biz:account:add')")
    @Log(title = "分账接收方", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody SettleAccount settleAccount)
    {
        return toAjax(settleAccountService.insertSettleAccount(settleAccount));
    }

    /**
     * 修改分账接收方
     */
    @PreAuthorize("@ss.hasPermi('biz:account:edit')")
    @Log(title = "分账接收方", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody SettleAccount settleAccount)
    {
        return toAjax(settleAccountService.updateSettleAccount(settleAccount));
    }

    /**
     * 删除分账接收方
     */
    @PreAuthorize("@ss.hasPermi('biz:account:remove')")
    @Log(title = "分账接收方", businessType = BusinessType.DELETE)
	@DeleteMapping("/{accountIds}")
    public AjaxResult remove(@PathVariable Long[] accountIds)
    {
        return toAjax(settleAccountService.deleteSettleAccountByAccountIds(accountIds));
    }
}
