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
import com.alibaba.fastjson2.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.biz.api.annotation.LoginRequired;
import com.ruoyi.biz.api.service.ApiOrderServiceImpl;
import com.ruoyi.biz.api.service.WxPayService;
import com.ruoyi.biz.api.service.WxMaService;
import com.ruoyi.biz.api.util.MemberContextHolder;
import com.ruoyi.biz.domain.Member;
import com.ruoyi.biz.domain.Order;
import com.ruoyi.biz.domain.Product;
import com.ruoyi.biz.service.IMemberService;
import com.ruoyi.biz.service.IOrderService;
import com.ruoyi.biz.service.IProductService;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.biz.api.annotation.StoreStaffRequired;
import com.ruoyi.biz.api.domain.LoginMember;

/**
 * 小程序-订单（下单、支付、核销、我的订单）
 *
 * @author dytuangou
 */
@Anonymous
@RestController
@RequestMapping("/api/order")
public class ApiOrderController
{
    private static final Logger log = LoggerFactory.getLogger(ApiOrderController.class);
    @Autowired
    private ApiOrderServiceImpl apiOrderService;

    @Autowired
    private IOrderService orderService;

    @Autowired
    private IMemberService memberService;

    @Autowired
    private WxPayService wxPayService;

    @Autowired
    private IProductService productService;

    @Autowired
    private WxMaService wxMaService;

    /**
     * 下单
     */
    @LoginRequired
    @PostMapping
    public AjaxResult create(@RequestBody JSONObject body)
    {
        Long memberId = MemberContextHolder.getMemberId();
        Order order = apiOrderService.placeOrder(memberId,
                body.getLong("productId"),
                body.getLong("num"),
                body.getLong("memberVoucherId"),
                body.getLong("distributorId"));
        return AjaxResult.success(order);
    }

    /**
     * 待支付订单换券（选券 / 换一张 / 取消用券）。
     *
     * <p>券入口原先只有下单页那一处，订单一建出来就没法再用券了 ——
     * 「到店自取」这类先下单、到店才付的场景里，用户领了券也用不上。</p>
     *
     * <p>body: {"memberVoucherId": 123}；传 null 或不传该字段 = 取消用券。</p>
     */
    @LoginRequired
    @PostMapping("/{orderId}/voucher")
    public AjaxResult changeVoucher(@PathVariable Long orderId, @RequestBody(required = false) JSONObject body)
    {
        Long memberVoucherId = body == null ? null : body.getLong("memberVoucherId");
        Order order = apiOrderService.changeVoucher(MemberContextHolder.getMemberId(), orderId, memberVoucherId);
        return AjaxResult.success(order);
    }

    /**
     * 发起支付：返回小程序 wx.requestPayment 参数。
     * mock模式（未配齐微信支付凭证）直接置为支付成功并返回 mock=true。
     */
    @LoginRequired
    @PostMapping("/prepay/{orderId}")
    public AjaxResult prepay(@PathVariable Long orderId)
    {
        Order order = orderService.selectOrderByOrderId(orderId);
        if (order == null)
        {
            throw new ServiceException("订单不存在");
        }
        if (!order.getMemberId().equals(MemberContextHolder.getMemberId()))
        {
            throw new ServiceException("无权支付该订单");
        }
        if (!"0".equals(order.getStatus()))
        {
            throw new ServiceException("订单状态不允许支付");
        }
        // 通用响应：orderNo / amount / payNo / payInfoId / expireTime
        // mock 模式也返回这些字段（方便支付中间页展示）
        java.util.Map<String, Object> resp = new java.util.LinkedHashMap<>();
        resp.put("orderNo", order.getOrderNo());
        resp.put("amount", order.getPayAmount());
        resp.put("expireTime", System.currentTimeMillis() + 2 * 60 * 60 * 1000L); // 2 小时过期
        if (wxPayService.isMock())
        {
            // mock 模式：直接标为已支付，payNo/payInfoId 本地生成
            String payNo = "MOCK" + System.currentTimeMillis() + (int) (Math.random() * 9000 + 1000);
            Order paidOrder = apiOrderService.paySuccess(orderId);
            Long payInfoId = paidOrder == null ? null : paidOrder.getOrderId();
            resp.put("mock", true);
            resp.put("payNo", payNo);
            resp.put("payInfoId", payInfoId);
            return AjaxResult.success(resp);
        }
        Member member = memberService.selectMemberByMemberId(MemberContextHolder.getMemberId());
        String openid = member == null ? null : member.getOpenid();
        int fen = WxPayService.yuanToFen(order.getPayAmount());
        JSONObject payParams = wxPayService.createJsapiOrderByMerchant(order.getMerchantId(), order.getOrderNo(), "订单-" + order.getOrderNo(), fen, openid);
        // 真实微信：payParams.timeStamp/nonceStr/package/signType/paySign，prepay_id 在 package 里
        resp.put("payNo", payParams.getString("transaction_id"));   // 真实下单后微信返回
        resp.put("payInfoId", payParams.getString("prepay_id"));     // 预支付交易会话标识
        resp.putAll(payParams);                                      // timeStamp/nonceStr/package/signType/paySign
        return AjaxResult.success(resp);
    }

