package com.ruoyi.biz.service.impl;

import java.util.List;
import com.ruoyi.common.utils.DateUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.mapper.VoucherMapper;
import com.ruoyi.biz.domain.Voucher;
import com.ruoyi.biz.service.IVoucherService;

/**
 * 代金券模板Service业务层处理
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@Service
public class VoucherServiceImpl implements IVoucherService 
{
    @Autowired
    private VoucherMapper voucherMapper;

    /**
     * 查询代金券模板
     * 
     * @param voucherId 代金券模板主键
     * @return 代金券模板
     */
    @Override
    public Voucher selectVoucherByVoucherId(Long voucherId)
    {
        return voucherMapper.selectVoucherByVoucherId(voucherId);
    }

    /**
     * 查询代金券模板列表
     * 
     * @param voucher 代金券模板
     * @return 代金券模板
     */
    @Override
    public List<Voucher> selectVoucherList(Voucher voucher)
    {
        return voucherMapper.selectVoucherList(voucher);
    }

    /**
     * 新增代金券模板
     * 
     * @param voucher 代金券模板
     * @return 结果
     */
    @Override
    public int insertVoucher(Voucher voucher)
    {
        voucher.setCreateTime(DateUtils.getNowDate());
        return voucherMapper.insertVoucher(voucher);
    }

    /**
     * 修改代金券模板
     * 
     * @param voucher 代金券模板
     * @return 结果
     */
    @Override
    public int updateVoucher(Voucher voucher)
    {
        voucher.setUpdateTime(DateUtils.getNowDate());
        return voucherMapper.updateVoucher(voucher);
    }

    /**
     * 批量删除代金券模板
     * 
     * @param voucherIds 需要删除的代金券模板主键
     * @return 结果
     */
    @Override
    public int deleteVoucherByVoucherIds(Long[] voucherIds)
    {
        return voucherMapper.deleteVoucherByVoucherIds(voucherIds);
    }

    /**
     * 删除代金券模板信息
     * 
     * @param voucherId 代金券模板主键
     * @return 结果
     */
    @Override
    public int deleteVoucherByVoucherId(Long voucherId)
    {
        return voucherMapper.deleteVoucherByVoucherId(voucherId);
    }
}
