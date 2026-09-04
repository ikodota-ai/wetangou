package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.PayBill;

/**
 * 买单流水Service接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface IPayBillService 
{
    /**
     * 查询买单流水
     * 
     * @param billId 买单流水主键
     * @return 买单流水
     */
    public PayBill selectPayBillByBillId(Long billId);

    /**
     * 按买单编号查询
     *
     * @param billNo 买单编号
     * @return 买单流水
     */
    public PayBill selectPayBillByBillNo(String billNo);

    /**
     * 查询买单流水列表
     * 
     * @param payBill 买单流水
     * @return 买单流水集合
     */
    public List<PayBill> selectPayBillList(PayBill payBill);

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
     * @param payBill 买单流水
     * @return 结果
     */
    public int updatePayBill(PayBill payBill);

    /**
     * 批量删除买单流水
     * 
     * @param billIds 需要删除的买单流水主键集合
     * @return 结果
     */
    public int deletePayBillByBillIds(Long[] billIds);

    /**
     * 删除买单流水信息
     * 
     * @param billId 买单流水主键
     * @return 结果
     */
    public int deletePayBillByBillId(Long billId);

    /**
     * 取消所有超时未完成的买单（待确认 / 待支付），并释放它们占用的代金券。
     *
     * <p>与订单同源问题：{@code assertNotHeld} 判买单占用看
     * status in ('0','1')，用户在店里发起买单又走掉，券就被这张废单锁死。</p>
     *
     * @param minutes 发起后多少分钟未完成算超时
     * @return 取消的买单数
     */
    public int cancelTimeoutPending(int minutes);
}
