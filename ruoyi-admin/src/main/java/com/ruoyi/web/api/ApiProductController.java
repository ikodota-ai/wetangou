package com.ruoyi.web.api;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.biz.api.annotation.LoginRequired;
import com.ruoyi.biz.api.annotation.RequireRole;
import com.ruoyi.biz.api.role.BizRole;
import com.ruoyi.biz.api.util.MemberContextHolder;
import com.ruoyi.biz.domain.ProductExt;
import com.ruoyi.biz.service.IProductExtService;
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
    private IProductExtService extService;

    @Autowired
    private ICategoryService categoryService;

    @Autowired
    private IProductSubitemGroupService subitemGroupService;

    /**
     * 商品列表（按商户 / 门店 / 分类 / 类型筛选，仅上架）
     *   - merchantId 不传：按 storeId 查单店商品
     *   - merchantId 传了 + storeId 缺：返回该商户下所有自取/跨店商品
     *   - 两个都传：商户范围 + 门店范围
     */
    @GetMapping("/list")
    public AjaxResult list(@RequestParam(required = false) Long storeId,
                           @RequestParam(required = false) Long merchantId,
                           @RequestParam(required = false) Long categoryId,
                           @RequestParam(required = false) String productType)
    {
        Product query = new Product();
        query.setStatus("0");
        query.setStoreId(storeId);
        query.setMerchantId(merchantId);
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
        // E1 收口：统一 subitemGroups 放顶层。历史曾有 data 子对象冗余，
        // 现已确认无客户端依赖（admin 用 listGroups 端点，小程序 pages/goods/detail/index.js
        // 第 50 行读 d.subitemGroups 顶层），删 dataMap 冗余让 API 干净。
        AjaxResult result = AjaxResult.success(p);
        if (p != null)
        {
            String t = p.getTypeCode() == null ? "" : p.getTypeCode();
            if ("GROUPON".equals(t) || "COMBO".equals(t))
            {
                List<ProductSubitemGroup> groups = subitemGroupService.selectByProductId(productId);
                result.put("subitemGroups", groups);
            }
        }
        return result;
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
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER}, includeHigher = true)
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
        // typeCode 必填且必须在 11 种字典内（拒绝前端乱传）
        if (body.getTypeCode() == null || body.getTypeCode().trim().isEmpty()) {
            throw new ServiceException("请选择商品类型");
        }
        // 业务字段必填校验（按 typeCode 分组）
        String tc = body.getTypeCode().trim();
        if (body.getProductName() == null || body.getProductName().trim().isEmpty()) {
            throw new ServiceException("商品名称不能为空");
        }
        if (body.getPrice() == null) {
            throw new ServiceException("售价不能为空");
        }
        if (body.getValidityDays() == null || body.getValidityDays() <= 0) {
            throw new ServiceException("有效天数必须 > 0");
        }
        // 类型特定必填
        if (("TIMECARD".equals(tc) || "HUIXIANG_CARD".equals(tc)) && (body.getTotalTimes() == null || body.getTotalTimes() <= 0)) {
            throw new ServiceException(tc + " 必须填写总次数");
        }
        if ("PERIOD_CARD".equals(tc)) {
            if (body.getPeriodType() == null || body.getPeriodType().trim().isEmpty()) {
                throw new ServiceException("周期卡必须选择周期类型");
            }
            if (body.getPeriodCount() == null || body.getPeriodCount() <= 0) {
                throw new ServiceException("周期卡必须填写周期数");
            }
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
        // 同步保存扩展属性(类型差异+6tab详细字段)
        saveExtByTypeCode(body);
        AjaxResult r = AjaxResult.success();
        r.put("productId", body.getProductId());
        r.put("merchantId", body.getMerchantId());
        r.put("storeId", body.getStoreId());
        return r;
    }

    /**
     * 商家端：编辑商品（小程序端搭配保存后回填 totalValue / subitemPickRuleJson 等）
     */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER}, includeHigher = true)
    @PutMapping
    public AjaxResult edit(@RequestBody Product body)
    {
        com.ruoyi.biz.api.domain.LoginMember me = MemberContextHolder.get();
        if (me == null) {
            throw new ServiceException("未登录");
        }
        if (body == null || body.getProductId() == null) {
            throw new ServiceException("商品ID不能为空");
        }
        Product exist = productService.selectProductByProductId(body.getProductId());
        if (exist == null) {
            throw new ServiceException("商品不存在");
        }
        if (exist.getMerchantId() == null || !exist.getMerchantId().equals(me.getMerchantId())) {
            throw new ServiceException("无权编辑该商品");
        }
        body.setMerchantId(me.getMerchantId());
        int rows = productService.updateProduct(body);
        if (rows > 0) saveExtByTypeCode(body);
        return rows > 0 ? AjaxResult.success() : AjaxResult.error("保存失败");
    }

    /**
     * 按 typeCode 分流保存到 biz_product_ext
     */
    private void saveExtByTypeCode(Product body) {
        if (body == null || body.getProductId() == null) return;
        ProductExt ext = new ProductExt();
        ext.setProductId(body.getProductId());
        // 公共
        ext.setDailyUseLimit(0);
        ext.setRefundRuleType("ANYTIME");
        String tc = body.getTypeCode();
        if (tc == null) return;
        if ("VOUCHER".equals(tc)) {
            ext.setVoucherAutoName(1);
            ext.setVoucherMinConsume(body.getMinConsume());
        } else if ("COMBO".equals(tc)) {
            ext.setComboTotalValue(body.getTotalValue());
            ext.setComboSaleType("LIMIT");
            ext.setComboAutoExtendDays(30);
        } else if ("GROUPON".equals(tc)) {
            ext.setGrouponPickRule("ALL");
        }
        extService.save(ext);
    }

    /**
     * 商家端：商品上下架
     */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER}, includeHigher = true)
    @PutMapping("/status")
    public AjaxResult toggleStatus(@RequestBody Product body)
    {
        com.ruoyi.biz.api.domain.LoginMember me = MemberContextHolder.get();
        if (me == null) {
            throw new ServiceException("未登录");
        }
        if (body == null || body.getProductId() == null) {
            throw new ServiceException("商品ID不能为空");
        }
        if (body.getStatus() == null || (!body.getStatus().equals("0") && !body.getStatus().equals("1"))) {
            throw new ServiceException("status 必须是 0(上架) 或 1(下架)");
        }
        Product exist = productService.selectProductByProductId(body.getProductId());
        if (exist == null) {
            throw new ServiceException("商品不存在");
        }
        if (exist.getMerchantId() == null || !exist.getMerchantId().equals(me.getMerchantId())) {
            throw new ServiceException("无权操作该商品");
        }
        exist.setStatus(body.getStatus());
        int rows = productService.updateProduct(exist);
        return rows > 0 ? AjaxResult.success() : AjaxResult.error("操作失败");
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
