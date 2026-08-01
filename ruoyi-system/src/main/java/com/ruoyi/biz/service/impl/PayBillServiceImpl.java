package com.ruoyi.biz.service.impl;

import java.util.List;
import com.ruoyi.common.utils.DateUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.mapper.PayBillMapper;
import com.ruoyi.biz.domain.PayBill;
import com.ruoyi.biz.service.IPayBillService;

/**
 * 买单流水Service业务层处理
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@Service
public class PayBillServiceImpl implements IPayBillService 
{
    @Autowired
    private PayBillMapper payBillMapper;

    /**
     * 查询买单流水
     * 
     * @param billId 买单流水主键
     * @return 买单流水
     */
    @Override
    public PayBill selectPayBillByBillId(Long billId)
    {
        return payBillMapper.selectPayBillByBillId(billId);
    }

    @Override
    public PayBill selectPayBillByBillNo(String billNo)
    {
        return payBillMapper.selectPayBillByBillNo(billNo);
    }

    /**
     * 查询买单流水列表
     * 
     * @param payBill 买单流水
     * @return 买单流水
     */
    @Override
    public List<PayBill> selectPayBillList(PayBill payBill)
    {
        return payBillMapper.selectPayBillList(payBill);
    }

    /**
     * 新增买单流水
     * 
     * @param payBill 买单流水
     * @return 结果
     */
    @Override
    public int insertPayBill(PayBill payBill)
    {
        payBill.setCreateTime(DateUtils.getNowDate());
        return payBillMapper.insertPayBill(payBill);
    }

    /**
     * 修改买单流水
     * 
     * @param payBill 买单流水
     * @return 结果
     */
    @Override
    public int updatePayBill(PayBill payBill)
    {
        payBill.setUpdateTime(DateUtils.getNowDate());
        return payBillMapper.updatePayBill(payBill);
    }

    /**
     * 批量删除买单流水
     * 
     * @param billIds 需要删除的买单流水主键
     * @return 结果
     */
    @Override
    public int deletePayBillByBillIds(Long[] billIds)
    {
        return payBillMapper.deletePayBillByBillIds(billIds);
    }

    /**
     * 删除买单流水信息
     * 
     * @param billId 买单流水主键
     * @return 结果
     */
    @Override
    public int deletePayBillByBillId(Long billId)
    {
        return payBillMapper.deletePayBillByBillId(billId);
    }
}
