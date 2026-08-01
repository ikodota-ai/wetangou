package com.ruoyi.biz.mapper;

import com.ruoyi.biz.domain.MerchantUser;
import com.ruoyi.common.annotation.IgnoreTenant;

/**
 * 后台账号租户归属Mapper接口
 *
 * @author dytuangou
 */
@IgnoreTenant
public interface MerchantUserMapper
{
    /**
     * 按系统用户ID查询归属
     *
     * @param userId 系统用户ID
     * @return 账号租户归属
     */
    public MerchantUser selectMerchantUserByUserId(Long userId);

    /**
     * 新增账号租户归属
     *
     * @param merchantUser 账号租户归属
     * @return 结果
     */
    public int insertMerchantUser(MerchantUser merchantUser);

    /**
     * 修改账号租户归属
     *
     * @param merchantUser 账号租户归属
     * @return 结果
     */
    public int updateMerchantUser(MerchantUser merchantUser);

    /**
     * 按系统用户ID删除归属
     *
     * @param userId 系统用户ID
     * @return 结果
     */
    public int deleteMerchantUserByUserId(Long userId);
}
