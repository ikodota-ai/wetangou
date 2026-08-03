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
        if (wxPayService.isMock())
        {
            apiOrderService.paySuccess(orderId);
            return AjaxResult.success().put("mock", true);
        }
        Member member = memberService.selectMemberByMemberId(MemberContextHolder.getMemberId());
        String openid = member == null ? null : member.getOpenid();
        int fen = WxPayService.yuanToFen(order.getPayAmount());
        JSONObject payParams = wxPayService.createJsapiOrderByMerchant(order.getMerchantId(), order.getOrderNo(), "订单-" + order.getOrderNo(), fen, openid);
        return AjaxResult.success(payParams);
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
