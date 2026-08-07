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
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.biz.api.annotation.LoginRequired;
import com.ruoyi.biz.api.service.ApiOrderService;
import com.ruoyi.biz.api.service.WxPayService;
import com.ruoyi.biz.api.util.MemberContextHolder;
import com.ruoyi.biz.domain.Member;
import com.ruoyi.biz.domain.Order;
import com.ruoyi.biz.service.IMemberService;
import com.ruoyi.biz.service.IOrderService;
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
    @Autowired
    private ApiOrderService apiOrderService;

    @Autowired
    private IOrderService orderService;

    @Autowired
    private IMemberService memberService;

    @Autowired
    private WxPayService wxPayService;

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
     * 订单详情
     */
    @LoginRequired
    @GetMapping("/{orderId}")
    public AjaxResult detail(@PathVariable Long orderId)
    {
        return AjaxResult.success(orderService.selectOrderByOrderId(orderId));
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
        // 门店员工只能在自己被授权的门店核销，请求里的 storeId 必须等于 token 中的 storeId
        if (loginMember != null && "store".equals(loginMember.getUserType())
                && !storeId.equals(loginMember.getStoreId()))
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
        Order order = apiOrderService.verify(verifyCode, storeId,
                "store:" + (loginMember == null ? "" : loginMember.getMemberId()));
        return AjaxResult.success(order);
    }
}
