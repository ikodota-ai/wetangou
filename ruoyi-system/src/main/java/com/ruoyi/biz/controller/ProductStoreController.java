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
import com.ruoyi.biz.domain.ProductStore;
import com.ruoyi.biz.service.IProductStoreService;
import com.ruoyi.common.utils.poi.ExcelUtil;
import com.ruoyi.common.core.page.TableDataInfo;

/**
 * 商品门店上架关系Controller
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@RestController
@RequestMapping("/biz/productStore")
public class ProductStoreController extends BaseController
{
    @Autowired
    private IProductStoreService productStoreService;

    /**
     * 查询商品门店上架关系列表
     */
    @PreAuthorize("@ss.hasPermi('biz:productStore:list')")
    @GetMapping("/list")
    public TableDataInfo list(ProductStore productStore)
    {
        startPage();
        List<ProductStore> list = productStoreService.selectProductStoreList(productStore);
        return getDataTable(list);
    }

    /**
     * 导出商品门店上架关系列表
     */
    @PreAuthorize("@ss.hasPermi('biz:productStore:export')")
    @Log(title = "商品门店上架关系", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, ProductStore productStore)
    {
        List<ProductStore> list = productStoreService.selectProductStoreList(productStore);
        ExcelUtil<ProductStore> util = new ExcelUtil<ProductStore>(ProductStore.class);
        util.exportExcel(response, list, "商品门店上架关系数据");
    }

    /**
     * 获取商品门店上架关系详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:productStore:query')")
    @GetMapping(value = "/{id}")
    public AjaxResult getInfo(@PathVariable("id") Long id)
    {
        return success(productStoreService.selectProductStoreById(id));
    }

    /**
     * 新增商品门店上架关系
     */
    @PreAuthorize("@ss.hasPermi('biz:productStore:add')")
    @Log(title = "商品门店上架关系", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody ProductStore productStore)
    {
        return toAjax(productStoreService.insertProductStore(productStore));
    }

    /**
     * 修改商品门店上架关系
     */
    @PreAuthorize("@ss.hasPermi('biz:productStore:edit')")
    @Log(title = "商品门店上架关系", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody ProductStore productStore)
    {
        return toAjax(productStoreService.updateProductStore(productStore));
    }

    /**
     * 删除商品门店上架关系
     */
    @PreAuthorize("@ss.hasPermi('biz:productStore:remove')")
    @Log(title = "商品门店上架关系", businessType = BusinessType.DELETE)
	@DeleteMapping("/{ids}")
    public AjaxResult remove(@PathVariable Long[] ids)
    {
        return toAjax(productStoreService.deleteProductStoreByIds(ids));
    }
}
