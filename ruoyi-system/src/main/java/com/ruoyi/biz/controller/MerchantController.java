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
import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.biz.service.IMerchantService;

/**
 * 商户Controller
 *
 * @author dytuangou
 */
@RestController
@RequestMapping("/biz/merchant")
public class MerchantController extends BaseController
{
    @Autowired
    private IMerchantService merchantService;

    /**
     * 查询商户列表
     */
    @PreAuthorize("@ss.hasPermi('biz:merchant:list')")
    @GetMapping("/list")
    public TableDataInfo list(Merchant merchant)
    {
        startPage();
        List<Merchant> list = merchantService.selectMerchantList(merchant);
        return getDataTable(list);
    }

    /**
     * 导出商户列表
     */
    @PreAuthorize("@ss.hasPermi('biz:merchant:export')")
    @Log(title = "商户", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, Merchant merchant)
    {
        List<Merchant> list = merchantService.selectMerchantList(merchant);
        ExcelUtil<Merchant> util = new ExcelUtil<Merchant>(Merchant.class);
        util.exportExcel(response, list, "商户数据");
    }

    /**
     * 获取商户详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:merchant:query')")
    @GetMapping(value = "/{merchantId}")
    public AjaxResult getInfo(@PathVariable("merchantId") Long merchantId)
    {
        merchantService.checkMerchantDataScope(merchantId);
        return success(merchantService.selectMerchantByMerchantId(merchantId));
    }

    /**
     * 新增商户
     */
    @PreAuthorize("@ss.hasPermi('biz:merchant:add')")
    @Log(title = "商户", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody Merchant merchant)
    {
        int rows = merchantService.insertMerchant(merchant);
        if (rows <= 0)
        {
            return error("新增商户失败");
        }
        // 自动开通的老板账号/初始密码只在本次响应里回带（不落库），由平台交付给老板；
        // 遗失后走后台「重置老板密码」。
        AjaxResult r = AjaxResult.success("新增成功");
        r.put("merchantId", merchant.getMerchantId());
        r.put("ownerUserName", merchant.getOwnerUserName());
        r.put("ownerInitPassword", merchant.getOwnerInitPassword());
        return r;
    }

    /**
     * 重置（必要时补建）商户老板账号密码。
     *
     * <p>老板初始密码只在新建商户时返回一次，遗失后无处可查；且本次之前建的商户
     * 根本没有老板账号。这个端点两件事一起干：有账号就重置密码，没账号就补建。</p>
     */
    @PreAuthorize("@ss.hasPermi('biz:merchant:edit')")
    @Log(title = "商户", businessType = BusinessType.UPDATE)
    @PutMapping("/owner/resetPwd/{merchantId}")
    public AjaxResult resetOwnerPwd(@PathVariable("merchantId") Long merchantId)
    {
        Merchant owner = merchantService.resetOwnerAccount(merchantId);
        AjaxResult r = AjaxResult.success("已重置老板密码");
        r.put("ownerUserName", owner.getOwnerUserName());
        r.put("ownerInitPassword", owner.getOwnerInitPassword());
        return r;
    }

    /**
     * 修改商户
     */
    @PreAuthorize("@ss.hasPermi('biz:merchant:edit')")
    @Log(title = "商户", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody Merchant merchant)
    {
        return toAjax(merchantService.updateMerchant(merchant));
    }

    /**
     * 删除商户
     */
    @PreAuthorize("@ss.hasPermi('biz:merchant:remove')")
    @Log(title = "商户", businessType = BusinessType.DELETE)
    @DeleteMapping("/{merchantIds}")
    public AjaxResult remove(@PathVariable Long[] merchantIds)
    {
        return toAjax(merchantService.deleteMerchantByMerchantIds(merchantIds));
    }
}
