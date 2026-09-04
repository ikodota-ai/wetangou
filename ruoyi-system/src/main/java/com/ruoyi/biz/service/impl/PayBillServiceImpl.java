package com.ruoyi.biz.service.impl;

import java.util.List;
import com.ruoyi.common.utils.DateUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
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
    private static final Logger log = LoggerFactory.getLogger(PayBillServiceImpl.class);

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

    /**
     * 取消超时未完成买单。动作与 {@code ApiBillController.cancel} 一致
     * （status 置 '3' + clearVoucher），只是不校验 memberId 归属。
     */
    @Override
    @Transactional(rollbackFor = Exception.class)
    public int cancelTimeoutPending(int minutes)
    {
        List<Long> ids = payBillMapper.selectTimeoutPendingIds(minutes);
        int cancelled = 0;
        for (Long billId : ids)
        {
            PayBill patch = new PayBill();
            patch.setBillId(billId);
            patch.setStatus("3");
            patch.setUpdateTime(DateUtils.getNowDate());
            payBillMapper.updatePayBill(patch);
            payBillMapper.clearVoucher(billId);
            cancelled++;
        }
        if (cancelled > 0)
        {
            log.info("[bill] 超时自动取消 count={} minutes={} ids={}", cancelled, minutes,
                    ids.size() > 20 ? ids.subList(0, 20) + "...(共" + ids.size() + ")" : ids);
        }
        return cancelled;
    }
}
