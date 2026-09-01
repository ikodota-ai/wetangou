package com.ruoyi.web.api;

import java.math.BigDecimal;
import java.util.Date;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.alibaba.fastjson2.JSONObject;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.biz.api.annotation.StoreStaffRequired;
import com.ruoyi.biz.api.domain.LoginMember;
import com.ruoyi.biz.api.annotation.LoginRequired;
import com.ruoyi.biz.api.service.WxPayService;
import com.ruoyi.biz.api.util.MemberContextHolder;
import com.ruoyi.biz.domain.Member;
import com.ruoyi.biz.domain.PayBill;
import com.ruoyi.biz.domain.MemberVoucher;
import com.ruoyi.biz.domain.Store;
import com.ruoyi.biz.service.IPayBillService;
import com.ruoyi.biz.service.IMemberService;
import com.ruoyi.biz.service.IMemberVoucherService;
import com.ruoyi.biz.service.IStoreService;

/**
 * 小程序-到店买单
 *
 * <p>默认链路是「会员在店员面前输入金额 → 直接支付」：买单的真实场景是
 * 顾客当面结账，店员看着屏幕上的金额，不需要再回后台点一次确认。
 * 所以门店的 {@code bill_auto_confirm} 默认为 '1'，create() 直接落
 * status='1'（待支付）。</p>
 *
 * <p>个别需要人工核对金额的门店可以把该开关置 '0'，退回
 * 「会员发起 → 店员 confirm → 会员支付」的三段式。注意：目前商家端
 * 并没有可用的确认入口（confirm 端点要求 userType=='store'，而商家端
 * 签发的是 merchant/owner/manager/staff），关掉开关等于让顾客付不了钱。</p>
 *
 * @author dytuangou
 */
@Anonymous
@RestController
@RequestMapping("/api/bill")
public class ApiBillController
{
    @Autowired
    private IPayBillService payBillService;

    @Autowired
    private IMemberVoucherService memberVoucherService;

    @Autowired
    private com.ruoyi.biz.api.service.VoucherUsageService voucherUsageService;

    @Autowired
    private IMemberService memberService;

    @Autowired
    private WxPayService wxPayService;

    @Autowired
    private IStoreService storeService;

    /**
     * 会员发起买单：填写消费金额，可选代金券
     */
    @LoginRequired
    @PostMapping
    @Transactional
    public AjaxResult create(@RequestBody JSONObject body)
    {
        Long memberId = MemberContextHolder.getMemberId();
        Long storeId = body.getLong("storeId");
        BigDecimal amount = body.getBigDecimal("amount");
        if (storeId == null || amount == null || amount.compareTo(BigDecimal.ZERO) <= 0)
        {
            throw new ServiceException("门店与消费金额必填");
        }
        Long memberVoucherId = body.getLong("memberVoucherId");
        // 校验与试算收口到 VoucherUsageService，与商品下单共用同一套规则。
        // 买单能明确拿到 storeId，门店限制在这条路上尤其重要：
        // 否则 A 店发的券可以用来付 B 店的账。
        BigDecimal discount = voucherUsageService.validateAndDiscount(
                memberVoucherId, memberId, amount, storeId);

        PayBill bill = new PayBill();
        bill.setBillNo("P" + System.currentTimeMillis() + (int) (Math.random() * 900 + 100));
        bill.setStoreId(storeId);
        bill.setMemberId(memberId);
        bill.setAmount(amount);
        bill.setMemberVoucherId(memberVoucherId);
        bill.setDiscountAmount(discount);
        bill.setPayAmount(amount.subtract(discount));
        bill.setCreateTime(new Date());
        // 「要不要店员确认」由门店的 bill_auto_confirm 决定，不再挂在支付 mock 开关上。
        //
        // 原先是 if (wxPayService.isMock()) status='1'，而 WxPayConfig.isMockEnabled()
        // 在 prod profile 下硬编码返回 false —— 于是本地（mockEnabled=true）建单即可付、
        // 生产必须等确认，同一份代码两种行为，看着像「功能被改回去了」。
        // 支付是否 mock 与业务上要不要人工核对金额本来就是两件无关的事。
        if (isAutoConfirm(storeId))
        {
            bill.setStatus("1");
            bill.setConfirmUser("auto");
            bill.setConfirmTime(new Date());
        }
        else
        {
            bill.setStatus("0");
        }
        payBillService.insertPayBill(bill);
        return AjaxResult.success(bill);
    }

    /**
     * 门店是否开启买单自动确认。
     *
     * <p>缺省语义是「开启」：门店查不到、或 bill_auto_confirm 为 null/空
     * （加列前的存量数据）都按自动确认处理。理由是关掉它会让顾客卡在
     * 「等门店确认」而没有任何一端能完成确认，宁可少一道人工核对，
     * 也不能让付款链路断掉。</p>
     */
    private boolean isAutoConfirm(Long storeId)
    {
        Store store = storeService.selectStoreByStoreId(storeId);
        if (store == null)
        {
            return true;
        }
        return !"0".equals(store.getBillAutoConfirm());
    }

