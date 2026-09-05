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
import com.ruoyi.biz.mapper.OrderMapper;
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
    private VoucherUsageService voucherUsageService;

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

    // 取消用券要把 member_voucher_id 置 NULL，而 updateOrder 的动态 SQL
    // 对 null 一律跳过，只能走一条显式的 clearVoucher
    @Autowired
    private OrderMapper orderMapper;

    @Autowired
    private com.ruoyi.biz.mapper.ProductMapper productMapper;

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

        // 代金券抵扣：校验与试算收口到 VoucherUsageService，与买单页共用同一套规则
        // （原先这里和 ApiBillController 各写一段，都漏了过期与门店限制两条判断）
        discount = voucherUsageService.validateAndDiscount(
                memberVoucherId, memberId, totalAmount, product.getStoreId());
        BigDecimal payAmount = totalAmount.subtract(discount);

        Order order = new Order();
        order.setOrderNo(genNo("D"));
        order.setStoreId(product.getStoreId());
        order.setMemberId(memberId);
        order.setProductId(productId);
        order.setProductName(product.getProductName());
        // 只快照头图首张：cover 是逗号串（PC 建品页可传 5 张），
        // 而 biz_order.product_cover 只有 varchar(255) —— 整串存进去不仅让订单列表
        // 的 <image src> 变白图，超长时还会被截成半个 URL 永久写进历史订单。
        order.setProductCover(com.ruoyi.common.utils.image.ImageUrlUtils.firstImage(product.getCover()));
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
        // V2.6 P1：下单时生成 12 位核销码（UUID 截取，扫码核销唯一标识）
        order.setVerifyCode(genVerifyCode());
        order.setCreateTime(new Date());
        orderService.insertOrder(order);
        return order;
    }

    /**
     * 待支付订单换券（选券 / 换一张 / 取消用券）。
     *
     * <p>为什么需要这个：券入口原先只在下单页（提交订单之前）有。一旦订单建出来
     * 进了待支付，用户想再用券就只剩「放弃这单重新下」一条路 —— 而重新下单又会
     * 被那笔待付单占着限购额度。到店自取这类先下单后到店付的场景尤其明显。</p>
     *
     * <p><b>必须重新生成 order_no</b>：order_no 就是微信支付的 out_trade_no，
     * 而 JSAPI 下单后金额已锁在微信侧那笔预支付单上。沿用旧单号再改金额，
     * 微信会以首次下单的金额为准（或直接报单号重复），出现「页面显示实付 180、
     * 实际扣 200」的资损。换号等于作废旧预支付单，重新走一次统一下单。</p>
     *
     * @param memberId        当前登录会员（用于归属校验）
     * @param orderId         订单主键
     * @param memberVoucherId 要用的券；传 null 表示取消用券
     * @return 改券后的订单
     */
    @Transactional
    public Order changeVoucher(Long memberId, Long orderId, Long memberVoucherId)
    {
        Order order = orderService.selectOrderByOrderId(orderId);
        if (order == null)
        {
            throw new ServiceException("订单不存在");
        }
        if (!order.getMemberId().equals(memberId))
        {
            throw new ServiceException("无权修改他人订单");
        }
        if (!"0".equals(order.getStatus()))
        {
            throw new ServiceException("仅待支付订单可以修改代金券");
        }

        BigDecimal totalAmount = order.getTotalAmount() == null ? BigDecimal.ZERO : order.getTotalAmount();
        // 排除自身：换成原本已选中的那张券时，不能被自己占用的记录挡住
        BigDecimal discount = voucherUsageService.validateAndDiscount(
                memberVoucherId, memberId, totalAmount, order.getStoreId(), orderId, null);

        Order patch = new Order();
        patch.setOrderId(orderId);
        patch.setDiscountAmount(discount);
        patch.setPayAmount(totalAmount.subtract(discount));
        patch.setOrderNo(genNo("D"));
        // 取消用券要把字段真置回 NULL。updateOrder 的 <if test="memberVoucherId != null">
        // 会把 null 直接跳过，所以这条单独走一个显式 update。
        if (memberVoucherId == null)
        {
            orderService.updateOrder(patch);
            orderMapper.clearVoucher(orderId);
        }
        else
        {
            patch.setMemberVoucherId(memberVoucherId);
            orderService.updateOrder(patch);
        }
        return orderService.selectOrderByOrderId(orderId);
    }

    /**
     * 取消待支付订单
     *
     * <p>为什么必须有这个能力：{@code VoucherUsageService.assertNotHeld} 判定
     * 一张券是否被占用，看的是 {@code biz_order.status in ('0','1','2')} —— 待支付
     * 也算占用（这是对的，否则同一张券能在 N 个待付单里各抵一次）。但小程序端
     * 压根没有取消订单的入口，于是用户一旦下了个待付单又不付，那张券就被永久
     * 锁死，之后每次用券都弹「该代金券已用于另一笔待支付订单，请先完成或取消
     * 那笔订单」——而「取消那笔」这个动作在产品里根本不存在，属于死锁。</p>
     *
     * <p>状态置 '3'（已取消，与 order/list 的 tab 映射一致）并清掉
     * member_voucher_id：清字段是关键，只改 status 的话 assertNotHeld 的
     * status 条件虽然不再命中，但库里仍留着一条指向该券的脏引用，
     * 日后若有人放宽那个 status 集合就会再次踩雷。</p>
     *
     * <p>只允许取消 status='0'：已支付（'1'）要走退款流程，不能简单置取消，
     * 否则用户付了钱订单却变成已取消，钱和货都没了。</p>
     */
    @Transactional
    public Order cancel(Long memberId, Long orderId)
    {
        Order order = orderService.selectOrderByOrderId(orderId);
        if (order == null)
        {
            throw new ServiceException("订单不存在");
        }
        if (order.getMemberId() == null || !order.getMemberId().equals(memberId))
        {
            throw new ServiceException("无权取消他人订单");
        }
        if ("3".equals(order.getStatus()))
        {
            // 幂等：重复点「取消」不该报错（弱网下用户会连点）
            return order;
        }
        if (!"0".equals(order.getStatus()))
        {
            throw new ServiceException("仅待支付订单可以取消");
        }

        Order patch = new Order();
        patch.setOrderId(orderId);
        patch.setStatus("3");
        orderService.updateOrder(patch);
        // 释放券占用：updateOrder 的 <if test="memberVoucherId != null"> 会跳过 null，
        // 所以置空必须走这条显式 update（changeVoucher 里同样的处理）
        orderMapper.clearVoucher(orderId);
        log.info("[order] cancel orderId={} memberId={} 释放券占用", orderId, memberId);
        return orderService.selectOrderByOrderId(orderId);
    }

    /**
     * 支付成功入账（微信回调 / mock 支付共用）：置为待使用，生成核销码、
     * 计算有效期，核销代金券，扣库存加销量，触发佣金。
     */
    @Transactional
    public Order paySuccess(Long orderId)
    {
        return paySuccess(orderId, null);
    }

    /**
     * 支付成功入账，并落微信侧真实交易号。
     *
     * @param transactionId 微信支付订单号（回调 {@code transaction_id}）；
     *                      为 null 时按 mock 生成本地流水号
     */
    @Transactional
    public Order paySuccess(Long orderId, String transactionId)
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
        // 真实回调带 transaction_id 时必须落它：对账、查单、发起退款都要靠这个号，
        // 之前一律写 "MOCKPAY<时间戳>"，线上收到的钱在系统里找不到对应的微信流水。
        order.setPayNo(StringUtils.isNotEmpty(transactionId)
                ? transactionId : ("MOCKPAY" + System.currentTimeMillis()));
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

        // 扣减库存、增加销量：走 mapper 的原子 update，不能走 productService.updateProduct。
        //
        // updateProduct 里第一行是 assertStoresBelongToMerchant —— 商品 store_ids 里
        // 只要有一个门店的 merchant_id 与商品对不上（线上存量脏数据就有），
        // 这里会抛「门店不属于该商家」，把整个支付回调事务连订单状态一起回滚：
        // 用户付了钱，订单还停在待支付，5 分钟后被超时任务取消。扣库存不该关心门店归属。
        //
        // 另外原来是「读出来减一再写回」，并发下单会互相覆盖导致超卖；
        // 且 updateProduct 会顺带 saveExt，用一个只有 stock/sales 的实体覆盖商品扩展字段。
        if (product != null && order.getNum() != null)
        {
            int affected = productMapper.deductStockAndAddSales(product.getProductId(), order.getNum());
            if (affected == 0)
            {
                // 钱已经收了，不能因为库存不足回滚订单，只告警等人工处理（超卖/补货）
                log.warn("[order] paySuccess 扣库存影响 0 行，可能库存不足 orderId={} productId={} num={}",
                        orderId, product.getProductId(), order.getNum());
            }
        }

        // 触发分销佣金
        commissionService.settleForOrder(order);
        return order;
    }

    /**
     * 不可核销时的具体原因（拼在「订单状态」之后）。
     *
     * <p>店员看到的完整文案例如「订单状态已核销过了，无需重复核销」。
     * 未知状态兜底成中性描述，不暴露内部状态码。</p>
     */
    private String verifyRejectReason(String status)
    {
        if ("0".equals(status)) return "还是待付款，请让客人先完成支付";
        if ("2".equals(status)) return "已核销过了，无需重复核销";
        if ("3".equals(status)) return "是已退款，不能核销";
        if ("4".equals(status)) return "是已取消，不能核销";
        return "不可核销";
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
            // 按状态给出具体原因。原来一律返「订单状态不可核销」，店员完全无法处置：
            // 两个店员同时盯着今日订单列表，一个刚核完，另一个点下去只看到这句话 ——
            // 不知道是已经核过了（那就放客人走）、还是客人压根没付款（要让客人先付）、
            // 还是已退款（要拒绝入场）。这三种情况店员的下一步动作完全不同。
            // 「订单状态」四个字保留在文案里（smoke-c36 幂等用例按它断言）。
            throw new ServiceException("订单状态" + verifyRejectReason(order.getStatus()));
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
