package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.common.annotation.IgnoreTenant;

/**
 * 商户Mapper接口
 *
 * <p>商户表本身不参与租户过滤（否则无法按appid反查商户），
 * 可见范围由服务层按账号类型控制。</p>
 *
 * @author dytuangou
 */
@IgnoreTenant
public interface MerchantMapper
{
    /**
     * 查询商户
     *
     * @param merchantId 商户主键
     * @return 商户
     */
    public Merchant selectMerchantByMerchantId(Long merchantId);

    /**
     * 按小程序appid查询商户
     *
     * @param appid 小程序appid
     * @return 商户
     */
    public Merchant selectMerchantByAppid(String appid);

    /**
     * 查询商户列表
     *
     * @param merchant 商户
     * @return 商户集合
     */
    public List<Merchant> selectMerchantList(Merchant merchant);

    /**
     * 查询代理商名下的商户ID列表
     *
     * @param agentId 代理商ID
     * @return 商户ID集合
     */
    public List<Long> selectMerchantIdsByAgentId(Long agentId);

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
     * @param merchantIds 需要删除的数据主键集合
     * @return 结果
     */
    public int deleteMerchantByMerchantIds(Long[] merchantIds);
}
