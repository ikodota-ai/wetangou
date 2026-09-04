package com.ruoyi.biz.service.impl;

import java.util.List;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.DateUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.biz.mapper.OrderMapper;
import com.ruoyi.biz.domain.Order;
import com.ruoyi.biz.service.IOrderService;

/**
 * 订单Service业务层处理
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@Service
public class OrderServiceImpl implements IOrderService 
{
    private static final Logger log = LoggerFactory.getLogger(OrderServiceImpl.class);

    @Autowired
    private OrderMapper orderMapper;

    /**
     * 查询订单
     * 
     * @param orderId 订单主键
     * @return 订单
     */
    @Override
    public Order selectOrderByOrderId(Long orderId)
    {
        return orderMapper.selectOrderByOrderId(orderId);
    }

    @Override
    public Order selectOrderByOrderNo(String orderNo)
    {
        return orderMapper.selectOrderByOrderNo(orderNo);
    }

    /**
     * 查询订单列表
     * 
     * @param order 订单
     * @return 订单
     */
    @Override
    public List<Order> selectOrderList(Order order)
    {
        return orderMapper.selectOrderList(order);
    }

    @Override
    public List<Order> selectVerifiedOrderList(Order order)
    {
        return orderMapper.selectVerifiedOrderList(order);
    }

    /**
     * 新增订单
     * 
     * @param order 订单
     * @return 结果
     */
    @Override
    public int insertOrder(Order order)
    {
        order.setCreateTime(DateUtils.getNowDate());
        return orderMapper.insertOrder(order);
    }

    /**
     * 修改订单
     * 
     * @param order 订单
     * @return 结果
     */
    @Override
    public int updateOrder(Order order)
    {
        order.setUpdateTime(DateUtils.getNowDate());
        return orderMapper.updateOrder(order);
    }

    /**
     * 批量删除订单
     * 
     * @param orderIds 需要删除的订单主键
     * @return 结果
     */
    @Override
    public int deleteOrderByOrderIds(Long[] orderIds)
    {
        assertDeletable(orderIds);
        return orderMapper.deleteOrderByOrderIds(orderIds);
    }

    /**
     * 删除订单信息
     * 
     * @param orderId 订单主键
     * @return 结果
     */
    @Override
    public int deleteOrderByOrderId(Long orderId)
    {
        assertDeletable(new Long[] { orderId });
        return orderMapper.deleteOrderByOrderId(orderId);
    }

    /**
     * 取消超时未支付订单。与 {@code ApiOrderServiceImpl.cancel} 同一套动作
     * （status 置 '3' + clearVoucher），差别只在这里没有 memberId 归属校验
     * —— 定时任务不代表任何会员。
     */
    @Override
    @Transactional(rollbackFor = Exception.class)
    public int cancelTimeoutUnpaid(int minutes)
    {
        List<Long> ids = orderMapper.selectTimeoutUnpaidIds(minutes);
        int cancelled = 0;
        for (Long orderId : ids)
        {
            Order patch = new Order();
            patch.setOrderId(orderId);
            patch.setStatus("3");
            patch.setUpdateTime(DateUtils.getNowDate());
            orderMapper.updateOrder(patch);
            // updateOrder 的 <if test="memberVoucherId != null"> 会跳过 null，
            // 置空必须走这条显式 update（与手动取消一致）
            orderMapper.clearVoucher(orderId);
            cancelled++;
        }
        if (cancelled > 0)
        {
            log.info("[order] 超时自动取消 count={} minutes={} ids={}", cancelled, minutes,
                    ids.size() > 20 ? ids.subList(0, 20) + "...(共" + ids.size() + ")" : ids);
        }
        return cancelled;
    }

    /**
     * 交易单据不允许物理删除。
     *
     * <p>后台订单列表原先挂着一个「删除」按钮，直连
     * {@code delete from biz_order}，谁有 biz:order:remove 权限就能把
     * <b>已付款、已核销</b>的订单整行抹掉。后果不是「列表少一行」：</p>
     * <ul>
     *   <li>钱还在微信账上，系统里却查不到这笔交易，对账直接对不平；</li>
     *   <li>用户手里的核销码失效，客服无据可查；</li>
     *   <li>已入账的分销佣金（biz_commission.order_id）成为孤儿，
     *       结算任务照样把钱结给推客；</li>
     *   <li>删除是物理的，没有 del_flag，删完无法恢复。</li>
     * </ul>
     *
     * <p>因此只放开「从未产生资金往来」的单据：待支付(0) 与已取消(3)。
     * 已支付(1)/已核销(2)/已退款(4) 一律拒绝，要清理请走取消/退款流程。</p>
     *
     * <p>放在 service 而不是 controller：删除入口有后台批量删和单条删两处，
     * 将来若再加导入清理脚本也会走这里，一处覆盖不会漏。</p>
     */
    private void assertDeletable(Long[] orderIds)
    {
        if (orderIds == null || orderIds.length == 0)
        {
            return;
        }
        for (Long orderId : orderIds)
        {
            if (orderId == null)
            {
                continue;
            }
            Order order = orderMapper.selectOrderByOrderId(orderId);
            if (order == null)
            {
                continue;
            }
            String status = order.getStatus();
            if ("0".equals(status) || "3".equals(status))
            {
                continue;
            }
            throw new ServiceException("订单「" + order.getOrderNo() + "」" + statusText(status)
                    + "，涉及真实资金往来，不允许删除；如需处理请走退款或取消流程");
        }
    }

    /** 状态码转中文，用于报错文案（后台看到「状态2」根本不知道是什么） */
    private String statusText(String status)
    {
        if ("1".equals(status)) return "已支付待使用";
        if ("2".equals(status)) return "已核销";
        if ("4".equals(status)) return "已退款";
        return "状态为 " + status;
    }
}
