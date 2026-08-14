package com.ruoyi.web.controller.biz;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.biz.domain.ProductType;
import com.ruoyi.biz.service.IProductTypeService;

/**
 * 商品类型字典 biz_product_type
 *
 * <p>平台级字典，类型是固定的（GROUPON/VOUCHER/...），商家不可增删。
 * 仅允许修改 typeName/typeDesc/icon/fieldConfig 字典元数据。</p>
 */
@RestController
@RequestMapping("/biz/productType")
public class BizProductTypeController extends BaseController
{
    @Autowired
    private IProductTypeService typeService;

    @PreAuthorize("@ss.hasPermi('biz:productType:list')")
    @GetMapping("/list")
    public TableDataInfo list(ProductType query)
    {
        startPage();
        return getDataTable(typeService.selectList(query));
    }

    /** 详情：按 typeCode */
    @PreAuthorize("@ss.hasPermi('biz:productType:query')")
    @GetMapping("/{typeCode}")
    public AjaxResult getInfo(@PathVariable String typeCode)
    {
        return success(typeService.selectByCode(typeCode));
    }

    /** 小程序拉取可选类型（按 PRD 8.2 "商品类型" tab 用）
     * 字典类公开数据，加 @Anonymous 允许未登录访问（H5/小程序均可匿名拿） */
    @Anonymous
    @GetMapping("/appCreatable")
    public AjaxResult appCreatable()
    {
        return success(typeService.selectAppCreatable());
    }

    @PreAuthorize("@ss.hasPermi('biz:productType:add')")
    @Log(title = "商品类型", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody ProductType entity)
    {
        return toAjax(typeService.insert(entity));
    }

    @PreAuthorize("@ss.hasPermi('biz:productType:edit')")
    @Log(title = "商品类型", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody ProductType entity)
    {
        return toAjax(typeService.update(entity));
    }

    @PreAuthorize("@ss.hasPermi('biz:productType:remove')")
    @Log(title = "商品类型", businessType = BusinessType.DELETE)
    @DeleteMapping("/{typeCode}")
    public AjaxResult remove(@PathVariable String typeCode)
    {
        return toAjax(typeService.deleteByCode(typeCode));
    }
}
