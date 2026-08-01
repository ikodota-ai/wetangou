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
    /**
     * 按经纬度查询最近的 N 个门店
     */
    public List<Store> selectNearestStoreList(Double longitude, Double latitude, int limit);

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

    /**
     * 查询距离 (lng,lat) 最近的 N 个门店（仅当前商户，status=0，del_flag=0）
     *
     * <p>使用 MySQL Haversine 公式直接在 SQL 端计算球面距离并排序，
     * 避免 Java 端二次遍历。返回结果包含 distance 字段（单位：米）。</p>
     *
     * @param longitude 用户经度（GCJ-02）
     * @param latitude 用户纬度（GCJ-02）
     * @param limit 返回数量
     * @return 门店集合，按距离升序
     */
