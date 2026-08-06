package com.ruoyi.biz.api.service;

import java.math.BigDecimal;
import java.util.Calendar;
import java.util.Date;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
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
import com.ruoyi.biz.mapper.DistributorMapper;
import com.ruoyi.biz.domain.Member;
import com.ruoyi.biz.domain.Distributor;

/**
 * 小程序-订单业务（下单、核销）
 *
 * @author dytuangou
 */
@Service
public class ApiOrderService
{
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
        return order;
    }

    private String genNo(String prefix)
    {
        return prefix + System.currentTimeMillis() + (int) (Math.random() * 900 + 100);
    }

    private String genVerifyCode()
    {
        return IdUtils.fastSimpleUUID().substring(0, 12).toUpperCase();
    }
}
