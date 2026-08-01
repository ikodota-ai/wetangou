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
import com.ruoyi.biz.api.service.ApiOrderService;
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
    private ApiOrderService apiOrderService;

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
    @Transactional
    public JSONObject notifyWithMerchant(@org.springframework.web.bind.annotation.PathVariable Long merchantId, HttpServletRequest request)
    {
        return doNotify(request, merchantId);
    }

    /**
     * 旧版单一回调入口：按 out_trade_no 反查所属商户再解密
     */
    @PostMapping("/notify")
    @Transactional
    public JSONObject notify(HttpServletRequest request)
    {
        return doNotify(request, null);
    }

    private JSONObject doNotify(HttpServletRequest request, Long merchantIdHint)
    {
        JSONObject result = new JSONObject();
        try
        {
            String rawBody = readBody(request);
            JSONObject notifyJson = JSONObject.parseObject(rawBody);
            JSONObject resource = notifyJson == null ? null : notifyJson.getJSONObject("resource");
            if (resource == null)
            {
                result.put("code", "FAIL");
                result.put("message", "缺少resource");
                return result;
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
                return result;
            }

            if (outTradeNo != null && outTradeNo.startsWith("P"))
            {
                handleBill(outTradeNo);
            }
            else
            {
                handleOrder(outTradeNo, transactionId);
            }

            result.put("code", "SUCCESS");
            return result;
        }
        catch (Exception e)
        {
            log.error("[WxPayNotify] 处理失败", e);
            result.put("code", "FAIL");
            result.put("message", e.getMessage());
            return result;
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

    private void handleOrder(String orderNo, String transactionId)
    {
        Order order = orderService.selectOrderByOrderNo(orderNo);
        if (order == null)
        {
            log.warn("[WxPayNotify] 订单不存在：{}", orderNo);
            return;
        }
        if (!"0".equals(order.getStatus()))
        {
            return;
        }
        apiOrderService.paySuccess(order.getOrderId());
    }

    private void handleBill(String billNo)
    {
        PayBill bill = payBillService.selectPayBillByBillNo(billNo);
        if (bill == null || !"1".equals(bill.getStatus()))
        {
            return;
        }
        bill.setStatus("2");
        payBillService.updatePayBill(bill);
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
