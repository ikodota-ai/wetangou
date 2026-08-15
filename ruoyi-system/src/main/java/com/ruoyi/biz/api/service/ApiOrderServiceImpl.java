package com.ruoyi.biz.api.service;

import java.math.BigDecimal;
import java.util.Calendar;
import java.util.Date;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.common.utils.uuid.IdUtils;
import com.ruoyi.biz.domain.Order;
import com.ruoyi.biz.domain.Product;
import com.ruoyi.biz.domain.MemberVoucher;
import com.ruoyi.biz.service.IOrderService;
import com.ruoyi.biz.service.IProductService;
import com.ruoyi.biz.service.IMemberVoucherService;
import com.ruoyi.biz.service.IMemberService;
import com.ruoyi.biz.service.IDistributorService;
import com.ruoyi.biz.service.IStoredCardService;
import com.ruoyi.biz.domain.StoredCard;
import com.ruoyi.biz.mapper.DistributorMapper;
import com.ruoyi.biz.domain.Member;
import com.ruoyi.biz.domain.Distributor;

/**
 * 小程序-订单业务（下单、核销）
 *
 * @author dytuangou
 */
@Service
public class ApiOrderServiceImpl implements IApiOrderService
{
    private static final Logger log = LoggerFactory.getLogger(ApiOrderServiceImpl.class);
    @Autowired
    private IOrderService orderService;

    @Autowired
    private IProductService productService;

    @Autowired
    private IMemberVoucherService memberVoucherService;

    @Autowired
    private ApiCommissionService commissionService;

    @Autowired
    private IMemberService memberService;

    @Autowired
    private IDistributorService distributorService;

    @Autowired
    private IStoredCardService storedCardService;

    @Autowired
    private DistributorMapper distributorMapper;

    /**
     * 会员下单（到店自取）：生成待付款订单，含核销码占位
     */
    @Transactional
    public Order placeOrder(Long memberId, Long productId, Long num, Long memberVoucherId, Long distributorId)
    {
        Product product = productService.selectProductByProductId(productId);
        if (product == null || !"0".equals(product.getStatus()))
        {
            throw new ServiceException("商品不存在或已下架");
        }
        // 数量校验：必须 >= 1，null 报错（不静默修正），
        // 避免前端传 0/-1 时被默默改成 1 产生反例
        if (num == null || num < 1)
        {
            throw new ServiceException("购买数量必须大于等于 1");
        }
        long quantity = num;
        if (product.getStock() != null && product.getStock() < quantity)
        {
            throw new ServiceException("商品库存不足");
        }

        // === V2.6 P0：商品限制条件校验 ===
        Date now = new Date();
        // 1) 售卖时间段
        if (product.getSaleStartDate() != null && now.before(product.getSaleStartDate()))
        {
            throw new ServiceException("商品尚未开始售卖，开始时间：" +
                new java.text.SimpleDateFormat("yyyy-MM-dd HH:mm").format(product.getSaleStartDate()));
        }
        if (product.getSaleEndDate() != null && now.after(product.getSaleEndDate()))
        {
            throw new ServiceException("商品已过售卖期，结束时间：" +
                new java.text.SimpleDateFormat("yyyy-MM-dd HH:mm").format(product.getSaleEndDate()));
        }
        // 2) 单次购买上限
        if (product.getMaxPerOrder() != null && product.getMaxPerOrder() > 0 && quantity > product.getMaxPerOrder().longValue())
        {
            throw new ServiceException("单次最多购买 " + product.getMaxPerOrder() + " 件");
        }
        // 3) 每人累计限购（查该用户已支付 + 待支付的有效订单数）
        if (product.getLimitPerUser() != null && product.getLimitPerUser() > 0)
        {
            int alreadyBought = countMemberProductBought(memberId, productId);
            if (alreadyBought + quantity > product.getLimitPerUser().longValue())
            {
                int remain = (int) Math.max(0L, product.getLimitPerUser().longValue() - alreadyBought);
                throw new ServiceException("每人限购 " + product.getLimitPerUser() + " 件，您已购买 " + alreadyBought + " 件，剩余可购 " + remain + " 件");
            }
        }
        // 4) 预约类商品必须走预约流程（强提示；此处仅校验商品类型）
        if ("BOOKING".equals(product.getTypeCode()) && product.getBookingRequired() == null)
        {
            product.setBookingRequired(1);
        }
        // === 限制条件校验完成 ===

        BigDecimal price = product.getPrice() == null ? BigDecimal.ZERO : product.getPrice();
        BigDecimal totalAmount = price.multiply(BigDecimal.valueOf(quantity));
        BigDecimal discount = BigDecimal.ZERO;

        // 代金券抵扣
        if (memberVoucherId != null)
        {
            MemberVoucher mv = memberVoucherService.selectMemberVoucherById(memberVoucherId);
            if (mv == null || !mv.getMemberId().equals(memberId) || !"0".equals(mv.getStatus()))
            {
                throw new ServiceException("代金券不可用");
            }
            if (mv.getThreshold() != null && totalAmount.compareTo(mv.getThreshold()) < 0)
            {
                throw new ServiceException("未达到代金券使用门槛");
            }
            discount = mv.getFaceValue() == null ? BigDecimal.ZERO : mv.getFaceValue();
            if (discount.compareTo(totalAmount) > 0)
            {
                discount = totalAmount;
            }
        }
        BigDecimal payAmount = totalAmount.subtract(discount);

        Order order = new Order();
        order.setOrderNo(genNo("D"));
        order.setStoreId(product.getStoreId());
        order.setMemberId(memberId);
        order.setProductId(productId);
        order.setProductName(product.getProductName());
        order.setProductCover(product.getCover());
        order.setOrderType("0");
        order.setPrice(price);
        order.setNum(quantity);
        order.setTotalAmount(totalAmount);
        order.setDiscountAmount(discount);
        order.setPayAmount(payAmount);
        order.setMemberVoucherId(memberVoucherId);
        // 前端传了 distributorId 优先用（推客场景：扫太阳码下单时 URL 带 distributorId）
        if (distributorId != null) {
            order.setDistributorId(distributorId);
        }
        // 如果前端没传 distributorId 但当前会员是被邀请用户，邀请人是推客时自动归属
        if (order.getDistributorId() == null) {
            Member me = memberService.selectMemberByMemberId(memberId);
            if (me != null && me.getInviteBy() != null) {
                // 精准查推客（避免 selectDistributorList 走通用 mapper 出现 "Column merchant_id ambiguous"）
                com.ruoyi.biz.domain.Distributor d = distributorMapper.selectDistributorByMemberId(me.getMerchantId(), me.getInviteBy());
                if (d != null && "0".equals(d.getStatus())) {
                    order.setDistributorId(d.getDistributorId());
                }
            }
        }
        order.setStatus("0");
        order.setCreateTime(new Date());
        orderService.insertOrder(order);
        return order;
    }

