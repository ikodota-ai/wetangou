package com.ruoyi.biz.api.service;

import java.math.BigDecimal;
import java.util.Date;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.ruoyi.biz.domain.MemberVoucher;
import com.ruoyi.biz.domain.Voucher;
import com.ruoyi.biz.mapper.OrderMapper;
import com.ruoyi.biz.mapper.PayBillMapper;
import com.ruoyi.biz.service.IMemberVoucherService;
import com.ruoyi.biz.service.IVoucherService;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;

/**
 * 代金券可用性校验 + 抵扣试算（下单 / 买单共用）
 *
 * <p>为什么要单独抽一个类：代金券的抵扣入口有两个 —— 商品下单
 * {@link ApiOrderServiceImpl#placeOrder} 和到店买单 {@code ApiBillController.create}，
 * 两边原本各写了一段几乎一样的校验（判归属、判 status、判门槛、封顶），
 * 于是同一个漏判要修两次，实际结果是只修一处、另一处继续放行。
 * 收口到这里之后，加一条规则两个入口同时生效。</p>
 *
 * <p>本类补齐了原先两处都缺的三条校验，都是实测能复现的真实问题：</p>
 * <ol>
 *   <li><b>过期券仍能抵扣</b>：原判断只看 {@code status='0'}，而 status 要靠定时任务刷新，
 *       系统里那个任务压根没建（sys_job 只有 4 条，无一是券过期）。
 *       于是 expire_time 已经是 5 天前的券 status 永远停在 '0' ——
 *       实测拿这种券下单，¥200 的单直接抵掉 ¥20 并成功落库。
 *       现在以 expire_time 为准，不依赖任务是否跑过。</li>
 *   <li><b>券能跨门店抵扣</b>：biz_voucher.store_id 限定了券属于哪个门店，
 *       但下单和买单都没校验过它。实测领门店 201 的「满 150 减 30」券，
 *       去买门店 200 的 ¥200 商品，照样抵扣成功 —— 等于 A 店发的券让 B 店买单，
 *       B 店的营业额被凭空扣掉一笔。现在按券模板的 store_id 校验。</li>
 *   <li><b>未到生效期的券能用</b>：valid_from 同样从来没被读过。</li>
 * </ol>
 *
 * <p>store_id=0 视为全门店通用（历史数据里 voucher_id=100 就是 0），
 * 券模板已被删除时按「不限门店」放行，不因为运营删了模板就把用户手里的券作废。</p>
 */
@Service
public class VoucherUsageService
{
    /** 券模板 store_id 为该值时表示全门店通用 */
    private static final long STORE_ANY = 0L;

    @Autowired
    private IMemberVoucherService memberVoucherService;

    @Autowired
    private IVoucherService voucherService;

    // 直接用 mapper 而不是 service：只需要一个 count 查询，
    // 走 selectOrderList 会被租户过滤切面改写 where，会员自己的券反而查不全
    @Autowired
    private OrderMapper orderMapper;

    @Autowired
    private PayBillMapper payBillMapper;

    /**
     * 校验券可用并返回实际抵扣金额。
     *
     * @param memberVoucherId 会员券 id（为 null 时直接返回 0，调用方不必先判空）
     * @param memberId        当前登录会员
     * @param amount          订单/账单总金额（门槛与封顶都以它为准）
     * @param storeId         本次消费的门店；为 null 时跳过门店校验
     * @return 实际抵扣金额，永不为负、永不超过 amount
     */
    public BigDecimal validateAndDiscount(Long memberVoucherId, Long memberId, BigDecimal amount, Long storeId)
    {
        return validateAndDiscount(memberVoucherId, memberId, amount, storeId, null, null);
    }

    /**
     * 同上，但允许把「当前这一单」排除在占用统计之外。
     *
     * <p>待支付订单换券时会用到：换成原本就选中的那张券，不能被自己占用的记录挡住。</p>
     *
     * @param excludeOrderId 排除的订单主键（订单侧换券传自身 id）
     * @param excludeBillId  排除的买单主键（买单侧传自身 id）
     */
    public BigDecimal validateAndDiscount(Long memberVoucherId, Long memberId, BigDecimal amount, Long storeId,
            Long excludeOrderId, Long excludeBillId)
    {
        if (memberVoucherId == null)
        {
            return BigDecimal.ZERO;
        }
        BigDecimal total = amount == null ? BigDecimal.ZERO : amount;

        MemberVoucher mv = memberVoucherService.selectMemberVoucherById(memberVoucherId);
        if (mv == null || mv.getMemberId() == null || !mv.getMemberId().equals(memberId)
                || !"0".equals(mv.getStatus()))
        {
            throw new ServiceException("代金券不可用");
        }
        // 过期以 expire_time 为准：status 靠定时任务刷，而那个任务并不存在
        Date now = new Date();
        if (mv.getExpireTime() != null && mv.getExpireTime().before(now))
        {
            throw new ServiceException("代金券已过期");
        }
        if (mv.getThreshold() != null && total.compareTo(mv.getThreshold()) < 0)
        {
            throw new ServiceException("未达到代金券使用门槛");
        }
        assertStoreMatch(mv, storeId, now);
        assertNotHeld(memberVoucherId, excludeOrderId, excludeBillId);

        BigDecimal discount = mv.getFaceValue() == null ? BigDecimal.ZERO : mv.getFaceValue();
        if (discount.compareTo(total) > 0)
        {
            discount = total;
        }
        if (discount.compareTo(BigDecimal.ZERO) < 0)
        {
            discount = BigDecimal.ZERO;
        }
        return discount;
    }

    /**
     * 占用校验：这张券是否已经挂在别的未失效订单/买单上。
     *
     * <p>为什么不能只看 member_voucher.status：那个字段要等支付成功回调才置 '1'，
     * 待支付阶段一直是 '0'。只看 status 的话，用户在下单页反复提交就能让
     * 同一张券在 N 个待付单里各抵一次。</p>
     */
    private void assertNotHeld(Long memberVoucherId, Long excludeOrderId, Long excludeBillId)
    {
        if (orderMapper.countVoucherHeldOrders(memberVoucherId, excludeOrderId) > 0)
        {
            throw new ServiceException("该代金券已用于另一笔待支付订单，请先完成或取消那笔订单");
        }
        if (payBillMapper.countVoucherHeldBills(memberVoucherId, excludeBillId) > 0)
        {
            throw new ServiceException("该代金券已用于另一笔买单，请先完成或取消那笔买单");
        }
    }

    /**
     * 门店与生效期校验：都挂在券模板上，会员券只存了面值/门槛快照。
     * 模板查不到（被运营删了）时不拦，避免用户手里的券无故失效。
     */
    private void assertStoreMatch(MemberVoucher mv, Long storeId, Date now)
    {
        if (mv.getVoucherId() == null || mv.getVoucherId() <= 0)
        {
            return;
        }
        Voucher tpl = voucherService.selectVoucherByVoucherId(mv.getVoucherId());
        if (tpl == null)
        {
            return;
        }
        if (tpl.getValidFrom() != null && tpl.getValidFrom().after(now))
        {
            throw new ServiceException("代金券未到生效时间");
        }
        Long limit = tpl.getStoreId();
        if (storeId == null || limit == null || limit == STORE_ANY)
        {
            return;
        }
        if (!limit.equals(storeId))
        {
            String name = StringUtils.isNotEmpty(tpl.getStoreName()) ? tpl.getStoreName() : ("门店" + limit);
            throw new ServiceException("该代金券仅限「" + name + "」使用");
        }
    }
}
