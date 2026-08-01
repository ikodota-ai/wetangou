package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.StoreAlbum;

/**
 * 门店相册Service接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface IStoreAlbumService 
{
    /**
     * 查询门店相册
     * 
     * @param albumId 门店相册主键
     * @return 门店相册
     */
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
     * 批量删除门店相册
     * 
     * @param albumIds 需要删除的门店相册主键集合
     * @return 结果
     */
    public int deleteStoreAlbumByAlbumIds(Long[] albumIds);

    /**
     * 删除门店相册信息
     * 
     * @param albumId 门店相册主键
     * @return 结果
     */
    public int deleteStoreAlbumByAlbumId(Long albumId);
}