    /**
     * 模拟支付成功回调：置为待使用，生成核销码、计算有效期，冻结代金券，触发佣金
     */
    @Transactional
    public Order paySuccess(Long orderId)
    {
        Order order = orderService.selectOrderByOrderId(orderId);
        if (order == null)
        {
            throw new ServiceException("订单不存在");
        }
        if (!"0".equals(order.getStatus()))
        {
            throw new ServiceException("订单状态不允许支付");
        }
        order.setStatus("1");
        order.setPayTime(new Date());
        order.setPayNo("MOCKPAY" + System.currentTimeMillis());
        order.setVerifyCode(genVerifyCode());
        // 核销有效期
        Product product = productService.selectProductByProductId(order.getProductId());
        int days = (product != null && product.getValidityDays() != null) ? product.getValidityDays() : 30;
        Calendar cal = Calendar.getInstance();
        cal.add(Calendar.DAY_OF_MONTH, days);
        order.setExpireTime(cal.getTime());
        orderService.updateOrder(order);

        // 使用代金券
        if (order.getMemberVoucherId() != null)
        {
            MemberVoucher mv = memberVoucherService.selectMemberVoucherById(order.getMemberVoucherId());
            if (mv != null && "0".equals(mv.getStatus()))
            {
                mv.setStatus("1");
                mv.setUseOrderId(order.getOrderId());
                mv.setUseTime(new Date());
                memberVoucherService.updateMemberVoucher(mv);
            }
        }

        // 扣减库存、增加销量
        if (product != null)
        {
            if (product.getStock() != null)
            {
                product.setStock(Math.max(0, product.getStock() - order.getNum()));
            }
            product.setSales((product.getSales() == null ? 0 : product.getSales()) + order.getNum());
            productService.updateProduct(product);
        }

        // 触发分销佣金
        commissionService.settleForOrder(order);
        return order;
    }

