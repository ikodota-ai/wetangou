package com.ruoyi.web.api;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.biz.domain.Product;
import com.ruoyi.biz.domain.Category;
import com.ruoyi.biz.service.IProductService;
import com.ruoyi.biz.service.ICategoryService;

/**
 * 小程序-商品
 *
 * @author dytuangou
 */
@Anonymous
@RestController
@RequestMapping("/api/product")
public class ApiProductController
{
    @Autowired
    private IProductService productService;

    @Autowired
    private ICategoryService categoryService;

    /**
     * 商品列表（按门店、分类、类型筛选，仅上架）
     */
    @GetMapping("/list")
    public AjaxResult list(@RequestParam(required = false) Long storeId,
                           @RequestParam(required = false) Long categoryId,
                           @RequestParam(required = false) String productType)
    {
        Product query = new Product();
        query.setStatus("0");
        query.setStoreId(storeId);
        query.setCategoryId(categoryId);
        query.setProductType(productType);
        List<Product> list = productService.selectProductList(query);
        return AjaxResult.success(list);
    }

    /**
     * 商品详情
     */
    @GetMapping("/{productId}")
    public AjaxResult detail(@PathVariable Long productId)
    {
        return AjaxResult.success(productService.selectProductByProductId(productId));
    }

    /**
     * 分类列表
     */
    @GetMapping("/category/list")
    public AjaxResult categoryList(@RequestParam(required = false) Long storeId)
    {
        Category query = new Category();
        query.setStatus("0");
        query.setStoreId(storeId);
        List<Category> list = categoryService.selectCategoryList(query);
        return AjaxResult.success(list);
    }
}
