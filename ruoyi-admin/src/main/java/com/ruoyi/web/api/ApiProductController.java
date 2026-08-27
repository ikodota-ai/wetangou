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
import com.ruoyi.biz.util.ProductValidator;
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
    /** 上架 */
    private static final String STATUS_ON = "0";
    /** 下架 / 草稿 */
    private static final String STATUS_OFF = "1";

    @Autowired
    private IProductService productService;
    @Autowired
    private IProductExtService extService;

    @Autowired
    private ICategoryService categoryService;

    @Autowired
    private IProductSubitemGroupService subitemGroupService;

    @Autowired
    private com.ruoyi.biz.service.ISaleChannelService channelService;

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
        // 默认值兜底。新建一律按草稿（下架）收 —— 与后台 admin 端 ProductController.add 一致。
        if (body.getProductType() == null) body.setProductType("0");
        if (body.getStatus() == null) body.setStatus(STATUS_OFF);
        if (body.getDelFlag() == null) body.setDelFlag("0");
        if (body.getSales() == null) body.setSales(0L);
        if (body.getStock() == null) body.setStock(0L);
        if (body.getSort() == null) body.setSort(0);
        if (body.getCreateBy() == null) body.setCreateBy("merchant_" + me.getMemberId());

        // 草稿只校验基础字段；上架态才跑该类型的完整必填。
        //
        // 原先这里无条件 ProductValidator.validate(body) 跑完整校验，跟商家端
        // 「先存草稿、之后补齐再上架」的流程是矛盾的：商家在手机上刚填完名称和价格
        // 点「保存为草稿」，直接被「GROUPON 需填库存 stock」顶回来，草稿一条都存不下。
        // 后台 admin 端一直是 validate(product, isDraft(product))，只有商家端这条链路
        // 卡着完整校验 —— 而商品维护的主场景恰恰在商家端。
        // 上架时的完整校验由 toggleStatus 负责，顾客可见性不会因此放松。
        boolean draft = !STATUS_ON.equals(body.getStatus());
        ProductValidator.validate(body, draft);
        if (!draft) {
            assertTypeSpecificRequired(tc, body);
        }

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
     *
     * <p>校验对象必须是「改完之后的那一行」而不是请求体本身：updateProduct 是逐字段
     * 判 null 的局部更新，请求体没带的字段在库里保持原值。原先这里一个校验都没有，
     * 商家在手机上把一个已上架商品的售价改成 0、库存改成 0 都能存下去 ——
     * 商品仍对顾客可见，但点进详情下单必然失败。admin 端一直是 merge + validate，
     * 只有商家端这条链路裸奔。</p>
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
        // 合并后仍是下架态 → 当草稿改；改完是上架态 → 必须补齐该类型全部必填项。
        // 单独再查一次而不复用 exist：mergeOntoOrigin 会把请求体的值写进传入对象，
        // 复用 exist 会让上面刚做完归属判定的那份数据被改脏。
        Product merged = ProductValidator.mergeOntoOrigin(
                productService.selectProductByProductId(body.getProductId()), body);
        boolean draft = ProductValidator.isDraft(merged);
        ProductValidator.validate(merged, draft);
        if (!draft) {
            assertTypeSpecificRequired(merged.getTypeCode(), merged);
        }
        int rows = productService.updateProduct(body);
        if (rows > 0) saveExtByTypeCode(body);
        return rows > 0 ? AjaxResult.success() : AjaxResult.error("保存失败");
    }

    /**
     * 按 typeCode 分流保存到 biz_product_ext。
     *
     * <p>这里以请求体带上来的 {@code body.getExt()} 为基础，再补类型相关的默认值 ——
     * 原先的写法是 {@code new ProductExt()} 从零构造，直接把商家端提交的 ext
     * 整个丢掉：小程序传了投放渠道 / 券码类型 / 消费时段也一个都存不进去。
     * 后台 admin 端走的是 ProductServiceImpl.saveExt（会用 body 的 ext），
     * 只有小程序这条链路漏了，属于「补了后台忘了小程序」的典型。</p>
     *
     * <p>补默认值都用「原值为 null 才补」，避免把商家显式选的值覆盖成默认。</p>
     */
    private void saveExtByTypeCode(Product body) {
        if (body == null || body.getProductId() == null) return;
        ProductExt ext = body.getExt() != null ? body.getExt() : new ProductExt();
        ext.setProductId(body.getProductId());
        // 公共默认值：只在商家端没传时兜底
        if (ext.getDailyUseLimit() == null) ext.setDailyUseLimit(0);
        if (ext.getRefundRuleType() == null) ext.setRefundRuleType("ANYTIME");
        if (ext.getCodeType() == null) ext.setCodeType("MERCHANT");
        if (ext.getStaffPromote() == null) ext.setStaffPromote(0);
        // 投放渠道：商家端没传就套平台字典的默认勾选，
        // 否则这批商品的 sale_channels 是空的，等顾客端真按渠道过滤时会整批消失
        if (ext.getSaleChannels() == null || ext.getSaleChannels().trim().isEmpty()) {
            ext.setSaleChannels(channelService.defaultChannelCodes());
        }
        String tc = body.getTypeCode();
        if (tc != null) {
            if ("VOUCHER".equals(tc)) {
                if (ext.getVoucherAutoName() == null) ext.setVoucherAutoName(1);
                if (ext.getVoucherMinConsume() == null) ext.setVoucherMinConsume(body.getMinConsume());
            } else if ("COMBO".equals(tc)) {
                if (ext.getComboTotalValue() == null) ext.setComboTotalValue(body.getTotalValue());
                if (ext.getComboSaleType() == null) ext.setComboSaleType("LIMIT");
                if (ext.getComboAutoExtendDays() == null) ext.setComboAutoExtendDays(30);
            } else if ("GROUPON".equals(tc)) {
                if (ext.getGrouponPickRule() == null) ext.setGrouponPickRule("ALL");
            }
        }
        extService.save(ext);
    }

    /**
     * 商家端：商品上下架
     *
     * <p>上架前必须跑完整校验：商家端建的商品现在默认落草稿（status=1），
     * 字段不一定填齐就会走到这里。原先这里只校验了 status 取值和商户归属，
     * 缺 stock / validityDays / maxPerOrder 也能直接上架 —— 商品对顾客可见了，
     * 但点进去下不了单。后台 admin 端的 changeStatus 一直是跑
     * ProductValidator + storeIds 校验的，只有小程序这条链路漏了。</p>
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
        if ("0".equals(body.getStatus())) {
            ProductValidator.validate(exist);
            assertTypeSpecificRequired(exist.getTypeCode(), exist);
            if (exist.getStoreIds() == null || exist.getStoreIds().trim().isEmpty()) {
                throw new ServiceException("上架前请先选择适用门店，否则顾客在任何门店都看不到该商品");
            }
        }
        exist.setStatus(body.getStatus());
        int rows = productService.updateProduct(exist);
        return rows > 0 ? AjaxResult.success() : AjaxResult.error("操作失败");
    }

    /**
     * ProductValidator 之外、商家端额外要求的类型必填。
     *
     * <p>抽成方法是为了让「新建时直接上架」和「草稿转上架」两条入口用同一套规则 ——
     * 原先这段只写在 add 里，从 status 端点上架完全不查，同一个商品走不同入口
     * 得到的可见性标准不一样。</p>
     */
    private void assertTypeSpecificRequired(String typeCode, Product p) {
        String tc = typeCode == null ? "" : typeCode.trim();
        if (p.getPrice() == null) {
            throw new ServiceException("售价不能为空");
        }
        if (("TIMECARD".equals(tc) || "HUIXIANG_CARD".equals(tc))
                && (p.getTotalTimes() == null || p.getTotalTimes() <= 0)) {
            throw new ServiceException(tc + " 必须填写总次数");
        }
        if ("PERIOD_CARD".equals(tc)) {
            if (p.getPeriodType() == null || p.getPeriodType().trim().isEmpty()) {
                throw new ServiceException("周期卡必须选择周期类型");
            }
            if (p.getPeriodCount() == null || p.getPeriodCount() <= 0) {
                throw new ServiceException("周期卡必须填写周期数");
            }
        }
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
