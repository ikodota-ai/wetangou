package com.ruoyi.biz.service.impl;

import java.util.List;
import com.ruoyi.common.utils.DateUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.mapper.StoreUserMapper;
import com.ruoyi.biz.domain.StoreUser;
import com.ruoyi.biz.service.IStoreUserService;

/**
 * 账号门店关联Service业务层处理
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@Service
public class StoreUserServiceImpl implements IStoreUserService 
{
    @Autowired
    private StoreUserMapper storeUserMapper;

    /**
     * 查询账号门店关联
     * 
     * @param id 账号门店关联主键
     * @return 账号门店关联
     */
    @Override
    public StoreUser selectStoreUserById(Long id)
    {
        return storeUserMapper.selectStoreUserById(id);
    }

    /**
     * 查询账号门店关联列表
     * 
     * @param storeUser 账号门店关联
     * @return 账号门店关联
     */
    @Override
    public List<StoreUser> selectStoreUserList(StoreUser storeUser)
    {
        return storeUserMapper.selectStoreUserList(storeUser);
    }

    /**
     * 新增账号门店关联
     * 
     * @param storeUser 账号门店关联
     * @return 结果
     */
    @Override
    public int insertStoreUser(StoreUser storeUser)
    {
        storeUser.setCreateTime(DateUtils.getNowDate());
        return storeUserMapper.insertStoreUser(storeUser);
    }

    /**
     * 修改账号门店关联
     * 
     * @param storeUser 账号门店关联
     * @return 结果
     */
    @Override
    public int updateStoreUser(StoreUser storeUser)
    {
        return storeUserMapper.updateStoreUser(storeUser);
    }

    /**
     * 批量删除账号门店关联
     * 
     * @param ids 需要删除的账号门店关联主键
     * @return 结果
     */
    @Override
    public int deleteStoreUserByIds(Long[] ids)
    {
        return storeUserMapper.deleteStoreUserByIds(ids);
    }

    /**
     * 删除账号门店关联信息
     * 
     * @param id 账号门店关联主键
     * @return 结果
     */
    @Override
    public int deleteStoreUserById(Long id)
    {
        return storeUserMapper.deleteStoreUserById(id);
    }
}
