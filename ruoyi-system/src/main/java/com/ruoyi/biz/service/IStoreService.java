package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.Store;

/**
 * 门店Service接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface IStoreService 
{
    /**
     * 查询门店
     * 
     * @param storeId 门店主键
     * @return 门店
     */
    public Store selectStoreByStoreId(Long storeId);

    /**
     * 查询门店列表
     * 
     * @param store 门店
     * @return 门店集合
     */
    public List<Store> selectStoreList(Store store);

    /**
     * 新增门店
     * 
     * @param store 门店
     * @return 结果
     */
    public int insertStore(Store store);

    /**
     * 修改门店
     * 
     * @param store 门店
     * @return 结果
     */
    public int updateStore(Store store);

    /**
     * 批量删除门店
     * 
     * @param storeIds 需要删除的门店主键集合
     * @return 结果
     */
    public int deleteStoreByStoreIds(Long[] storeIds);

    /**
     * 删除门店信息
     * 
     * @param storeId 门店主键
     * @return 结果
     */
    public int deleteStoreByStoreId(Long storeId);
}
