package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.biz.domain.Voucher;

/**
 * 代金券模板Mapper接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface VoucherMapper 
{
    /**
     * 查询代金券模板
     * 
     * @param voucherId 代金券模板主键
     * @return 代金券模板
     */
    public Voucher selectVoucherByVoucherId(Long voucherId);

    /**
     * 查询代金券模板列表
     * 
     * @param voucher 代金券模板
     * @return 代金券模板集合
     */
    public List<Voucher> selectVoucherList(Voucher voucher);

    /**
     * 新增代金券模板
     * 
     * @param voucher 代金券模板
     * @return 结果
     */
    public int insertVoucher(Voucher voucher);

    /**
     * 修改代金券模板
     * 
     * @param voucher 代金券模板
     * @return 结果
     */
    public int updateVoucher(Voucher voucher);

    /**
     * 删除代金券模板
     * 
     * @param voucherId 代金券模板主键
     * @return 结果
     */
    public int deleteVoucherByVoucherId(Long voucherId);

    /**
     * 批量删除代金券模板
     * 
     * @param voucherIds 需要删除的数据主键集合
     * @return 结果
     */
    public int deleteVoucherByVoucherIds(Long[] voucherIds);
}
