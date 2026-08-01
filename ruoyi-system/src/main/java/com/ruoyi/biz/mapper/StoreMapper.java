package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.biz.domain.Store;
import org.apache.ibatis.annotations.Param;

/**
 * 门店Mapper接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface StoreMapper 
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
     * 删除门店
     * 
     * @param storeId 门店主键
     * @return 结果
     */
    public int deleteStoreByStoreId(Long storeId);

    /**
     * 批量删除门店
     * 
     * @param storeIds 需要删除的数据主键集合
     * @return 结果
     */
    /**
     * 按经纬度查询最近的 N 个门店
     *
     * <p>使用 MySQL Haversine 公式计算球面距离（米），
     * 返回结果按距离升序。租户过滤由 TenantSqlInterceptor 自动追加。</p>
     *
     * @param longitude 用户经度
     * @param latitude 用户纬度
     * @param limit 返回数量
     * @return 门店集合，含 distance 字段
     */
    public List<Store> selectNearestStoreList(@Param("longitude") Double longitude, @Param("latitude") Double latitude, @Param("limit") int limit);

    public int deleteStoreByStoreIds(Long[] storeIds);
}