    /**
     * 模拟支付成功（仅mock模式下由前端触发；真实环境由微信支付回调触发）
     */
    @LoginRequired
    @PostMapping("/pay/{orderId}")
    public AjaxResult pay(@PathVariable Long orderId)
    {
        Order order = orderService.selectOrderByOrderId(orderId);
        if (order == null || !order.getMemberId().equals(MemberContextHolder.getMemberId()))
        {
            throw new ServiceException("订单不存在");
        }
        if (!wxPayService.isMock())
        {
            throw new ServiceException("请通过微信支付完成付款");
        }
        return AjaxResult.success(apiOrderService.paySuccess(orderId));
    }

    /**
     * 调试端点：mock 模式开放 /_e2e_paySuccess/{orderId}，走真实 paySuccess 流程入账 commission
     * 仅在 sys_config wx.pay.mockEnabled=true 时可用；生产应保持 false
     * 不走 wxPayService.createOrder，直接落 paySuccess，验证佣金真实入账链路
     */
    @LoginRequired
    @PostMapping("/_e2e_paySuccess/{orderId}")
    public AjaxResult e2ePaySuccess(@PathVariable Long orderId)
    {
        if (!wxPayService.isMock())
        {
            throw new ServiceException("调试端点仅 mock 模式开放");
        }
        Order order = orderService.selectOrderByOrderId(orderId);
        if (order == null || !order.getMemberId().equals(MemberContextHolder.getMemberId()))
        {
            throw new ServiceException("订单不存在");
        }
        if (!"0".equals(order.getStatus()))
        {
            throw new ServiceException("订单状态不允许支付");
        }
        return AjaxResult.success(apiOrderService.paySuccess(orderId));
    }

    /**
     * 我的订单列表（按状态筛选）
     */
    @LoginRequired
    @GetMapping("/list")
    public AjaxResult list(@RequestParam(required = false) String status)
    {
        Order query = new Order();
        query.setMemberId(MemberContextHolder.getMemberId());
        query.setStatus(status);
        List<Order> list = orderService.selectOrderList(query);
        return AjaxResult.success(list);
    }

    /**
     * 订单详情（按主键）
     */
    @LoginRequired
    @GetMapping("/{orderId}")
    public AjaxResult detail(@PathVariable Long orderId)
    {
        Order order = orderService.selectOrderByOrderId(orderId);
        if (order == null)
        {
            throw new ServiceException("订单不存在");
        }
        return detailOf(order);
    }

    /**
     * 订单详情（按商户订单号）
     *
     * <p>给微信支付「商品订单详情path」用。那个配置项里的订单号占位符，
     * 微信填进来的是下单时传的 out_trade_no —— 也就是 biz_order.order_no
     * （形如 D1787398679265359），不是数据库主键 order_id。
     * 只有 /{orderId} 这一个入口时，用户从微信账单点「查看订单」跳进小程序，
     * 参数拿 order_no 去请求会直接 400（Long 转换失败）。</p>
     *
     * <p>路径特意加 /no/ 前缀区分：order_no 全是 D/P 开头的字符串，
     * 但如果放同一个 /{x} 上让 Spring 按类型试探，数字型订单号会被两个
     * 方法同时匹配到，属于埋雷。</p>
     */
    @LoginRequired
    @GetMapping("/no/{orderNo}")
    public AjaxResult detailByNo(@PathVariable String orderNo)
    {
        Order order = orderService.selectOrderByOrderNo(orderNo);
        if (order == null)
        {
            throw new ServiceException("订单不存在");
        }
        return detailOf(order);
    }

