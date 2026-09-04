package com.ruoyi.web.api;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.DeleteMapping;
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
import com.ruoyi.common.utils.StringUtils;
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
    private com.ruoyi.biz.service.IProductSubitemService subitemService;

    @Autowired
    private com.ruoyi.biz.service.ISaleChannelService channelService;

    @Autowired
    private com.ruoyi.biz.api.service.WxMaService wxMaService;

    @Autowired
    private com.ruoyi.framework.config.ServerConfig serverConfig;

    /**
     * 商品列表（按商户 / 门店 / 分类 / 类型筛选，仅上架）
     *   - merchantId 不传：按 storeId 查单店商品
     *   - merchantId 传了 + storeId 缺：返回该商户下所有自取/跨店商品
     *   - 两个都传：商户范围 + 门店范围
     *
     * <p>typeCode 是 v2 抖音来客商品类型（GROUPON/VOUCHER/BOOKING/...）。
     * 原先这个端点只收老字段 productType（'0'/'1'），顾客端没法按 v2 类型筛，
     * 于是首页「预约服务」tab 只能写死一张图 —— 这里补上。
     * productType 保留是为了兼容既有调用方。</p>
     */
    @GetMapping("/list")
    public AjaxResult list(@RequestParam(required = false) Long storeId,
                           @RequestParam(required = false) Long merchantId,
                           @RequestParam(required = false) Long categoryId,
                           @RequestParam(required = false) String productType,
                           @RequestParam(required = false) String typeCode)
    {
        Product query = new Product();
        query.setStatus("0");
        query.setStoreId(storeId);
        query.setMerchantId(merchantId);
        query.setCategoryId(categoryId);
        query.setProductType(productType);
        query.setTypeCode(typeCode);
        List<Product> list = productService.selectProductList(query);
        return AjaxResult.success(fillImageUrls(list));
    }

    /**
     * 商家端-商品列表（分页 + 按状态筛选）。
     *
     * <p>为什么不复用 {@code /list}：那个端点是给顾客端用的，写死了
     * {@code status="0"} 只返上架商品、而且不分页一次全返。商家端拿它做列表有两个
     * 死结：一是看不到自己的草稿（建品后落草稿，列表里一条都没有，商家以为没保存成功），
     * 二是没有 total，「已上架 / 未上架」的 tab 角标只能拿当前页自己数 ——
     * 站在「已上架」tab 时请求带 status=0 返回的全是上架品，「未上架」角标恒为 0，
     * 商品超过一页时上架角标也是错的。
     *
     * <p>顾客端那个端点保持原样不动（改成分页会破坏 app.js 里 loadGoods /
     * loadAllPickupGoods 的 {@code res.data} 数组读法）。</p>
     *
     * <p>merchantId 一律取 token 里的，忽略前端传值：否则商家改个 query 参数
     * 就能翻别家商户的商品列表。</p>
     */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER}, includeHigher = true)
    @GetMapping("/merchant/list")
    public AjaxResult merchantList(@RequestParam(required = false) Long storeId,
                                   @RequestParam(required = false) Long categoryId,
                                   @RequestParam(required = false) String typeCode,
                                   @RequestParam(required = false) String status,
                                   @RequestParam(required = false) String keyword,
                                   @RequestParam(defaultValue = "1") int pageNum,
                                   @RequestParam(defaultValue = "20") int pageSize)
    {
        com.ruoyi.biz.api.domain.LoginMember me = MemberContextHolder.get();
        if (me == null) {
            throw new ServiceException("未登录");
        }
        Long merchantId = me.getMerchantId();
        if (merchantId == null || merchantId <= 0) {
            throw new ServiceException("当前账号未绑定商户");
        }
        Product query = new Product();
        query.setMerchantId(merchantId);
        query.setStoreId(storeId);
        query.setCategoryId(categoryId);
        query.setTypeCode(typeCode);
        // status 不传 = 全部（草稿 + 上架），这是「全部」tab 要的
        if (status != null && !status.trim().isEmpty()) {
            query.setStatus(status.trim());
        }
        if (keyword != null && !keyword.trim().isEmpty()) {
            query.setProductName(keyword.trim());
        }
        // 手写分页而不是 startPage()：PageHelper 只对紧随其后的第一条 SQL 生效，
        // 而 selectProductList 的 resultMap 带 ext 的 association（一次查询里含 join），
        // 用 PageHelper 的 count 改写在这种嵌套映射上容易把 total 数错。
        // 商家端单个商户的商品量级（百级）全量查回来再切片，代价可接受。
        List<Product> all = productService.selectProductList(query);
        int total = all == null ? 0 : all.size();
        int size = pageSize <= 0 ? 20 : Math.min(pageSize, 100);
        int from = Math.max(0, (Math.max(pageNum, 1) - 1) * size);
        List<Product> page = from >= total
                ? java.util.Collections.emptyList()
                : all.subList(from, Math.min(from + size, total));
        AjaxResult r = AjaxResult.success();
        r.put("rows", fillImageUrls(new java.util.ArrayList<>(page)));
        r.put("total", total);
        return r;
    }

    /**
     * 商品详情。
     *
     * <p>顾客端（商品详情页 / 下单页 / 分享页）和商家端编辑页回填都走这一个端点，
     * 但两边可见范围不同，必须在这里分开判：
     * <ul>
     *   <li>顾客态：只能看本 appid 商户的<b>上架</b>商品。原先这个端点既不判商户
     *       也不判状态 —— 商品 id 是自增连号，随手把 URL 里的 id 加一就能翻出
     *       别家商户的商品，连人家还没上架的草稿（定价、库存、门店）都一起吐出来。
     *       /list 一直是带 status=0 和商户条件的，只有详情这条漏了。</li>
     *   <li>商家态（带员工 token）：能看自己商户的草稿 —— 编辑页回填就靠它，
     *       否则商家在小程序里建完草稿点「编辑」会直接被判成无权访问。
     *       但仍不能跨商户。</li>
     * </ul>
     *
     * <p>两种情况都返回同一句「商品不存在或已下架」而不点明「无权访问」：
     * 否则返回文案本身就成了探测别家商品 id 是否存在的信道。</p>
     */
    @GetMapping("/{productId}")
    public AjaxResult detail(@PathVariable Long productId)
    {
        Product p = productService.selectProductByProductId(productId);
        if (p == null || !isVisibleToCaller(p))
        {
            return AjaxResult.error("商品不存在或已下架");
        }
        p.setCover(ImageUrlUtils.toAbsolute(p.getCover()));
        p.setImages(ImageUrlUtils.toAbsolute(p.getImages()));
        // E1 收口：统一 subitemGroups 放顶层。历史曾有 data 子对象冗余，
        // 现已确认无客户端依赖（admin 用 listGroups 端点，小程序 pages/goods/detail/index.js
        // 第 50 行读 d.subitemGroups 顶层），删 dataMap 冗余让 API 干净。
        AjaxResult result = AjaxResult.success(p);
        String t = p.getTypeCode() == null ? "" : p.getTypeCode();
        if ("GROUPON".equals(t) || "COMBO".equals(t))
        {
            List<ProductSubitemGroup> groups = subitemGroupService.selectByProductId(productId);
            result.put("subitemGroups", groups);
        }
        return result;
    }

    /**
     * 商品小程序码（用于分享面板 / 海报）
     *
     * <p>为什么要新开一个端点：分享面板和海报页原先都拿不到真的小程序码 ——
     * 面板里画的是一个 CSS 渐变拼出来的「假二维码」（.qr-circle 用
     * radial-gradient + conic-gradient 模拟纹理，扫不出任何东西），
     * 海报页则调 {@code /api/distributor/qrcode}，那个端点要求调用者
     * 是推客（{@code currentDistributor() == null} 直接抛「您还不是推客」），
     * 普通会员分享商品必然失败。分享商品跟推客身份无关，应该人人可用。</p>
     *
     * <p>scene 里带 p:productId，扫码进来直落商品详情页。不带推客信息，
     * 推客返佣的归因码仍走 /api/distributor/qrcode 那条路。</p>
     *
     * <p>文件层缓存（同 E10 模式）：wxacodeUnlimited 有日调用上限，
     * 一个商品的码是固定内容，没必要每次打开分享面板都去换一张。</p>
     *
     * <p>返回 dataUrl 而不是文件 URL：小程序 canvas 画图要先 downloadFile，
     * 而 downloadFile 受 request 合法域名限制，本地/未备案域名会失败；
     * dataUrl 可以直接 &lt;image src&gt; 渲染，也能被 canvas 的 createImage 吃下。
     * 同时也返 url，方便调试时直接在浏览器打开确认。</p>
     */
    @GetMapping("/{productId}/qrcode")
    public AjaxResult productQrcode(@PathVariable Long productId) throws Exception
    {
        Product p = productService.selectProductByProductId(productId);
        if (p == null || !isVisibleToCaller(p))
        {
            return AjaxResult.error("商品不存在或已下架");
        }
        Long merchantId = p.getMerchantId() == null ? 1L : p.getMerchantId();
        // scene 上限 32 字符，只放商品 id
        String scene = "p:" + productId;

        String dir = com.ruoyi.common.config.RuoYiConfig.getProfile() + "/product_qr";
        java.io.File dirFile = new java.io.File(dir);
        if (!dirFile.exists() && !dirFile.mkdirs())
        {
            return AjaxResult.error("无法创建小程序码目录");
        }
        // 文件名带 merchantId：同一个 productId 在不同商户的小程序里
        // 要用各自 appid 生成，不能互相复用
        String fileName = "pq_" + merchantId + "_" + productId + ".png";
        java.io.File target = new java.io.File(dirFile, fileName);
        byte[] bytes;
        boolean cached = target.exists() && target.length() > 0;
        if (cached)
        {
            bytes = java.nio.file.Files.readAllBytes(target.toPath());
        }
        else
        {
            bytes = wxMaService.getWxaCodeUnlimited(scene, "pages/goods/detail/index", merchantId);
            if (bytes == null || bytes.length == 0)
            {
                return AjaxResult.error("生成小程序码失败");
            }
            try (java.io.FileOutputStream fos = new java.io.FileOutputStream(target))
            {
                fos.write(bytes);
            }
        }
        String dataUrl = "data:image/png;base64," + java.util.Base64.getEncoder().encodeToString(bytes);
        String url = serverConfig.getUrl() + com.ruoyi.common.constant.Constants.RESOURCE_PREFIX
                + "/product_qr/" + fileName;
        return AjaxResult.success()
                .put("dataUrl", dataUrl)
                .put("url", url)
                .put("scene", scene)
                .put("cached", cached);
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
        if (body.getCreateBy() == null) body.setCreateBy("merchant_" + me.getStaffUserId());

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
     * 该商品对当前调用方是否可见。
     *
     * <p>商户归属一律以服务端解析的为准，不看任何请求参数：
     * 商家态取员工 token 里的 merchantId，顾客态取 X-App-Id 解析出来的租户上下文
     * （MemberAuthInterceptor 对匿名请求会按 appid 写入 TenantContextHolder）。</p>
     *
     * <p>兜底策略是「解析不到商户就只放行上架商品」而不是全放行：appid 缺失时
     * 拦截器会 fallback 到默认商户，此时若把未上架商品也放出去，等于给默认商户
     * 开了一个不带 header 就能读草稿的后门。</p>
     */
    private boolean isVisibleToCaller(Product p)
    {
        Long owner = p.getMerchantId();
        com.ruoyi.biz.api.domain.LoginMember me = MemberContextHolder.get();
        // 商家态：自己商户的商品含草稿都可见（编辑页回填需要），别家一概不可见
        if (me != null && me.isStaffSession() && me.getMerchantId() != null)
        {
            return owner != null && owner.equals(me.getMerchantId());
        }
        // 顾客态：先卡上架，再卡商户
        if (!STATUS_ON.equals(p.getStatus()))
        {
            return false;
        }
        com.ruoyi.common.core.domain.model.TenantContext ctx =
                com.ruoyi.common.utils.TenantContextHolder.get();
        if (ctx == null || ctx.isPlatform())
        {
            return true;
        }
        if (ctx.isMerchant() && ctx.getMerchantId() != null)
        {
            return owner != null && owner.equals(ctx.getMerchantId());
        }
        if (ctx.isAgent() && ctx.getMerchantIds() != null)
        {
            return owner != null && ctx.getMerchantIds().contains(owner);
        }
        return true;
    }

    // ===================== 商家端：商品搭配（子品分组 / 几选几）=====================
    //
    // 为什么要在小程序侧重开一套而不直接用 PC 的 /biz/productSubitem/**：
    // 那套挂在 Spring Security 下、靠 @PreAuthorize + 后台 sys_user 的 perms 判权，
    // 小程序员工 token 走的是 MemberAuthInterceptor 这条完全独立的链路，
    // 拿员工 token 打 /biz/** 一律 401（实测「请求访问 /biz/productSubitem/groups
    // 认证失败」）。所以 pages/merchant/product/combo 那个页面即使把入口接上，
    // 每个操作也必然 401 —— 团购在手机上永远配不了套餐内容。
    //
    // 三条约束都在服务端做，不靠前端传：
    //   1) 商品必须属于当前登录员工的商户（assertMyProduct）
    //   2) 组/子品必须属于该商品（防拿别家的 groupId 往自己商品上挂，或反向删别家的组）
    //   3) 只有 OWNER/MANAGER 能改（店员只核销，不该动商品结构）

    /** 某商品的搭配分组（含每组子品） */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER}, includeHigher = true)
    @GetMapping("/subitem/groups")
    public AjaxResult subitemGroups(@RequestParam("productId") Long productId)
    {
        assertMyProduct(productId);
        return AjaxResult.success(subitemGroupService.selectByProductId(productId));
    }

    /** 新建搭配分组 */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER}, includeHigher = true)
    @PostMapping("/subitem/group")
    public AjaxResult addSubitemGroup(@RequestBody ProductSubitemGroup group)
    {
        if (group == null || group.getProductId() == null)
        {
            throw new ServiceException("缺少 productId");
        }
        assertMyProduct(group.getProductId());
        com.ruoyi.biz.api.domain.LoginMember me = MemberContextHolder.get();
        group.setCreateBy("mstaff-" + (me == null ? "" : me.getStaffUserId()));
        int rows = subitemGroupService.insert(group);
        if (rows <= 0)
        {
            return AjaxResult.error("新建失败");
        }
        AjaxResult r = AjaxResult.success("已新建分组");
        r.put("groupId", group.getGroupId());
        return r;
    }

    /**
     * 改分组（主要是「几选几」）。
     *
     * <p>pickRule 的合法性必须在服务端判：N 大于本组子品数就变成一个顾客永远
     * 满足不了的规则，下单页会卡死；N 等于子品数则和 ALL 同义，归一成 ALL
     * 避免同一语义在库里存两种值（PC 端 checkPickRule 就是这么做的，
     * 两边规则必须一致，否则手机上配的组在 PC 上显示成另一回事）。</p>
     */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER}, includeHigher = true)
    @PutMapping("/subitem/group")
    public AjaxResult editSubitemGroup(@RequestBody ProductSubitemGroup group)
    {
        if (group == null || group.getGroupId() == null)
        {
            throw new ServiceException("缺少 groupId");
        }
        ProductSubitemGroup exist = subitemGroupService.selectById(group.getGroupId());
        if (exist == null)
        {
            throw new ServiceException("分组不存在");
        }
        assertMyProduct(exist.getProductId());
        // productId 不许改：否则能把自己的组挂到别人的商品上
        group.setProductId(exist.getProductId());
        String rule = group.getPickRule();
        if (rule != null && !rule.trim().isEmpty() && !"ALL".equals(rule))
        {
            if (!rule.startsWith("PICK_"))
            {
                throw new ServiceException("选择规则格式不正确，应为 ALL 或 PICK_N");
            }
            int n;
            try
            {
                n = Integer.parseInt(rule.substring("PICK_".length()));
            }
            catch (NumberFormatException e)
            {
                throw new ServiceException("选择规则格式不正确：" + rule);
            }
            if (n <= 0)
            {
                throw new ServiceException("可选数量必须大于 0");
            }
            int size = subitemService.selectByGroupId(group.getGroupId()).size();
            if (size == 0)
            {
                throw new ServiceException("请先给该商品组添加单品，再设置几选几");
            }
            if (n > size)
            {
                throw new ServiceException("本组只有 " + size + " 个单品，不能设为选 " + n + " 个");
            }
            if (n == size)
            {
                group.setPickRule("ALL");
            }
        }
        return subitemGroupService.update(group) > 0 ? AjaxResult.success() : AjaxResult.error("保存失败");
    }

    /** 删分组（连带该组子品由 service 处理）。DELETE 保持幂等，删不到不报错 */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER}, includeHigher = true)
    @DeleteMapping("/subitem/group/{groupId}")
    public AjaxResult removeSubitemGroup(@PathVariable("groupId") Long groupId)
    {
        ProductSubitemGroup exist = subitemGroupService.selectById(groupId);
        if (exist != null)
        {
            assertMyProduct(exist.getProductId());
            subitemGroupService.deleteById(groupId);
        }
        return AjaxResult.success();
    }

    /** 某分组下的子品 */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER}, includeHigher = true)
    @GetMapping("/subitem/list")
    public AjaxResult subitemList(@RequestParam("groupId") Long groupId)
    {
        ProductSubitemGroup g = subitemGroupService.selectById(groupId);
        if (g == null)
        {
            throw new ServiceException("分组不存在");
        }
        assertMyProduct(g.getProductId());
        return AjaxResult.success(subitemService.selectByGroupId(groupId));
    }

    /** 加子品 */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER}, includeHigher = true)
    @PostMapping("/subitem")
    public AjaxResult addSubitem(@RequestBody com.ruoyi.biz.domain.ProductSubitem subitem)
    {
        if (subitem == null || subitem.getGroupId() == null)
        {
            throw new ServiceException("缺少 groupId");
        }
        // 名称必须在这里判：biz_product_subitem.subitem_name 是 NOT NULL 且无默认值，
        // 不校验就直接 insert，MySQL 抛 "Field 'subitem_name' doesn't have a default value"，
        // 而 RuoYi 的全局异常处理会把整段 SQL 异常原文塞进 msg 返给端上 ——
        // 商家在手机上看到的是一屏 "### Error updating database ... ProductSubitemMapper.xml"，
        // 完全不知道是名称没填。字段名写错（比如传 itemName 而不是 subitemName）也是这个下场。
        if (StringUtils.isEmpty(subitem.getSubitemName()))
        {
            throw new ServiceException("请填写单品名称（字段 subitemName）");
        }
        ProductSubitemGroup g = subitemGroupService.selectById(subitem.getGroupId());
        if (g == null)
        {
            throw new ServiceException("分组不存在");
        }
        assertMyProduct(g.getProductId());
        // productId 一律以分组归属为准，不信前端传值
        subitem.setProductId(g.getProductId());
        com.ruoyi.biz.api.domain.LoginMember me = MemberContextHolder.get();
        subitem.setCreateBy("mstaff-" + (me == null ? "" : me.getStaffUserId()));
        int rows = subitemService.insert(subitem);
        if (rows <= 0)
        {
            return AjaxResult.error("添加失败");
        }
        AjaxResult r = AjaxResult.success("已添加单品");
        r.put("subitemId", subitem.getSubitemId());
        return r;
    }

    /**
     * 删子品，并把超出范围的「几选几」收回来。
     *
     * <p>一个组 3 个单品、规则 PICK_2，删掉 1 个后只剩 2 个，规则还写着选 2 ——
     * 此时"选2"已等于全选却仍显示成限选，顾客看到的可选数量和实际不符。
     * 与 PC 端 shrinkPickRule 同一套收敛逻辑。</p>
     */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER}, includeHigher = true)
    @DeleteMapping("/subitem/{subitemId}")
    public AjaxResult removeSubitem(@PathVariable("subitemId") Long subitemId)
    {
        com.ruoyi.biz.domain.ProductSubitem exist = subitemService.selectById(subitemId);
        if (exist == null)
        {
            return AjaxResult.success();
        }
        ProductSubitemGroup g = exist.getGroupId() == null ? null
                : subitemGroupService.selectById(exist.getGroupId());
        if (g != null)
        {
            assertMyProduct(g.getProductId());
        }
        subitemService.deleteById(subitemId);
        if (g != null)
        {
            shrinkPickRule(g);
        }
        return AjaxResult.success();
    }

    /** 删完单品后收敛 pickRule：N >= 剩余单品数就归成 ALL */
    private void shrinkPickRule(ProductSubitemGroup group)
    {
        String rule = group.getPickRule();
        if (rule == null || !rule.startsWith("PICK_"))
        {
            return;
        }
        int n;
        try
        {
            n = Integer.parseInt(rule.substring("PICK_".length()));
        }
        catch (NumberFormatException e)
        {
            return;
        }
        if (n >= subitemService.selectByGroupId(group.getGroupId()).size())
        {
            group.setPickRule("ALL");
            subitemGroupService.update(group);
        }
    }

    /**
     * 商品必须属于当前登录员工的商户，否则拒。
     *
     * <p>商户从 token 取，不看请求参数 —— 否则改个 productId 就能编别家的套餐结构。</p>
     */
    private void assertMyProduct(Long productId)
    {
        if (productId == null)
        {
            throw new ServiceException("缺少 productId");
        }
        com.ruoyi.biz.api.domain.LoginMember me = MemberContextHolder.get();
        Long mine = me == null ? null : me.getMerchantId();
        if (mine == null)
        {
            throw new ServiceException("登录态缺少商户信息，请重新登录");
        }
        Product p = productService.selectProductByProductId(productId);
        if (p == null || p.getMerchantId() == null || !p.getMerchantId().equals(mine))
        {
            throw new ServiceException("商品不存在或无权操作");
        }
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
