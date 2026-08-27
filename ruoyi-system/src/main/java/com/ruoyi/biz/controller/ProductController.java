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
import com.ruoyi.common.utils.TenantContextHolder;
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
        Long tokenMerchantId = TenantContextHolder.getMerchantId();
        if (tokenMerchantId != null)
        {
            // 商户账号只能给自己建商品，忽略前端传值防越权
            product.setMerchantId(tokenMerchantId);
        }
        if (product.getMerchantId() == null || product.getMerchantId() == 0L)
        {
            return AjaxResult.error("请选择所属商家：商品必须归属某个商户，否则小程序按商户查商品拿不到它");
        }
        TenantFilterHelper.assertDataScope(product.getMerchantId());
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
        Product origin = productService.selectProductByProductId(product.getProductId());
        if (origin == null)
        {
            return AjaxResult.error("商品不存在");
        }
        // 1) 有没有权限动这个商品
        TenantFilterHelper.assertDataScope(origin.getMerchantId());

        Long tokenMerchantId = TenantContextHolder.getMerchantId();
        if (tokenMerchantId != null)
        {
            // 商户账号不允许把商品转给别家
            product.setMerchantId(tokenMerchantId);
        }
        else if (product.getMerchantId() == null || product.getMerchantId() == 0L)
        {
            // 平台/代理商漏传时保持原归属，避免分段式编辑的后续 tab 把 merchant_id 清掉
            product.setMerchantId(origin.getMerchantId());
        }
        // 2) 改完之后的归属是否仍在权限范围内
        TenantFilterHelper.assertDataScope(product.getMerchantId());
        // 3) 校验对象必须是「改完之后的那一行」，而不是请求体本身。
        //
        // updateProduct 的 SQL 是逐字段判 null 的局部更新，所以请求体里没带的
        // 字段在库里会保持原值。可校验以前直接拿请求体来判，于是只改一两个字段的
        // 局部 PUT（比如商品搭配抽屉只提交 productId + 搭配明细）就会因为
        // typeCode/productName 为 null 被判成「商品类型 typeCode 不能为空」而存不进去，
        // 尽管这两个字段在库里明明是好的。
        //
        // 反方向还有个更隐蔽的问题：status 没带时 isDraft 会把请求判成草稿，
        // 于是一个已上架商品可以靠「不带 status 的局部 PUT」把售价改成 0 而绕过上架校验，
        // 顾客侧就会看到点进去下不了单的商品。用合并后的视图判，这两个方向一起解决。
        Product merged = mergeOntoOrigin(origin, product);
        // 合并后仍是下架态 → 继续当草稿改；一旦要上架，就必须补齐该类型的所有必填项。
        ProductValidator.validate(merged, isDraft(merged));
        return toAjax(productService.updateProduct(product));
    }

    /**
     * 上架 / 下架。
     *
     * <p>为什么需要这个独立端点：商品新建一律落草稿（下架态），因为分段式创建
     * 第 1 步只填品类/类型/名称就要落库拿 productId，此时必填项还没填完，
     * 不可能直接上架。所以「上架」必然是个独立的后续动作。</p>
     *
     * <p>上架时跑完整校验（{@code draft=false}）：草稿允许字段不全，但一旦要
     * 对顾客可见，该类型的必填项必须齐 —— 否则小程序会拿到没有库存/没有有效期
     * 的商品，下单流程直接崩。下架反过来不校验：已经有问题的商品必须允许随时
     * 撤下来，如果下架也要求字段齐全，就会出现「烂数据商品下不掉」的死锁。</p>
     *
     * @param product 只需 productId + status（0 上架 / 1 下架）
     */
    @PreAuthorize("@ss.hasPermi('biz:product:edit')")
    @Log(title = "商品", businessType = BusinessType.UPDATE)
    @PutMapping("/status")
    public AjaxResult changeStatus(@RequestBody Product product)
    {
        if (product == null || product.getProductId() == null)
        {
            return AjaxResult.error("商品ID不能为空");
        }
        String status = product.getStatus();
        if (!STATUS_ON.equals(status) && !STATUS_OFF.equals(status))
        {
            return AjaxResult.error("status 必须是 0（上架）或 1（下架）");
        }
        Product origin = productService.selectProductByProductId(product.getProductId());
        if (origin == null)
        {
            return AjaxResult.error("商品不存在");
        }
        TenantFilterHelper.assertDataScope(origin.getMerchantId());

        origin.setStatus(status);
        if (STATUS_ON.equals(status))
        {
            // 先查归属：merchant_id 为 0/空的是历史遗留的孤儿商品。
            // 不先拦的话会一路走到门店归属校验，然后报「门店 X 不属于该商家」——
            // 而用户看到的门店明明就是自己的，根本无从判断真正缺的是商品归属，
            // 所以这里直接把话说清楚。顺带也堵住了「孤儿商品被上架后
            // 小程序按商户查不到、顾客永远看不见」的问题。
            if (origin.getMerchantId() == null || origin.getMerchantId() == 0L)
            {
                return AjaxResult.error("该商品未归属任何商家，无法上架：请先在编辑页选择所属商家后再上架");
            }
            // 上架要对顾客可见，必填项必须齐；报错信息由 ProductValidator 指明缺哪个字段
            ProductValidator.validate(origin, false);
            if (com.ruoyi.common.utils.StringUtils.isEmpty(origin.getStoreIds()))
            {
                return AjaxResult.error("上架前请先选择适用门店，否则顾客在任何门店都看不到该商品");
            }
        }
        return toAjax(productService.updateProduct(origin));
    }

    /**
     * 局部请求体合到库里原值上，得到「改完之后长什么样」。
     *
     * <p>实现下沉到 {@link ProductValidator#mergeOntoOrigin}，因为小程序商家端的
     * edit 端点也要用同一套语义 —— 原先这里是 private static，商家端复用不到，
     * 结果那条链路完全不校验。</p>
     */
    private static Product mergeOntoOrigin(Product origin, Product incoming)
    {
        return ProductValidator.mergeOntoOrigin(origin, incoming);
    }

    /** 下架态（含未指定）视为草稿：小程序端只查 status='0'，草稿不会暴露给用户 */
    private static boolean isDraft(Product product)
    {
        return ProductValidator.isDraft(product);
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