    /**
     * 两个详情入口共用的归属校验 —— 越权判断不能只写在其中一个上。
     */
    private AjaxResult detailOf(Order order)
    {
        if (!order.getMemberId().equals(MemberContextHolder.getMemberId()))
        {
            throw new ServiceException("无权查看他人订单");
        }
        return AjaxResult.success(order);
    }

    /**
     * 门店核销（店员在门店端使用，携带门店ID与核销码）
     */
    @LoginRequired
    @StoreStaffRequired
    @PostMapping("/verify")
    public AjaxResult verify(@RequestBody JSONObject body)
    {
        Long storeId = body.getLong("storeId");
        String verifyCode = body.getString("verifyCode");
        String orderNo = body.getString("orderNo");
        if (StringUtils.isEmpty(verifyCode) && StringUtils.isEmpty(orderNo))
        {
            throw new ServiceException("核销码或订单编号至少填一个");
        }
        if (storeId == null)
        {
            throw new ServiceException("门店ID不能为空");
        }
        LoginMember loginMember = MemberContextHolder.get();
        // 员工只能在自己被授权的门店核销。
        // 原来比的是 token 里的单个 storeId，多店员工（含 store_id=0 展开的老板）
        // 切到别的店就核销不了；改用 hasStore 比整个授权门店集合。
        if (loginMember != null && loginMember.isStaffSession()
                && !loginMember.hasStore(storeId))
        {
            throw new ServiceException("无权操作其他门店");
        }
        // 优先 verifyCode；为空时用 orderNo 解析（一次额外查）
        if (StringUtils.isEmpty(verifyCode) && !StringUtils.isEmpty(orderNo))
        {
            Order byNo = orderService.selectOrderByOrderNo(orderNo.trim());
            if (byNo == null)
            {
                throw new ServiceException("订单编号无效");
            }
            verifyCode = byNo.getVerifyCode();
        }
        // 核销人标识：商家端链路没有 memberId（那是会员主键），要用 staffUserId，
        // 否则核销记录里全是 "store:null"，事后查不到是谁核的。
        Object operator = loginMember == null ? "" :
                (loginMember.getStaffUserId() != null ? loginMember.getStaffUserId() : loginMember.getMemberId());
        Order order = apiOrderService.verify(verifyCode, storeId, "store:" + operator);
        // 核销成功 → 异步发订阅消息给买家（不阻塞主流程，异常仅 log）
        notifyVerifySuccessAsync(order);
        return AjaxResult.success(order);
    }

