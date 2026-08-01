package com.ruoyi.biz.service.impl;

import java.util.List;
import com.ruoyi.common.utils.DateUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.mapper.StoreAlbumMapper;
import com.ruoyi.biz.domain.StoreAlbum;
import com.ruoyi.biz.service.IStoreAlbumService;

/**
 * 门店相册Service业务层处理
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@Service
public class StoreAlbumServiceImpl implements IStoreAlbumService 
{
    @Autowired
    private StoreAlbumMapper storeAlbumMapper;

    /**
     * 查询门店相册
     * 
     * @param albumId 门店相册主键
     * @return 门店相册
     */
    @Override
    public StoreAlbum selectStoreAlbumByAlbumId(Long albumId)
    {
        return storeAlbumMapper.selectStoreAlbumByAlbumId(albumId);
    }

    /**
     * 查询门店相册列表
     * 
     * @param storeAlbum 门店相册
     * @return 门店相册
     */
    @Override
    public List<StoreAlbum> selectStoreAlbumList(StoreAlbum storeAlbum)
    {
        return storeAlbumMapper.selectStoreAlbumList(storeAlbum);
    }

    /**
     * 新增门店相册
     * 
     * @param storeAlbum 门店相册
     * @return 结果
     */
    @Override
    public int insertStoreAlbum(StoreAlbum storeAlbum)
    {
        storeAlbum.setCreateTime(DateUtils.getNowDate());
        return storeAlbumMapper.insertStoreAlbum(storeAlbum);
    }

    /**
     * 修改门店相册
     * 
     * @param storeAlbum 门店相册
     * @return 结果
     */
    @Override
    public int updateStoreAlbum(StoreAlbum storeAlbum)
    {
        storeAlbum.setUpdateTime(DateUtils.getNowDate());
        return storeAlbumMapper.updateStoreAlbum(storeAlbum);
    }

    /**
     * 批量删除门店相册
     * 
     * @param albumIds 需要删除的门店相册主键
     * @return 结果
     */
    @Override
    public int deleteStoreAlbumByAlbumIds(Long[] albumIds)
    {
        return storeAlbumMapper.deleteStoreAlbumByAlbumIds(albumIds);
    }

    /**
     * 删除门店相册信息
     * 
     * @param albumId 门店相册主键
     * @return 结果
     */
    @Override
    public int deleteStoreAlbumByAlbumId(Long albumId)
    {
        return storeAlbumMapper.deleteStoreAlbumByAlbumId(albumId);
    }
}
