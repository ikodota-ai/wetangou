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
import com.ruoyi.biz.domain.ProductType;
import com.ruoyi.biz.service.IProductTypeService;
import com.ruoyi.biz.domain.Store;
import com.ruoyi.biz.service.IStoreService;
import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.biz.service.IMerchantService;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
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
    private IProductTypeService productTypeService;

    @Autowired
    private IStoreService storeService;

    @Autowired
    private IMerchantService merchantService;

    @Autowired
    private com.ruoyi.system.service.ISysDictDataService dictDataService;

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
        // 同上：两者都是逗号串，必须逐张拼 base
        p.setCover(ImageUrlUtils.toAbsoluteCsv(p.getCover()));
        p.setImages(ImageUrlUtils.toAbsoluteCsv(p.getImages()));
        // E1 收口：统一 subitemGroups 放顶层。历史曾有 data 子对象冗余，
        // 现已确认无客户端依赖（admin 用 listGroups 端点，小程序 pages/goods/detail/index.js
        // 第 50 行读 d.subitemGroups 顶层），删 dataMap 冗余让 API 干净。
        AjaxResult result = AjaxResult.success(p);
        String t = p.getTypeCode() == null ? "" : p.getTypeCode();
        // 子品只看库里有没有，不按 typeCode 白名单。
        //
        // 原先这里写的是 {@code if ("GROUPON".equals(t) || "COMBO".equals(t))}，
        // 理由是「PC 建品页只给这两类开了搜配入口」。但子品表里存不存在数据
        // 跟商品类型并不挂钩：本地 biz_product_subitem_group 里 BOOKING 类型的
        // 999534「云南野生菌双人火锅套餐」真有 4 组 17 个子品
        // （锅底 2选1 / 荟菜 4选4 / 素菜 4选4 / 饮品 3选2），
        // 却因为不在白名单而永远下发 null —— 顾客看不到自己到店能挑什么，
        // 而“能挑几样”正是他判断这个套餐值不值的前提。
        //
        // 换成无条件查、有内容才下发：没子品的商品（代金券等）查出空列表，
        // 不放进 result，前端那张卡的 wx:if 行为不变。
        List<ProductSubitemGroup> groups = subitemGroupService.selectByProductId(productId);
        if (groups != null && !groups.isEmpty())
        {
            result.put("subitemGroups", groups);
        }

        // 类型名与面向顾客的使用说明，从 biz_product_type 字典取。
        //
        // 原先小程序详情页自己维护了一张 typeText() 映射表（GROUPON 写死「团购套餐」），
        // 而运营早就在后台把它改成了「到店自取」—— 字典表形同虚设，
        // 改了名字顾客端半点不动。类型说明卡同理（5 段文案硬编码在 WXML）。
        // 现在统一从字典下发，前端只负责渲染。
        if (StringUtils.isNotEmpty(t))
        {
            ProductType pt = productTypeService.selectByCode(t);
            if (pt != null)
            {
                result.put("typeName", pt.getTypeName());
                result.put("typeTips", pt.getTypeTips());
            }
        }

        // 适用门店的服务设施标签（已翻译成中文）。
        //
        // 原先详情页那一行「服务」写的是「免预约 / 到店核销」—— 那是预约方式，
        // 不是服务设施。真正的服务设施（可堂食 / 提供独立空间 / 免费停车…）存在
        // biz_store.services，顾客在商品页上从来看不到，而这是他判断能不能去的前提。
        //
        // 取主门店（store_id）的设施；多店商品各店设施可能不同，但商品页只能展一份，
        // 以主门店为准比一个都不展强（具体到店设施在门店详情页看）。
        Long mainStoreId = p.getStoreId();
        if (mainStoreId == null && StringUtils.isNotEmpty(p.getStoreIds()))
        {
            String first = p.getStoreIds().split(",")[0].trim();
            if (StringUtils.isNotEmpty(first))
            {
                try { mainStoreId = Long.valueOf(first); } catch (NumberFormatException ignore) {}
            }
        }
        if (mainStoreId != null)
        {
            Store st = storeService.selectStoreByStoreId(mainStoreId);
            if (st != null)
            {
                result.put("storeServices", translateServices(st.getServices()));
                // 门店营业时间与评分：详情页「适用门店」卡里原先写死了
                // 「周一至周日 09:00-22:30」和「暂无评分」五颗空星。
                result.put("storeHours", st.getBusinessHours());
                result.put("storeRating", st.getRating());
                result.put("storeNameMain", st.getStoreName());
            }
        }

        // 适用门店完整列表。
        //
        // 商品可以多店通用（store_ids 逗号串，实测 999534 = "100,101,200"），
        // 但详情页那张「适用门店」卡只画了主门店一家，旁边一行「3店通用 >」
        // 还是不可点的纯文本：顾客看到“3 店”却无法知道到底是哪 3 家，
        // 也就无法判断离自己最近那家到底能不能用。
        //
        // 不复用 store_names 那个子查询（它只是 group_concat 出一串名字）：
        // 顾客要的是地址、营业时间、电话这些能拿来决定去哪家的信息。
        List<Map<String, Object>> applicableStores = new ArrayList<Map<String, Object>>();
        java.util.LinkedHashSet<Long> storeIdSet = new java.util.LinkedHashSet<Long>();
        if (StringUtils.isNotEmpty(p.getStoreIds()))
        {
            for (String one : p.getStoreIds().split(","))
            {
                String v = one.trim();
                if (StringUtils.isEmpty(v))
                {
                    continue;
                }
                try { storeIdSet.add(Long.valueOf(v)); } catch (NumberFormatException ignore) {}
            }
        }
        // 单店商品（store_ids 为空、只有 store_id）也要进这个列表，
        // 否则前端得维护两套渲染分支。
        if (storeIdSet.isEmpty() && p.getStoreId() != null && p.getStoreId() > 0L)
        {
            storeIdSet.add(p.getStoreId());
        }
        for (Long sid : storeIdSet)
        {
            Store one = storeService.selectStoreByStoreId(sid);
            if (one == null)
            {
                continue;
            }
            Map<String, Object> m = new HashMap<String, Object>();
            m.put("storeId", one.getStoreId());
            m.put("storeName", one.getStoreName());
            m.put("address", one.getAddress());
            m.put("phone", one.getPhone());
            m.put("businessHours", one.getBusinessHours());
            m.put("rating", one.getRating());
            m.put("longitude", one.getLongitude());
            m.put("latitude", one.getLatitude());
            m.put("services", translateServices(one.getServices()));
            applicableStores.add(m);
        }
        result.put("applicableStores", applicableStores);

        // 商户级展示开关（销量 / 库存）。
        // 必须兑底成 "1"：商户缓存 merchant:* 没 TTL，新增列之前写进去的快照
        // 反序列化回来这两个 key 是 null（promoter_enabled 上线时踩过同一个坑），
        // 不兑底就会把所有老商户的销量和库存整体隐掉。
        result.put("showSales", "1");
        result.put("showStock", "1");
        if (p.getMerchantId() != null)
        {
            Merchant mch = merchantService.selectMerchantByMerchantId(p.getMerchantId());
            if (mch != null)
            {
                result.put("showSales", StringUtils.isEmpty(mch.getShowSales()) ? "1" : mch.getShowSales());
                result.put("showStock", StringUtils.isEmpty(mch.getShowStock()) ? "1" : mch.getShowStock());
            }
        }
        return result;
    }

    /**
     * 把 biz_store.services 的字典码值（dine_in,can_book）翻译成中文标签。
     *
     * 与 ApiStoreController.services 同口径：翻译在服务端做，前端不得自己维护映射表，
     * 否则后台字典加了新码值前端就不显示。
     */
    private List<String> translateServices(String services)
    {
        List<String> labels = new ArrayList<String>();
        if (StringUtils.isEmpty(services))
        {
            return labels;
        }
        for (String code : services.split(","))
        {
            String c = code.trim();
            if (StringUtils.isEmpty(c))
            {
                continue;
            }
            String label = dictDataService.selectDictLabel("biz_store_service", c);
            labels.add(StringUtils.isEmpty(label) ? c : label);
        }
        return labels;
    }

    /**
     * 本店更多商品（商品详情页底部推荐位）。
     *
     * <p>为什么新开而不复用 {@code /list}：那个端点不分页一次全返，
     * 也不会把当前正在看的这个商品排除掉 —— 推荐位里摆一张
     * 跟当前页一模一样的卡，点进去还是自己，看着就像坏了。
     *
     * <p>背景：详情页底部那张「本店更多商品（3）」卡的 WXML 分支一直存在，
     * 读的是 {@code product.moreGoods} —— 而后端从未下发过这个字段，
     * 所以真机上这张卡永远不可能出现；连标题里的「3」都是写死的。
     * 对比抖音来客，推荐位是商家复购的主要入口（「更多本店团购(6)」、
     * 「小伙伴们还喜欢」各占一屏）。
     *
     * <p>范围口径：优先同门店（顾客已经在看这家店了），同门店不够再补同商户。
     * 跨商户一律不进：推荐位的点击会直接 redirectTo 到对方详情页，
     * 而 appid 就是租户边界，把别家商户的货推到本商户小程序里是数据泄露。
     */
    @GetMapping("/{productId}/more")
    public AjaxResult moreGoods(@PathVariable Long productId,
                               @RequestParam(required = false) Integer limit)
    {
        Product cur = productService.selectProductByProductId(productId);
        if (cur == null || !isVisibleToCaller(cur))
        {
            return AjaxResult.error("商品不存在或已下架");
        }
        int max = (limit == null || limit <= 0) ? 6 : Math.min(limit, 20);

        java.util.LinkedHashMap<Long, Product> picked = new java.util.LinkedHashMap<Long, Product>();

        // 第一轮：同门店。
        if (cur.getStoreId() != null && cur.getStoreId() > 0L)
        {
            Product q = new Product();
            q.setStatus("0");
            q.setMerchantId(cur.getMerchantId());
            q.setStoreId(cur.getStoreId());
            collectMore(picked, productService.selectProductList(q), productId, max);
        }
        // 第二轮：同商户其他门店，补到 max。
        if (picked.size() < max && cur.getMerchantId() != null)
        {
            Product q = new Product();
            q.setStatus("0");
            q.setMerchantId(cur.getMerchantId());
            collectMore(picked, productService.selectProductList(q), productId, max);
        }

        List<Product> out = new ArrayList<Product>(picked.values());
        return AjaxResult.success(fillImageUrls(out));
    }

    /**
     * 把候选商品收进结果集，跳过当前商品、去重、封顶。
     * 用 LinkedHashMap 而不是 List：两轮查询（同门店 / 同商户）会重叠，
     * 不去重同一个商品会在推荐位里出现两次。
     */
    private void collectMore(java.util.LinkedHashMap<Long, Product> picked,
                             List<Product> candidates, Long selfId, int max)
    {
        if (candidates == null)
        {
            return;
        }
        for (Product one : candidates)
        {
            if (picked.size() >= max)
            {
                return;
            }
            if (one == null || one.getProductId() == null)
            {
                continue;
            }
            if (one.getProductId().equals(selfId))
            {
                continue;
            }
            picked.put(one.getProductId(), one);
        }
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
     * 商品类型字典（biz_product_type）
     *
     * <p>为什么要开这个端点：小程序商家端建品页自己写了一份
     * TYPE_LIST 硬编码（GROUPON →「团购套餐」），会员端详情页又写了一份 typeText()。
     * 而运营已经在后台把它改成了「到店自取」——三处名字各说各话，
     * 商家在建品页选的是「团购套餐」，顾客在详情页看到的却该是「到店自取」。
     * 统一从字典下发，前端不再自己维护映射表。</p>
     *
     * <p>appCanCreate=1 时只返小程序允许创建的那几种（建品页用）；
     * 不传则全返（详情页/列表页需要能翻译所有类型，包括已停用的）。</p>
     */
    @GetMapping("/type/list")
    public AjaxResult typeList(@RequestParam(required = false) Integer appCanCreate)
    {
        ProductType query = new ProductType();
        query.setAppCanCreate(appCanCreate);
        return AjaxResult.success(productTypeService.selectList(query));
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
     * <p>补默认值都用「原值为 null 才补」，避免把商家显式选的值覆盖成默认。
     * 但「原值」指的是「库里已有的那一行」，不是「本次请求体里的」：
     * 小程序的编辑是局部提交（只传这次改的几个 ext 字段），
     * 若拿请求体当基准判 null，每次局部保存都会把未提交的字段
     * 覆写成默认值 —— 商家先选好的投放渠道（如只投首页+拼团）
     * 会在下一次改日期时静默变回平台全量默认（实测已重现），
     * 券码类型/自用限频同理。所以这里先读一次已有行作为基准。</p>
     */
    private void saveExtByTypeCode(Product body) {
        if (body == null || body.getProductId() == null) return;
        ProductExt ext = body.getExt() != null ? body.getExt() : new ProductExt();
        ext.setProductId(body.getProductId());
        // 库里已有的那一行：只用来判断“这个字段是不是真的从来没值”，
        // 不把旧值回填进 ext —— mapper 的 update 本身就是 <if != null> 局部更新，
        // 回填反而会把商家“清空某个值”的意图弄没。
        ProductExt old = extService.selectById(body.getProductId());
        // 公共默认值：只在「请求没传 && 库里也没有」时兜底
        if (ext.getDailyUseLimit() == null && (old == null || old.getDailyUseLimit() == null)) ext.setDailyUseLimit(0);
        if (ext.getRefundRuleType() == null && (old == null || old.getRefundRuleType() == null)) ext.setRefundRuleType("ANYTIME");
        if (ext.getCodeType() == null && (old == null || old.getCodeType() == null)) ext.setCodeType("MERCHANT");
        if (ext.getStaffPromote() == null && (old == null || old.getStaffPromote() == null)) ext.setStaffPromote(0);
        // 投放渠道：商家端没传且库里也空时才套平台字典的默认勾选，
        // 否则这批商品的 sale_channels 是空的，等顾客端真按渠道过滤时会整批消失
        boolean reqNoChannel = ext.getSaleChannels() == null || ext.getSaleChannels().trim().isEmpty();
        boolean dbNoChannel = old == null || old.getSaleChannels() == null || old.getSaleChannels().trim().isEmpty();
        if (reqNoChannel && dbNoChannel) {
            ext.setSaleChannels(channelService.defaultChannelCodes());
        }
        String tc = body.getTypeCode();
        if (tc != null) {
            // 同上：类型默认值也只在库里真的没值时才补。
            // 否则商家把组合券包的“自动延期”从 30 改成 7，
            // 下次只改个价格就又变回 30。
            if ("VOUCHER".equals(tc)) {
                if (ext.getVoucherAutoName() == null && (old == null || old.getVoucherAutoName() == null)) ext.setVoucherAutoName(1);
                if (ext.getVoucherMinConsume() == null && (old == null || old.getVoucherMinConsume() == null)) ext.setVoucherMinConsume(body.getMinConsume());
            } else if ("COMBO".equals(tc)) {
                if (ext.getComboTotalValue() == null && (old == null || old.getComboTotalValue() == null)) ext.setComboTotalValue(body.getTotalValue());
                if (ext.getComboSaleType() == null && (old == null || old.getComboSaleType() == null)) ext.setComboSaleType("LIMIT");
                if (ext.getComboAutoExtendDays() == null && (old == null || old.getComboAutoExtendDays() == null)) ext.setComboAutoExtendDays(30);
            } else if ("GROUPON".equals(tc)) {
                if (ext.getGrouponPickRule() == null && (old == null || old.getGrouponPickRule() == null)) ext.setGrouponPickRule("ALL");
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
            // cover/images 都是逗号串（头图最多 5 张 / 环境图 10 张），
            // 单值版 toAbsolute 只会给整串头部拼 base，第二张以后仍是相对路径。
            p.setCover(ImageUrlUtils.toAbsoluteCsv(p.getCover()));
            p.setImages(ImageUrlUtils.toAbsoluteCsv(p.getImages()));
        }
        return list;
    }
}