    /**
     * 客人端：取订单的核销 Scheme URL
     *
     * <p>用于「出示给店员」场景：客人在小程序下单团购/优惠券/组合券后
     * → 我的订单页点「出示给店员」→ 展示一个二维码
     * → 店员手机微信首页「扫一扫」扫这个码
     * → 微信自动唤起小程序 verify 页 → 自动核销。</p>
     *
     * <p>仅订单归属人可调（防他人冒用券码）。</p>
     */
    @LoginRequired
    @GetMapping("/{orderId}/scheme")
    public AjaxResult orderScheme(@org.springframework.web.bind.annotation.PathVariable("orderId") Long orderId)
    {
        if (orderId == null) return AjaxResult.error("orderId 不能为空");
        Order order = orderService.selectOrderByOrderId(orderId);
        if (order == null) return AjaxResult.error("订单不存在");
        // 防冒用：只允许订单本人调
        Long loginMemberId = com.ruoyi.biz.api.util.MemberContextHolder.getMemberId();
        if (loginMemberId == null || !loginMemberId.equals(order.getMemberId())) {
            return AjaxResult.error("无权查看该订单的核销码");
        }
        // 仅已支付订单可生成 Scheme
        if (!"1".equals(order.getStatus()) && !"2".equals(order.getStatus())) {
            return AjaxResult.error("订单状态不可核销（仅已支付/已核销可出示）");
        }
        // 取商品信息
        Product product = order.getProductId() != null
            ? productService.selectProductByProductId(order.getProductId()) : null;

        // 核销码：优先用订单上的 verifyCode，没有则即时生成
        String verifyCode = order.getVerifyCode();
        if (verifyCode == null || verifyCode.isEmpty()) {
            verifyCode = com.ruoyi.common.utils.uuid.IdUtils.fastSimpleUUID().substring(0, 12).toUpperCase();
        }

        // 拼 query：code + sid
        String query = "code=" + java.net.URLEncoder.encode(verifyCode, java.nio.charset.StandardCharsets.UTF_8)
                     + "&sid=" + (order.getStoreId() == null ? 0 : order.getStoreId());
        String scheme = wxMaService.generateScheme("pages/merchant/verify/index", query, true, order.getMerchantId());

        java.util.Map<String, Object> vo = new java.util.LinkedHashMap<>();
        vo.put("scheme", scheme);
        vo.put("page", "pages/merchant/verify/index");
        vo.put("verifyCode", verifyCode);
        vo.put("orderId", order.getOrderId());
        vo.put("orderNo", order.getOrderNo());
        vo.put("storeId", order.getStoreId());
        vo.put("productName", product == null ? order.getProductName() : product.getProductName());
        vo.put("payAmount", order.getPayAmount());
        vo.put("status", order.getStatus());
        vo.put("statusName", "1".equals(order.getStatus()) ? "待使用" : "2".equals(order.getStatus()) ? "已核销" : "未知");
        return AjaxResult.success(vo);
    }

    /**
     * 核销成功订阅消息（异步）
     *
     * <p>取买家 openid（可能查不到，比如临时下单未绑微信 → 静默跳过），
     * 调微信 subscribe/send，失败仅 log 不抛错（核销主流程不受影响）。</p>
     */
    private void notifyVerifySuccessAsync(Order order)
    {
        if (order == null || order.getMemberId() == null) return;
        try
        {
            // 异步线程池执行（不阻塞 verify 响应）
            java.util.concurrent.CompletableFuture.runAsync(() -> {
                try
                {
                    Member buyer = memberService.selectMemberByMemberId(order.getMemberId());
                    if (buyer == null || buyer.getOpenid() == null || buyer.getOpenid().isEmpty()) {
                        log.info("[核销通知] 会员 {} 无 openid，跳过", order.getMemberId());
                        return;
                    }
                    String productName = "商品";
                    if (order.getProductId() != null) {
                        Product p = productService.selectProductByProductId(order.getProductId());
                        if (p != null && p.getProductName() != null) productName = p.getProductName();
                    }
                    String templateId = "VERIFY_SUCCESS_TEMPLATE_ID"; // 实际从 sys_config / biz_wxconfig 读取
                    java.util.Map<String, java.util.Map<String, String>> data = new java.util.HashMap<>();
                    data.put("thing1", java.util.Collections.singletonMap("value", truncate(productName, 20)));
                    data.put("date2", java.util.Collections.singletonMap("value", new java.text.SimpleDateFormat("yyyy-MM-dd HH:mm").format(order.getVerifyTime())));
                    data.put("thing3", java.util.Collections.singletonMap("value", truncate("核销成功，请到店使用", 20)));
                    wxMaService.sendSubscribeMessage(buyer.getOpenid(), templateId, order.getMerchantId(), data);
                }
                catch (Exception e) {
                    log.warn("[核销通知] 发送失败 orderId={} err={}", order.getOrderId(), e.getMessage());
                }
            });
        }
        catch (Exception e)
        {
            log.warn("[核销通知] 调度失败 orderId={} err={}", order.getOrderId(), e.getMessage());
        }
    }

    private static String truncate(String s, int max)
    {
        if (s == null) return "";
        return s.length() <= max ? s : s.substring(0, max);
    }

