package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.common.annotation.IgnoreTenant;
import com.ruoyi.biz.domain.StoreAlbum;

/**
 * 门店相册Mapper接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface StoreAlbumMapper 
{
    /**
     * 查询门店相册
     * 
     * @param albumId 门店相册主键
     * @return 门店相册
     */
    @IgnoreTenant
    public StoreAlbum selectStoreAlbumByAlbumId(Long albumId);

    /**
     * 查询门店相册列表
     * 
     * @param storeAlbum 门店相册
     * @return 门店相册集合
     */
    public List<StoreAlbum> selectStoreAlbumList(StoreAlbum storeAlbum);

    /**
     * 新增门店相册
     * 
     * @param storeAlbum 门店相册
     * @return 结果
     */
    public int insertStoreAlbum(StoreAlbum storeAlbum);

    /**
     * 修改门店相册
     * 
     * @param storeAlbum 门店相册
     * @return 结果
     */
    public int updateStoreAlbum(StoreAlbum storeAlbum);

    /**
     * 删除门店相册
     * 
     * @param albumId 门店相册主键
     * @return 结果
     */
    public int deleteStoreAlbumByAlbumId(Long albumId);

    /**
     * 批量删除门店相册
     * 
     * @param albumIds 需要删除的数据主键集合
     * @return 结果
     */
    public int deleteStoreAlbumByAlbumIds(Long[] albumIds);
}
