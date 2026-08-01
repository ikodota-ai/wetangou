package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.StoreUser;

/**
 * 账号门店关联Service接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface IStoreUserService 
{
    /**
     * 查询账号门店关联
     * 
     * @param id 账号门店关联主键
     * @return 账号门店关联
     */
    public StoreUser selectStoreUserById(Long id);

    /**
     * 查询账号门店关联列表
     * 
     * @param storeUser 账号门店关联
     * @return 账号门店关联集合
     */
    public List<StoreUser> selectStoreUserList(StoreUser storeUser);

    /**
     * 新增账号门店关联
     * 
     * @param storeUser 账号门店关联
     * @return 结果
     */
    public int insertStoreUser(StoreUser storeUser);

    /**
     * 修改账号门店关联
     * 
     * @param storeUser 账号门店关联
     * @return 结果
     */
    public int updateStoreUser(StoreUser storeUser);

    /**
     * 批量删除账号门店关联
     * 
     * @param ids 需要删除的账号门店关联主键集合
     * @return 结果
     */
    public int deleteStoreUserByIds(Long[] ids);

    /**
     * 删除账号门店关联信息
     * 
     * @param id 账号门店关联主键
     * @return 结果
     */
    public int deleteStoreUserById(Long id);
}
