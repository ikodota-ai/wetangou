package com.ruoyi.biz.service.impl;

import java.util.List;
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
}
