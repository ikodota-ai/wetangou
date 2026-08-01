package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.Merchant;

/**
 * 商户Service接口
 *
 * @author dytuangou
 */
public interface IMerchantService
{
    /**
     * 查询商户
     *
     * @param merchantId 商户主键
     * @return 商户
     */
    public Merchant selectMerchantByMerchantId(Long merchantId);

    /**
     * 查询商户列表（按当前登录账号的可见范围过滤）
     *
     * @param merchant 商户
     * @return 商户集合
     */
    public List<Merchant> selectMerchantList(Merchant merchant);

    /**
     * 新增商户
     *
     * @param merchant 商户
     * @return 结果
     */
    public int insertMerchant(Merchant merchant);

    /**
     * 修改商户
     *
     * @param merchant 商户
     * @return 结果
     */
    public int updateMerchant(Merchant merchant);

    /**
     * 批量删除商户
     *
     * @param merchantIds 需要删除的商户主键集合
     * @return 结果
     */
    public int deleteMerchantByMerchantIds(Long[] merchantIds);

    /**
     * 校验appid唯一性
     *
     * @param merchant 商户
     * @return 是否唯一
     */
    public boolean checkAppidUnique(Merchant merchant);

    /**
     * 校验当前账号是否有权操作该商户
     *
     * @param merchantId 商户ID
     */
    public void checkMerchantDataScope(Long merchantId);
}
