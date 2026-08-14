package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.common.annotation.IgnoreTenant;
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
