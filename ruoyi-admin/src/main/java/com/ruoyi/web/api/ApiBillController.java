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
import com.ruoyi.biz.api.annotation.RequireRole;
import com.ruoyi.biz.api.role.BizRole;
import com.ruoyi.biz.api.service.WxPayService;
import com.ruoyi.biz.api.util.MemberContextHolder;
import com.ruoyi.biz.domain.Member;
import com.ruoyi.biz.domain.PayBill;
import com.ruoyi.biz.domain.MemberVoucher;
import com.ruoyi.biz.service.IPayBillService;
import com.ruoyi.biz.service.IMemberService;
import com.ruoyi.biz.service.IMemberVoucherService;

/**
 * 小程序-到店买单（会员发起 → 店员确认 → 会员支付）
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
    private IMemberService memberService;

    @Autowired
    private WxPayService wxPayService;

    /**
     * 会员发起买单：填写消费金额，可选代金券
     */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER, BizRole.STAFF}, includeHigher = true)
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
        BigDecimal discount = BigDecimal.ZERO;
        if (memberVoucherId != null)
        {
            MemberVoucher mv = memberVoucherService.selectMemberVoucherById(memberVoucherId);
            if (mv == null || !mv.getMemberId().equals(memberId) || !"0".equals(mv.getStatus()))
            {
                throw new ServiceException("代金券不可用");
            }
            if (mv.getThreshold() != null && amount.compareTo(mv.getThreshold()) < 0)
            {
                throw new ServiceException("未达到代金券使用门槛");
            }
            discount = mv.getFaceValue() == null ? BigDecimal.ZERO : mv.getFaceValue();
            if (discount.compareTo(amount) > 0)
            {
                discount = amount;
            }
        }

        PayBill bill = new PayBill();
        bill.setBillNo("P" + System.currentTimeMillis() + (int) (Math.random() * 900 + 100));
        bill.setStoreId(storeId);
        bill.setMemberId(memberId);
        bill.setAmount(amount);
        bill.setMemberVoucherId(memberVoucherId);
        bill.setDiscountAmount(discount);
        bill.setPayAmount(amount.subtract(discount));
        bill.setStatus("0");
        bill.setCreateTime(new Date());
        // 支付 mock 模式：跳过店员确认环节，create 后直接置为已确认，
        // 前端轮询一次 status=1 即触发 prepay/pay，适合自助买单场景。
        // 生产环境 wx.pay.mockEnabled=false 时仍走老流程（status=0 待确认）。
        if (wxPayService.isMock())
        {
            bill.setStatus("1");
        }
        payBillService.insertPayBill(bill);
        return AjaxResult.success(bill);
    }

    /**
     * 查询买单状态（会员轮询店员是否已确认）
     */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER, BizRole.STAFF}, includeHigher = true)
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
        if (loginMember == null || !"store".equals(loginMember.getUserType())
                || !loginMember.getStoreId().equals(bill.getStoreId()))
        {
            throw new ServiceException("仅买单所属门店的员工可确认");
        }
        bill.setStatus("1");
        bill.setConfirmUser("store:" + loginMember.getMemberId());
        bill.setConfirmTime(new Date());
        payBillService.updatePayBill(bill);
        return AjaxResult.success(bill);
    }

    /**
     * 发起买单支付：返回小程序 wx.requestPayment 参数。
     * mock模式直接置为已支付并返回 mock=true。
     */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER, BizRole.STAFF}, includeHigher = true)
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
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER, BizRole.STAFF}, includeHigher = true)
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
