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
     * 把 appid 置为 NULL（解绑小程序）。
     *
     * <p>为什么要专用语句：updateMerchant 的动态 set 是 {@code <if test="appid != null">}，
     * 置 null 时那一行不会生成，appid 永远清不掉；而 appid 是 UNIQUE KEY 且历史数据落的是 ''，
     * 留着空串会让下一个不填 appid 的商户建不出来（Duplicate entry '' for key 'uk_appid'）。</p>
     *
     * @param merchantId 商户ID
     * @return 影响行数
     */
    public int clearAppid(Long merchantId);

    /**
     * 批量删除商户
     *
     * @param merchantIds 需要删除的数据主键集合
     * @return 结果
     */
    public int deleteMerchantByMerchantIds(Long[] merchantIds);
}