    /**
     * 查询买单状态（自动确认门店建单即 status=1；需确认门店由会员轮询店员是否已确认）
     */
    @LoginRequired
    @GetMapping("/{billId}")
    public AjaxResult detail(@PathVariable Long billId)
    {
        com.ruoyi.biz.domain.PayBill bill = payBillService.selectPayBillByBillId(billId);
        if (bill == null)
        {
            throw new ServiceException("账单不存在");
        }
        // 账单可由 memberId 关联到下单人, 防止会员越权查看他人账单
        Long memberId = MemberContextHolder.getMemberId();
        if (bill.getMemberId() != null && !bill.getMemberId().equals(memberId))
        {
            throw new ServiceException("无权查看他人账单");
        }
        return AjaxResult.success(bill);
    }

    /**
     * 店员确认买单金额（仅门店端员工可操作）
     */
    @LoginRequired
    @StoreStaffRequired
    @PostMapping("/confirm/{billId}")
    @Transactional
    public AjaxResult confirm(@PathVariable Long billId)
    {
        PayBill bill = payBillService.selectPayBillByBillId(billId);
        if (bill == null || !"0".equals(bill.getStatus()))
        {
            throw new ServiceException("买单不存在或状态不允许确认");
        }
        // 二次校验：确认人必须是买单所属门店的员工
        LoginMember loginMember = MemberContextHolder.get();
        // 同 verify：认全部员工链路（owner/manager/staff/store），且按授权门店集合比对
        if (loginMember == null || !loginMember.isStaffSession()
                || !loginMember.hasStore(bill.getStoreId()))
        {
            throw new ServiceException("仅买单所属门店的员工可确认");
        }
        bill.setStatus("1");
        bill.setConfirmUser("store:" + (loginMember.getStaffUserId() != null
                ? loginMember.getStaffUserId() : loginMember.getMemberId()));
        bill.setConfirmTime(new Date());
        payBillService.updatePayBill(bill);
        return AjaxResult.success(bill);
    }

    /**
     * 发起买单支付：返回小程序 wx.requestPayment 参数。
     * mock模式直接置为已支付并返回 mock=true。
     */
    @LoginRequired
    @PostMapping("/prepay/{billId}")
    @Transactional
    public AjaxResult prepay(@PathVariable Long billId)
    {
        PayBill bill = payBillService.selectPayBillByBillId(billId);
        if (bill == null || !"1".equals(bill.getStatus()))
        {
            throw new ServiceException("买单未确认或状态异常");
        }
        if (!bill.getMemberId().equals(MemberContextHolder.getMemberId()))
        {
            throw new ServiceException("无权支付该买单");
        }
        java.util.Map<String, Object> resp = new java.util.LinkedHashMap<>();
        resp.put("orderNo", bill.getBillNo());
        resp.put("amount", bill.getPayAmount());
        resp.put("expireTime", System.currentTimeMillis() + 2 * 60 * 60 * 1000L);
        if (wxPayService.isMock())
        {
            markPaid(bill);
            String payNo = "MOCK" + System.currentTimeMillis() + (int) (Math.random() * 9000 + 1000);
            resp.put("mock", true);
            resp.put("payNo", payNo);
            resp.put("payInfoId", bill.getBillId());
            return AjaxResult.success(resp);
        }
        Member member = memberService.selectMemberByMemberId(MemberContextHolder.getMemberId());
        String openid = member == null ? null : member.getOpenid();
        int fen = WxPayService.yuanToFen(bill.getPayAmount());
        JSONObject payParams = wxPayService.createJsapiOrderByMerchant(bill.getMerchantId(), bill.getBillNo(), "买单-" + bill.getBillNo(), fen, openid);
        resp.put("payNo", payParams.getString("transaction_id"));
        resp.put("payInfoId", payParams.getString("prepay_id"));
        resp.putAll(payParams);
        return AjaxResult.success(resp);
    }

    /**
     * 会员支付（仅mock模式；真实环境由微信支付回调触发），使用代金券
     */
    @LoginRequired
    @PostMapping("/pay/{billId}")
    @Transactional
    public AjaxResult pay(@PathVariable Long billId)
    {
        PayBill bill = payBillService.selectPayBillByBillId(billId);
        if (bill == null || !"1".equals(bill.getStatus()))
        {
            throw new ServiceException("买单未确认或状态异常");
        }
        if (!bill.getMemberId().equals(MemberContextHolder.getMemberId()))
        {
            throw new ServiceException("无权支付该买单");
        }
        if (!wxPayService.isMock())
        {
            throw new ServiceException("请通过微信支付完成付款");
        }
        markPaid(bill);
        return AjaxResult.success(bill);
    }

    /**
     * 标记买单已支付并核销代金券（供mock支付/回调复用）
     */
    private void markPaid(PayBill bill)
    {
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
}
