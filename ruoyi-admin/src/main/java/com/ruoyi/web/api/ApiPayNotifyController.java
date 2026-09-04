package com.ruoyi.web.api;

import java.io.BufferedReader;
import java.util.Date;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.alibaba.fastjson2.JSONObject;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.biz.api.service.ApiOrderServiceImpl;
import com.ruoyi.biz.api.service.WxPayService;
import com.ruoyi.biz.domain.MemberVoucher;
import com.ruoyi.biz.domain.Order;
import com.ruoyi.biz.domain.PayBill;
import com.ruoyi.biz.service.IMemberVoucherService;
import com.ruoyi.biz.service.IOrderService;
import com.ruoyi.biz.service.IPayBillService;
import jakarta.servlet.http.HttpServletRequest;

/**
 * 微信支付V3 支付结果回调
 *
 * @author dytuangou
 */
@Anonymous
@RestController
@RequestMapping("/api/pay")
public class ApiPayNotifyController
{
    private static final Logger log = LoggerFactory.getLogger(ApiPayNotifyController.class);

    @Autowired
    private WxPayService wxPayService;

    @Autowired
    private ApiOrderServiceImpl apiOrderService;

    @Autowired
    private IOrderService orderService;

    @Autowired
    private IPayBillService payBillService;

    @Autowired
    private IMemberVoucherService memberVoucherService;

    /**
     * 多商户版支付结果通知：
     * - URL 形如 /api/pay/notify/{merchantId} 时直接按该 merchantId 解密（推荐）
     * - 旧版 /api/pay/notify 入站时根据 out_trade_no 查订单/买单得到 merchantId 再解密
     */
    @PostMapping("/notify/{merchantId}")
    public org.springframework.http.ResponseEntity<JSONObject> notifyWithMerchant(
            @org.springframework.web.bind.annotation.PathVariable Long merchantId, HttpServletRequest request)
    {
        return doNotify(request, merchantId);
    }

    /**
     * 旧版单一回调入口：按 out_trade_no 反查所属商户再解密
     */
    @PostMapping("/notify")
    public org.springframework.http.ResponseEntity<JSONObject> notify(HttpServletRequest request)
    {
        return doNotify(request, null);
    }

    /**
     * 回调处理。
     *
     * <p><b>@Transactional 被刻意去掉了</b>：原先整个 doNotify 是一个事务，
     * 里面任何一步抛异常（最典型的是扣库存时撞上 assertStoresBelongToMerchant 的
     * 门店归属校验）都会把已经改好的订单状态一起回滚，而 catch 又照样返回
     * HTTP 200 + code=SUCCESS —— 微信认为通知成功不再重试，这笔已付款的订单
     * 就永远停在待支付，5 分钟后被超时任务取消。事务边界现在收在
     * {@code paySuccess} / {@code handleBill} 内部，一笔失败不影响已完成的部分，
     * 且失败时返回 500 让微信按 15s/15s/30s… 的节奏重试。</p>
     */
    private org.springframework.http.ResponseEntity<JSONObject> doNotify(HttpServletRequest request, Long merchantIdHint)
    {
        JSONObject result = new JSONObject();
        try
        {
            String rawBody = readBody(request);
            JSONObject notifyJson = JSONObject.parseObject(rawBody);
            JSONObject resource = notifyJson == null ? null : notifyJson.getJSONObject("resource");
            if (resource == null)
            {
                // 报文本身不合法，重试也不会变好，返回 200 让微信别再发
                result.put("code", "FAIL");
                result.put("message", "缺少resource");
                return org.springframework.http.ResponseEntity.ok(result);
            }
            String plain;
            if (merchantIdHint != null)
            {
                plain = wxPayService.decryptNotifyByMerchant(
                        merchantIdHint,
                        resource.getString("associated_data"),
                        resource.getString("nonce"),
                        resource.getString("ciphertext"));
            }
            else
            {
                // 旧版入口：先按 out_trade_no 反查所属商户再解密
                String tmpOutTradeNo = notifyJson.getString("out_trade_no");
                Long tmpMerchantId = resolveMerchantIdByOutTradeNo(tmpOutTradeNo);
                plain = wxPayService.decryptNotifyByMerchant(
                        tmpMerchantId,
                        resource.getString("associated_data"),
                        resource.getString("nonce"),
                        resource.getString("ciphertext"));
            }
            JSONObject data = JSONObject.parseObject(plain);

            String tradeState = data.getString("trade_state");
            String outTradeNo = data.getString("out_trade_no");
            String transactionId = data.getString("transaction_id");

            if (!"SUCCESS".equals(tradeState))
            {
                log.warn("[WxPayNotify] 非成功状态：{} {}", outTradeNo, tradeState);
                result.put("code", "SUCCESS");
                return org.springframework.http.ResponseEntity.ok(result);
            }

            log.info("[WxPayNotify] 收到支付成功通知 outTradeNo={} transactionId={}", outTradeNo, transactionId);
            if (outTradeNo != null && outTradeNo.startsWith("P"))
            {
                handleBill(outTradeNo, transactionId);
            }
            else
            {
                handleOrder(outTradeNo, transactionId);
            }

            result.put("code", "SUCCESS");
            return org.springframework.http.ResponseEntity.ok(result);
        }
        catch (Exception e)
        {
            // 关键：必须返回非 2xx，微信才会重试。
            // 原来这里返回 200 + code=FAIL，微信只看 HTTP 状态码，
            // 收到 200 就认为通知已送达，永不重试 —— 钱收了单没了，且无从补偿。
            log.error("[WxPayNotify] 处理失败，返回 500 让微信重试", e);
            result.put("code", "FAIL");
            result.put("message", e.getMessage());
            return org.springframework.http.ResponseEntity
                    .status(org.springframework.http.HttpStatus.INTERNAL_SERVER_ERROR).body(result);
        }
    }

