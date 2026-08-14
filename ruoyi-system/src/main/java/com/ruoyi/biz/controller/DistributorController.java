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
import com.ruoyi.biz.domain.Distributor;
import com.ruoyi.biz.service.IDistributorService;
import com.ruoyi.common.utils.poi.ExcelUtil;
import com.ruoyi.biz.tenant.TenantFilterHelper;
import com.ruoyi.common.core.domain.BaseEntity;
import com.ruoyi.common.core.page.TableDataInfo;

/**
 * 推客Controller
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@RestController
@RequestMapping("/biz/distributor")
public class DistributorController extends BaseController
{
    @Autowired
    private IDistributorService distributorService;

    /**
     * 查询推客列表
     */
    @PreAuthorize("@ss.hasPermi('biz:distributor:list')")
    @GetMapping("/list")
    public TableDataInfo list(Distributor distributor)
    {
        TenantFilterHelper.apply((BaseEntity) distributor,
                                  (e, v) -> ((com.ruoyi.biz.domain.Distributor) e).setMerchantId(v),
                                  e -> ((com.ruoyi.biz.domain.Distributor) e).getMerchantId());
        startPage();
        List<Distributor> list = distributorService.selectDistributorList(distributor);
        return getDataTable(list);
    }

    /**
     * 导出推客列表
     */
    @PreAuthorize("@ss.hasPermi('biz:distributor:export')")
    @Log(title = "推客", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, Distributor distributor)
    {
        TenantFilterHelper.apply((BaseEntity) distributor,
                                  (e, v) -> ((com.ruoyi.biz.domain.Distributor) e).setMerchantId(v),
                                  e -> ((com.ruoyi.biz.domain.Distributor) e).getMerchantId());
        List<Distributor> list = distributorService.selectDistributorList(distributor);
        ExcelUtil<Distributor> util = new ExcelUtil<Distributor>(Distributor.class);
        util.exportExcel(response, list, "推客数据");
    }

    /**
     * 获取推客详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:distributor:query')")
    @GetMapping(value = "/{distributorId}")
    public AjaxResult getInfo(@PathVariable("distributorId") Long distributorId)
    {
        return success(distributorService.selectDistributorByDistributorId(distributorId));
    }

    /**
     * 新增推客
     */
    @PreAuthorize("@ss.hasPermi('biz:distributor:add')")
    @Log(title = "推客", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody Distributor distributor)
    {
        return toAjax(distributorService.insertDistributor(distributor));
    }

    /**
     * 修改推客
     */
    @PreAuthorize("@ss.hasPermi('biz:distributor:edit')")
    @Log(title = "推客", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody Distributor distributor)
    {
        return toAjax(distributorService.updateDistributor(distributor));
    }

    /**
     * 删除推客
     */
    @PreAuthorize("@ss.hasPermi('biz:distributor:remove')")
    @Log(title = "推客", businessType = BusinessType.DELETE)
	@DeleteMapping("/{distributorIds}")
    public AjaxResult remove(@PathVariable Long[] distributorIds)
    {
        return toAjax(distributorService.deleteDistributorByDistributorIds(distributorIds));
    }
}
