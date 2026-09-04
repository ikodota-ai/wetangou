package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.common.annotation.IgnoreTenant;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.biz.domain.PayBill;

/**
 * 买单流水Mapper接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface PayBillMapper 
{
    /**
     * 查询买单流水
     * 
     * @param billId 买单流水主键
     * @return 买单流水
     */
    @IgnoreTenant
    public PayBill selectPayBillByBillId(Long billId);

    /**
     * 按买单编号查询
     *
     * <p>@IgnoreTenant 的理由同 {@code OrderMapper.selectOrderByOrderNo}：
     * 调用方是微信支付回调，没有登录身份，租户上下文兜底成默认商户后
     * 会给 SQL 追加 {@code merchant_id = 1}，商户 100 的买单查不出来，
     * 支付成功的钱收了但买单状态不动。bill_no 全库唯一。</p>
     *
     * @param billNo 买单编号
     * @return 买单流水
     */
    @IgnoreTenant
    public PayBill selectPayBillByBillNo(String billNo);

    /**
     * 查询买单流水列表
     * 
     * @param payBill 买单流水
     * @return 买单流水集合
     */
    public List<PayBill> selectPayBillList(PayBill payBill);

    /**
     * 该会员券当前被几个「未失效」的买单占用（status 0 待确认 / 1 待支付 / 2 已完成）。
     *
     * <p>和订单侧同一个问题：券的「已使用」是支付回调才置的，建单只是把
     * member_voucher_id 记到买单上，于是一张券可以同时挂在多个待支付买单上
     * 各抵一次。买单和商品下单共用一套券，所以两张表都要算进占用。</p>
     *
     * @param memberVoucherId 会员券 id
     * @param excludeBillId   要排除的买单主键，可为 null
     * @return 占用该券的买单数
     */
    public int countVoucherHeldBills(@Param("memberVoucherId") Long memberVoucherId,
            @Param("excludeBillId") Long excludeBillId);

    /**
     * 新增买单流水
     * 
     * @param payBill 买单流水
     * @return 结果
     */
    public int insertPayBill(PayBill payBill);

    /**
     * 修改买单流水
     * 
     * <p>@IgnoreTenant：支付回调无登录身份，租户改写会让 update 影响 0 行。</p>
     *
     * @param payBill 买单流水
     * @return 结果
     */
    @IgnoreTenant
    public int updatePayBill(PayBill payBill);

    /**
     * 清掉买单上的会员券引用（取消买单时释放券占用）。
     *
     * @param billId 买单主键
     * @return 结果
     */
    public int clearVoucher(@Param("billId") Long billId);

    /**
     * 查出所有已超时的待确认/待支付买单主键（定时任务用）。
     *
     * <p>status '0'（待确认）和 '1'（待支付）都要收：门店开了自动确认时买单直接落
     * '1'，没开时停在 '0'，两种都可能被用户放弃而把券锁死。</p>
     *
     * @param minutes 发起后多少分钟未完成算超时
     * @return 待取消的买单主键集合
     */
    @IgnoreTenant
    public List<Long> selectTimeoutPendingIds(@Param("minutes") int minutes);

    /**
     * 删除买单流水
     * 
     * @param billId 买单流水主键
     * @return 结果
     */
    public int deletePayBillByBillId(Long billId);

    /**
     * 批量删除买单流水
     * 
     * @param billIds 需要删除的数据主键集合
     * @return 结果
     */
    public int deletePayBillByBillIds(Long[] billIds);
}