    /**
     * 订单核销二维码（太阳码）
     *  - 用户出示给员工扫，员工扫到后跳 /pages/merchant/verify/index?code=...&sid=...
     *  - 必须本人订单
     *  - 仅已支付/已核销状态可生成
     *
     * 返回：image/png（280x280 太阳码）
     */
    @GetMapping(value = "/{orderId}/qrcode", produces = "image/png")
    public byte[] orderQrcode(@PathVariable("orderId") Long orderId) throws Exception
    {
        if (orderId == null) throw new ServiceException("orderId 不能为空");
        Order order = orderService.selectOrderByOrderId(orderId);
        if (order == null) throw new ServiceException("订单不存在");
        Long loginMemberId = MemberContextHolder.getMemberId();
        if (loginMemberId == null || !loginMemberId.equals(order.getMemberId()))
        {
            throw new ServiceException("无权查看该订单的核销码");
        }
        if (!"1".equals(order.getStatus()) && !"2".equals(order.getStatus()))
        {
            throw new ServiceException("订单状态不可核销");
        }
        String verifyCode = order.getVerifyCode();
        if (verifyCode == null || verifyCode.isEmpty())
        {
            verifyCode = com.ruoyi.common.utils.uuid.IdUtils.fastSimpleUUID().substring(0, 12).toUpperCase();
        }
        // scene 格式：verify:orderId:code （长度 <= 32）
        String scene = "verify:" + order.getOrderId() + ":" + verifyCode;
        // page 指向会员订单详情页（员工扫到进会员端不可，再让他扫码核销）
        // 实际员工场景走 Scheme URL（orderScheme 接口），本接口给用户展示
        return wxMaService.getWxaCodeUnlimited(scene, "pages/order/detail/index", order.getMerchantId());
    }

    /**
     * 订单核销二维码（dataUrl 形式，便于小程序 <image> 直显，不依赖 token header）
     *
     * <p>和 /qrcode 区别：本端点返 JSON { dataUrl, verifyCode, orderId, scene }，
     * dataUrl 是 image/png base64，前端可直接 <image src="{{qrDataUrl}}"> 渲染。
     * <p>真实 wxacode（无 mock）走此端点也安全：图片以 dataUrl 在前端渲染，
     * 不暴露内部 access_token 链路。
     */
    @GetMapping(value = "/{orderId}/qrcode-data", produces = "application/json")
    public AjaxResult orderQrcodeData(@PathVariable("orderId") Long orderId) throws Exception
    {
        if (orderId == null) return AjaxResult.error("orderId 不能为空");
        Order order = orderService.selectOrderByOrderId(orderId);
        if (order == null) return AjaxResult.error("订单不存在");
        Long loginMemberId = MemberContextHolder.getMemberId();
        if (loginMemberId == null || !loginMemberId.equals(order.getMemberId()))
        {
            return AjaxResult.error("无权查看该订单的核销码");
        }
        if (!"1".equals(order.getStatus()) && !"2".equals(order.getStatus()))
        {
            return AjaxResult.error("订单状态不可核销");
        }
        String verifyCode = order.getVerifyCode();
        if (verifyCode == null || verifyCode.isEmpty())
        {
            verifyCode = com.ruoyi.common.utils.uuid.IdUtils.fastSimpleUUID().substring(0, 12).toUpperCase();
        }
        String scene = "verify:" + order.getOrderId() + ":" + verifyCode;
        byte[] png = wxMaService.getWxaCodeUnlimited(scene, "pages/order/detail/index", order.getMerchantId());
        if (png == null || png.length == 0) {
            return AjaxResult.error("生成核销码失败");
        }
        String dataUrl = "data:image/png;base64," + java.util.Base64.getEncoder().encodeToString(png);
        java.util.Map<String, Object> vo = new java.util.LinkedHashMap<>();
        vo.put("orderId", order.getOrderId());
        vo.put("verifyCode", verifyCode);
        vo.put("scene", scene);
        vo.put("dataUrl", dataUrl);
        vo.put("size", png.length);
        return AjaxResult.success(vo);
    }

}