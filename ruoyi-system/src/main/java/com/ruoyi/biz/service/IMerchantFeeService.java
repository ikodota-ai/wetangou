package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.MerchantFee;

/**
 * 商户收费Service接口
 *
 * @author dytuangou
 */
public interface IMerchantFeeService
{
    /**
     * 查询商户收费
     *
     * @param feeId 收费主键
     * @return 商户收费
     */
    public MerchantFee selectMerchantFeeByFeeId(Long feeId);

    /**
     * 查询商户收费列表
     *
     * @param merchantFee 商户收费
     * @return 商户收费集合
     */
    public List<MerchantFee> selectMerchantFeeList(MerchantFee merchantFee);

    /**
     * 新增商户收费
     *
     * @param merchantFee 商户收费
     * @return 结果
     */
    public int insertMerchantFee(MerchantFee merchantFee);

    /**
     * 修改商户收费
     *
     * @param merchantFee 商户收费
     * @return 结果
     */
    public int updateMerchantFee(MerchantFee merchantFee);

    /**
     * 确认收款：同步商户服务到期时间
     *
     * @param feeId 收费ID
     * @return 结果
     */
    public int confirmMerchantFee(Long feeId);

    /**
     * 批量删除商户收费
     *
     * @param feeIds 需要删除的数据主键集合
     * @return 结果
     */
    public int deleteMerchantFeeByFeeIds(Long[] feeIds);
}
