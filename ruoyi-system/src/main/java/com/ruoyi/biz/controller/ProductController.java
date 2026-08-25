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
import com.ruoyi.biz.domain.Product;
import com.ruoyi.biz.service.IProductService;
import com.ruoyi.biz.util.ProductValidator;
import com.ruoyi.common.utils.image.ImageUrlUtils;
import com.ruoyi.common.utils.poi.ExcelUtil;
import com.ruoyi.biz.tenant.TenantFilterHelper;
import com.ruoyi.common.core.domain.BaseEntity;
import com.ruoyi.common.core.page.TableDataInfo;

/**
 * 商品Controller
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@RestController
@RequestMapping("/biz/product")
public class ProductController extends BaseController
{
    /** 上架 */
    private static final String STATUS_ON = "0";

    /** 下架（草稿态） */
    private static final String STATUS_OFF = "1";

    @Autowired
    private IProductService productService;

    /**
     * 查询商品列表
     */
    @PreAuthorize("@ss.hasPermi('biz:product:list')")
    @GetMapping("/list")
    public TableDataInfo list(Product product)
    {
        TenantFilterHelper.apply((BaseEntity) product,
                                  (e, v) -> ((com.ruoyi.biz.domain.Product) e).setMerchantId(v),
                                  e -> ((com.ruoyi.biz.domain.Product) e).getMerchantId());
        startPage();
        List<Product> list = productService.selectProductList(product);
        return getDataTable(fillImageUrls(list));
    }

    /**
     * 导出商品列表
     */
    @PreAuthorize("@ss.hasPermi('biz:product:export')")
    @Log(title = "商品", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, Product product)
    {
        TenantFilterHelper.apply((BaseEntity) product,
                                  (e, v) -> ((com.ruoyi.biz.domain.Product) e).setMerchantId(v),
                                  e -> ((com.ruoyi.biz.domain.Product) e).getMerchantId());
        List<Product> list = productService.selectProductList(product);
        ExcelUtil<Product> util = new ExcelUtil<Product>(Product.class);
        util.exportExcel(response, list, "商品数据");
    }

    /**
     * 获取商品详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:product:query')")
    @GetMapping(value = "/{productId}")
    public AjaxResult getInfo(@PathVariable("productId") Long productId)
    {
        Product p = productService.selectProductByProductId(productId);
        if (p != null)
        {
            TenantFilterHelper.assertDataScope(p.getMerchantId());
            p.setCover(ImageUrlUtils.toAbsolute(p.getCover()));
            p.setImages(ImageUrlUtils.toAbsolute(p.getImages()));
        }
        return success(p);
    }

    /**
     * 新增商品
     */
    @PreAuthorize("@ss.hasPermi('biz:product:add')")
    @Log(title = "商品", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody Product product)
    {
        // 新建一律按草稿收：分段式创建页第 1 步只有品类/类型/名称，
        // 库存、有效期、单次限购都在拿到 productId 之后的 tab 里填。
        // 强行完整校验会导致「建不出第一个商品」的死锁。
        if (product.getStatus() == null || product.getStatus().isEmpty())
        {
            product.setStatus(STATUS_OFF);
        }
        ProductValidator.validate(product, isDraft(product));
        int rows = productService.insertProduct(product);
        if (rows <= 0)
        {
            return error("新增商品失败");
        }
        // 回传自增主键：前端「高级编辑」第 1 步保存后需要 productId 才能继续填写后续 tab
        return success(product.getProductId());
    }

    /**
     * 修改商品
     */
    @PreAuthorize("@ss.hasPermi('biz:product:edit')")
    @Log(title = "商品", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody Product product)
    {
        // 仍是下架态 → 继续当草稿改；一旦要上架，就必须补齐该类型的所有必填项。
        ProductValidator.validate(product, isDraft(product));
        return toAjax(productService.updateProduct(product));
    }

    /** 下架态（含未指定）视为草稿：小程序端只查 status='0'，草稿不会暴露给用户 */
    private static boolean isDraft(Product product)
    {
        return !STATUS_ON.equals(product.getStatus());
    }

    /**
     * 删除商品
     */
    @PreAuthorize("@ss.hasPermi('biz:product:remove')")
    @Log(title = "商品", businessType = BusinessType.DELETE)
	@DeleteMapping("/{productIds}")
    public AjaxResult remove(@PathVariable Long[] productIds)
    {
        return toAjax(productService.deleteProductByProductIds(productIds));
    }

    /**
     * 把列表里所有图片字段（cover/images）转成绝对 URL，
     * 避免前端 &lt;el-image&gt; 走原生 src 时因相对路径访问到错误端口。
     */
    private List<Product> fillImageUrls(List<Product> list)
    {
        if (list == null)
        {
            return null;
        }
        for (Product p : list)
        {
            p.setCover(ImageUrlUtils.toAbsolute(p.getCover()));
            p.setImages(ImageUrlUtils.toAbsolute(p.getImages()));
        }
        return list;
    }
}
