package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.biz.domain.Order;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.common.annotation.IgnoreTenant;

/**
 * 订单Mapper接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface OrderMapper 
{
    /**
     * 查询订单
     * 
     * @param orderId 订单主键
     * @return 订单
     */
    @IgnoreTenant
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
     * 核销记录查询：按核销时间倒序，只返回真正核销过的单（verify_time 非空）。
     *
     * <p>为什么不能复用 selectOrderList：那个查询的时间区间打在 create_time 上，
     * 而团购最常见的就是「昨天买、今天来店里核」—— 用下单时间筛，店长今天的
     * 核销记录里会看不到这些单，反而混进今天下单但还没核的单。核销记录必须
     * 按 verify_time 筛。</p>
     *
     * <p>params 支持 storeIds（find_in_set，多店老板一次看全部授权门店）、
     * verifyBegin / verifyEnd（核销时间区间）、verifyUser（核销人精确匹配）。</p>
     */
    public List<Order> selectVerifiedOrderList(Order order);

    /**
     * 该会员券当前被几个「未失效」的订单占用（status 0 待支付 / 1 待使用 / 2 已核销）。
     *
     * <p>为什么必须有这个查询：券的「已使用」是在支付成功回调里才置的，
     * 下单只是把 member_voucher_id 记到订单上。于是同一张券可以在多个待支付
     * 订单里各抵一次 —— 实测一张 ¥20 券连开 3 单，三单都 discount=20，
     * 支付后 use_order_id 只记住第一单，商家凭空少收 ¥40。</p>
     *
     * <p>排除自身订单（excludeOrderId）是为了支持「待支付订单换券」：
     * 换成同一张券时不能被自己占用的记录挡住。</p>
     *
     * @param memberVoucherId 会员券 id
     * @param excludeOrderId  要排除的订单主键，可为 null
     * @return 占用该券的订单数
     */
    @IgnoreTenant
    public int countVoucherHeldOrders(@Param("memberVoucherId") Long memberVoucherId,
            @Param("excludeOrderId") Long excludeOrderId);

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
     * 把订单上的代金券清空（取消用券）。
     *
     * <p>不能复用 updateOrder：它的动态 SQL 是
     * {@code <if test="memberVoucherId != null">}，传 null 那一列会被整段跳过，
     * 于是「取消用券」在库里永远不生效 —— 金额减了、券还挂着。</p>
     *
     * @param orderId 订单主键
     * @return 结果
     */
    @IgnoreTenant
    public int clearVoucher(@Param("orderId") Long orderId);

    /**
     * 删除订单
     * 
     * @param orderId 订单主键
     * @return 结果
     */
    public int deleteOrderByOrderId(Long orderId);

    /**
     * 批量删除订单
     * 
     * @param orderIds 需要删除的数据主键集合
     * @return 结果
     */
    public int deleteOrderByOrderIds(Long[] orderIds);
}
