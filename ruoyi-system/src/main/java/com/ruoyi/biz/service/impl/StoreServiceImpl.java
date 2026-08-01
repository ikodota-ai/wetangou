package com.ruoyi.biz.service.impl;

import java.util.List;
import com.ruoyi.common.utils.DateUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.mapper.StoreMapper;
import com.ruoyi.biz.domain.Store;
import com.ruoyi.biz.service.IStoreService;

/**
 * 门店Service业务层处理
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@Service
public class StoreServiceImpl implements IStoreService 
{
    @Autowired
    private StoreMapper storeMapper;

    /**
     * 查询门店
     * 
     * @param storeId 门店主键
     * @return 门店
     */
    @Override
    public Store selectStoreByStoreId(Long storeId)
    {
        return storeMapper.selectStoreByStoreId(storeId);
    }

    /**
     * 查询门店列表
     * 
     * @param store 门店
     * @return 门店
     */
    @Override
    public List<Store> selectStoreList(Store store)
    {
        return storeMapper.selectStoreList(store);
    }

    /**
     * 新增门店
     * 
     * @param store 门店
     * @return 结果
     */
    @Override
    public int insertStore(Store store)
    {
        store.setCreateTime(DateUtils.getNowDate());
        return storeMapper.insertStore(store);
    }

    /**
     * 修改门店
     * 
     * @param store 门店
     * @return 结果
     */
    @Override
    public int updateStore(Store store)
    {
        store.setUpdateTime(DateUtils.getNowDate());
        return storeMapper.updateStore(store);
    }

    /**
     * 批量删除门店
     * 
     * @param storeIds 需要删除的门店主键
     * @return 结果
     */
    @Override
    public int deleteStoreByStoreIds(Long[] storeIds)
    {
        return storeMapper.deleteStoreByStoreIds(storeIds);
    }

    /**
     * 删除门店信息
     * 
     * @param storeId 门店主键
     * @return 结果
     */
    @Override
    public int deleteStoreByStoreId(Long storeId)
    {
        return storeMapper.deleteStoreByStoreId(storeId);
    }
}