    /**
     * 核销订单（门店店员）
     */
    @Transactional
    public Order verify(String verifyCode, Long storeId, String operator)
    {
        if (StringUtils.isEmpty(verifyCode))
        {
            throw new ServiceException("核销码不能为空");
        }
        Order query = new Order();
        query.setVerifyCode(verifyCode);
        List<Order> list = orderService.selectOrderList(query);
        if (list.isEmpty())
        {
            throw new ServiceException("核销码无效");
        }
        Order order = list.get(0);
        if (storeId != null && !storeId.equals(order.getStoreId()))
        {
            throw new ServiceException("该订单不属于当前门店");
        }
        if (!"1".equals(order.getStatus()))
        {
            throw new ServiceException("订单状态不可核销");
        }
        if (order.getExpireTime() != null && order.getExpireTime().before(new Date()))
        {
            throw new ServiceException("订单已过期");
        }
        order.setStatus("2");
        order.setVerifyTime(new Date());
        order.setVerifyUser(operator);
        orderService.updateOrder(order);

        // 储值卡商品：核销后扣减会员卡内余额
        try {
            deductStoredCardIfNeeded(order);
        } catch (Exception e) {
            // 储值卡扣减失败，回滚整笔核销
            log.warn("[核销] 储值卡扣减失败 orderId={} err={}", order.getOrderId(), e.getMessage());
            throw e;
        }
        return order;
    }

    /**
     * 核销后处理：若订单对应商品 type_code=STORED_CARD，
     * 按订单实付金额（或面额）扣减会员储值卡余额，事务内完成。
     *
     * <p>幂等键 bizNo=orderNo:"C"，已扣过直接跳过（防重放）。</p>
     */
    private void deductStoredCardIfNeeded(Order order)
    {
        if (order.getProductId() == null) return;
        Product p = productService.selectProductByProductId(order.getProductId());
        if (p == null) return;
        if (!"STORED_CARD".equals(p.getTypeCode())) return;
        if (order.getMemberId() == null) return;

        // 找会员对应此商品的卡（一会员一卡一面）
        StoredCard card = storedCardService.selectByMemberAndProduct(order.getMemberId(), p.getProductId());
        if (card == null) {
            log.warn("[核销] STORED_CARD 订单 {} 找不到会员 {} 的卡 productId={}",
                order.getOrderId(), order.getMemberId(), p.getProductId());
            return;
        }

        // 扣减金额：优先按 payAmount（实付），否则按面额
        java.math.BigDecimal amount = order.getPayAmount() != null && order.getPayAmount().signum() > 0
            ? order.getPayAmount()
            : (p.getFaceValue() != null ? p.getFaceValue() : BigDecimal.ZERO);
        if (amount == null || amount.signum() <= 0) {
            log.warn("[核销] STORED_CARD 订单 {} 扣减金额为 0，跳过", order.getOrderId());
            return;
        }

        String bizNo = order.getOrderNo() + ":C";
        try {
            storedCardService.consume(card.getCardId(), amount, bizNo,
                order.getOrderId(), "STAFF", order.getVerifyUser());
            log.info("[核销] STORED_CARD 扣减成功 orderId={} cardId={} amount={} bizNo={}",
                order.getOrderId(), card.getCardId(), amount, bizNo);
        } catch (com.ruoyi.common.exception.ServiceException se) {
            // 余额不足：把核销回滚（事务整体回滚，由 @Transactional 保证）
            throw se;
        }
    }

    private String genNo(String prefix)
    {
        return prefix + System.currentTimeMillis() + (int) (Math.random() * 900 + 100);
    }

    private String genVerifyCode()
    {
        return IdUtils.fastSimpleUUID().substring(0, 12).toUpperCase();
    }

    /**
     * 统计某会员对某商品的累计购买数（已支付 + 待支付都算，用于限购校验）
     *  - status IN ('0', '1')：待付款、待使用都计入
     *  - status = '2'（已核销）也计入（不能买了用、用了再买）
     *  - status = '3'（已退款）不计入
     */
    private int countMemberProductBought(Long memberId, Long productId)
    {
        com.ruoyi.biz.domain.Order q = new com.ruoyi.biz.domain.Order();
        q.setMemberId(memberId);
        q.setProductId(productId);
        List<com.ruoyi.biz.domain.Order> list = orderService.selectOrderList(q);
        int total = 0;
        for (com.ruoyi.biz.domain.Order o : list)
        {
            String s = o.getStatus();
            if ("0".equals(s) || "1".equals(s) || "2".equals(s))
            {
                total += (o.getNum() == null ? 0 : o.getNum());
            }
        }
        return total;
    }
}
