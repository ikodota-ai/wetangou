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
     * 微信支付结果通知：解密后按 out_trade_no 前缀分发到订单/买单。
     * 订单编号以 D 开头，买单编号以 P 开头。
     */
    @PostMapping("/notify")
    @Transactional
    public JSONObject notify(HttpServletRequest request)
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
            String plain = wxPayService.decryptNotify(
                    resource.getString("associated_data"),
                    resource.getString("nonce"),
                    resource.getString("ciphertext"));
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
