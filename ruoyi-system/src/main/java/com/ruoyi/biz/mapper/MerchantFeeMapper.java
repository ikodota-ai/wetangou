package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.biz.domain.MerchantFee;

/**
 * 商户收费Mapper接口
 *
 * <p>biz_merchant_fee 属商户强隔离表，由租户拦截器自动追加 merchant_id 条件。</p>
 *
 * @author dytuangou
 */
public interface MerchantFeeMapper
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
     * 批量删除商户收费
     *
     * @param feeIds 需要删除的数据主键集合
     * @return 结果
     */
    public int deleteMerchantFeeByFeeIds(Long[] feeIds);
}
