package com.ruoyi.web.api;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.biz.api.annotation.LoginRequired;
import com.ruoyi.biz.api.util.MemberContextHolder;
import com.ruoyi.biz.domain.Product;
import com.ruoyi.biz.domain.Category;
import com.ruoyi.biz.domain.ProductSubitemGroup;
import com.ruoyi.biz.service.IProductSubitemGroupService;
import com.ruoyi.biz.service.IProductService;
import com.ruoyi.biz.service.ICategoryService;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.image.ImageUrlUtils;

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

    @Autowired
    private IProductSubitemGroupService subitemGroupService;

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
        return AjaxResult.success(fillImageUrls(list));
    }

    /**
     * 商品详情
     */
    @GetMapping("/{productId}")
    public AjaxResult detail(@PathVariable Long productId)
    {
        Product p = productService.selectProductByProductId(productId);
        if (p != null)
        {
            p.setCover(ImageUrlUtils.toAbsolute(p.getCover()));
            p.setImages(ImageUrlUtils.toAbsolute(p.getImages()));
        }
        AjaxResult r = AjaxResult.success(p);
        if (p != null)
        {
            String t = p.getTypeCode() == null ? "" : p.getTypeCode();
            if ("GROUPON".equals(t) || "COMBO".equals(t))
            {
                List<ProductSubitemGroup> groups = subitemGroupService.selectByProductId(productId);
                // 兼容：顶层 + data 子对象都放（前端 miniprogram7/pages/goods/detail/index.js
                // 先查 d.subitemGroups，老逻辑；新版可查 d.data.subitemGroups）
                r.put("subitemGroups", groups);
                java.util.Map<String, Object> dataMap = new java.util.LinkedHashMap<>();
                dataMap.put("product", p);
                dataMap.put("subitemGroups", groups);
                r.put("data", dataMap);
            }
        }
        return r;
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

    /**
     * 商家端-创建商品（P1-2 商家端商品创建）
     * 需小程序员工登录；从 token 取 merchantId；前端只传 typeCode/价格/面值等业务字段
     * merchantId/storeId 由后端强制覆盖防越权
     */
    @LoginRequired
    @PostMapping("/add")
    public AjaxResult add(@RequestBody Product body)
    {
        com.ruoyi.biz.api.domain.LoginMember me = MemberContextHolder.get();
        if (me == null) {
            throw new ServiceException("未登录");
        }
        Long merchantId = me.getMerchantId();
        if (merchantId == null || merchantId <= 0) {
            throw new ServiceException("当前账号未绑定商户");
        }
        if (body == null) {
            throw new ServiceException("商品数据不能为空");
        }
        // 强制覆盖租户字段，前端不可越权
        body.setMerchantId(merchantId);
        // 商家端必须指定至少一个适用门店（storeIds 逗号分隔），由 syncPrimaryStore 选第一个作为主门店
        if (body.getStoreIds() == null || body.getStoreIds().trim().isEmpty()) {
            throw new ServiceException("请至少选择一个适用门店");
        }
        // 默认值兜底
        if (body.getProductType() == null) body.setProductType("0");
        if (body.getStatus() == null) body.setStatus("0");
        if (body.getDelFlag() == null) body.setDelFlag("0");
        if (body.getSales() == null) body.setSales(0L);
        if (body.getStock() == null) body.setStock(0L);
        if (body.getSort() == null) body.setSort(0);
        if (body.getCreateBy() == null) body.setCreateBy("merchant_" + me.getMemberId());

        int rows = productService.insertProduct(body);
        if (rows <= 0) {
            return AjaxResult.error("保存失败");
        }
        AjaxResult r = AjaxResult.success();
        r.put("productId", body.getProductId());
        r.put("merchantId", body.getMerchantId());
        r.put("storeId", body.getStoreId());
        return r;
    }

    /**
     * 把商品列表的图片字段（cover/images）转成绝对 URL，
     * 避免小程序 webview / &lt;image src&gt; 走原生加载时 404。
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
