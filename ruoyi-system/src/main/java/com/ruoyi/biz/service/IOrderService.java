package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.Order;

/**
 * 订单Service接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface IOrderService 
{
    /**
     * 查询订单
     * 
     * @param orderId 订单主键
     * @return 订单
     */
    public Order selectOrderByOrderId(Long orderId);

    /**
     * 按订单编号查询订单
     *
     * @param orderNo 订单编号
     * @return 订单
     */
    public Order selectOrderByOrderNo(String orderNo);

    /**
     * 查询订单列表
     * 
     * @param order 订单
     * @return 订单集合
     */
    public List<Order> selectOrderList(Order order);

    /**
     * 核销记录查询（按 verify_time 倒序，只含已核销单）。
     * 详见 {@link com.ruoyi.biz.mapper.OrderMapper#selectVerifiedOrderList}。
     */
    public List<Order> selectVerifiedOrderList(Order order);

    /**
     * 新增订单
     * 
     * @param order 订单
     * @return 结果
     */
    public int insertOrder(Order order);

    /**
     * 修改订单
     * 
     * @param order 订单
     * @return 结果
     */
    public int updateOrder(Order order);

    /**
     * 批量删除订单
     * 
     * @param orderIds 需要删除的订单主键集合
     * @return 结果
     */
    public int deleteOrderByOrderIds(Long[] orderIds);

    /**
     * 删除订单信息
     * 
     * @param orderId 订单主键
     * @return 结果
     */
    public int deleteOrderByOrderId(Long orderId);

    /**
     * 取消所有超时未支付的订单，并释放它们占用的代金券。
     *
     * <p>为什么必须自动做：{@code VoucherUsageService.assertNotHeld} 把
     * status='0'（待支付）也算券被占用 —— 这是对的，否则一张券能在 N 个
     * 待付单里各抵一次。但用户下单不付时，那张券就一直锁着，会员端每次用券
     * 都弹「已用于另一笔待支付订单」。现在虽然有手动取消入口（{@code POST
     * /api/order/&#123;orderId&#125;/cancel}），但没人会为了解锁一张券去翻半年前的
     * 待付单，只能靠定时任务兜。</p>
     *
     * @param minutes 下单后多少分钟未支付算超时
     * @return 取消的订单数
     */
    public int cancelTimeoutUnpaid(int minutes);
}