    /**
     * 按 out_trade_no 反查所属 merchantId：
     * - 订单（biz_order）通过 selectOrderByOrderNo 拿 merchantId
     * - 买单（biz_pay_bill）通过 selectPayBillByBillNo 拿 merchantId
     * - 都拿不到时回退默认商户（兜底，避免重复通知导致漏单）
     */
    private Long resolveMerchantIdByOutTradeNo(String outTradeNo)
    {
        if (outTradeNo == null)
        {
            return 1L;
        }
        if (outTradeNo.startsWith("P"))
        {
            com.ruoyi.biz.domain.PayBill bill = payBillService.selectPayBillByBillNo(outTradeNo);
            if (bill != null && bill.getMerchantId() != null)
            {
                return bill.getMerchantId();
            }
        }
        else
        {
            com.ruoyi.biz.domain.Order order = orderService.selectOrderByOrderNo(outTradeNo);
            if (order != null && order.getMerchantId() != null)
            {
                return order.getMerchantId();
            }
        }
        log.warn("[WxPayNotify] 无法定位 {} 所属商户，回退默认商户=1", outTradeNo);
        return 1L;
    }

    /**
     * 订单入账。
     *
     * <p>查不到订单时必须抛异常而不是静默 return —— 微信通知是可靠的，
     * 「订单不存在」只可能是我们自己查错了（历史上就是租户过滤把
     * merchant_id=1 加到了 where 里，商户 100 的单一律查不到）。
     * 静默返回会让微信停止重试，从此无从补偿。</p>
     */
    private void handleOrder(String orderNo, String transactionId)
    {
        Order order = orderService.selectOrderByOrderNo(orderNo);
        if (order == null)
        {
            throw new ServiceException("支付回调找不到订单：" + orderNo);
        }
        if (!"0".equals(order.getStatus()))
        {
            // 幂等：微信会重复通知，已入账直接当成功
            log.info("[WxPayNotify] 订单 {} 已是 status={}，跳过重复入账", orderNo, order.getStatus());
            return;
        }
        apiOrderService.paySuccess(order.getOrderId(), transactionId);
        log.info("[WxPayNotify] 订单入账成功 orderNo={} transactionId={}", orderNo, transactionId);
    }

    /**
     * 买单入账：置为已完成，落支付时间与微信交易号。
     *
     * <p>原先只改了 status，{@code pay_time / pay_no} 压根没有这两列 ——
     * 后台看一笔已完成的买单，既不知道什么时候付的，也拿不到微信流水号去对账，
     * 更没法发起退款。本轮建表补上（{@code sql/upgrade/biz_pay_bill_paid_20260904.sql}）。</p>
     */
    @Transactional
    public void handleBill(String billNo, String transactionId)
    {
        PayBill bill = payBillService.selectPayBillByBillNo(billNo);
        if (bill == null)
        {
            throw new ServiceException("支付回调找不到买单：" + billNo);
        }
        if (!"1".equals(bill.getStatus()))
        {
            log.info("[WxPayNotify] 买单 {} 已是 status={}，跳过重复入账", billNo, bill.getStatus());
            return;
        }
        bill.setStatus("2");
        bill.setPayTime(new Date());
        bill.setPayNo(transactionId);
        payBillService.updatePayBill(bill);
        log.info("[WxPayNotify] 买单入账成功 billNo={} transactionId={}", billNo, transactionId);
        if (bill.getMemberVoucherId() != null)
        {
            MemberVoucher mv = memberVoucherService.selectMemberVoucherById(bill.getMemberVoucherId());
            if (mv != null && "0".equals(mv.getStatus()))
            {
                mv.setStatus("1");
                mv.setUseTime(new Date());
                memberVoucherService.updateMemberVoucher(mv);
            }
        }
    }

    private String readBody(HttpServletRequest request) throws Exception
    {
        StringBuilder sb = new StringBuilder();
        try (BufferedReader reader = request.getReader())
        {
            String line;
            while ((line = reader.readLine()) != null)
            {
                sb.append(line);
            }
        }
        return sb.toString();
    }
}
