package com.ruoyi.biz.domain;

import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 门店相册对象 biz_store_album
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public class StoreAlbum extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 商户ID（多商户隔离字段） */
    private Long merchantId;

    /** 相册ID */
    private Long albumId;

    /** 门店ID */
    @Excel(name = "门店ID")
    private Long storeId;

    /** 门店名称（展示用，非表字段） */
    private String storeName;

    /** 图片地址 */
    @Excel(name = "图片地址")
    private String imageUrl;

    /** 类型（0环境 1菜品 2门面） */
    @Excel(name = "类型", readConverterExp = "0=环境,1=菜品,2=门面")
    private String albumType;

    /** 显示顺序 */
    @Excel(name = "显示顺序")
    private Integer sort;

    public void setAlbumId(Long albumId) 
    {
        this.albumId = albumId;
    }

    public Long getAlbumId() 
    {
        return albumId;
    }

    public void setStoreId(Long storeId) 
    {
        this.storeId = storeId;
    }

    public Long getStoreId() 
    {
        return storeId;
    }

    public void setStoreName(String storeName) { this.storeName = storeName; }

    public String getStoreName() { return storeName; }


    public void setImageUrl(String imageUrl) 
    {
        this.imageUrl = imageUrl;
    }

    public String getImageUrl() 
    {
        return imageUrl;
    }

    public void setAlbumType(String albumType) 
    {
        this.albumType = albumType;
    }

    public String getAlbumType() 
    {
        return albumType;
    }

    public void setSort(Integer sort) 
    {
        this.sort = sort;
    }

    public Integer getSort() 
    {
        return sort;
    }

    public Long getMerchantId()
    {
        return merchantId;
    }

    public void setMerchantId(Long merchantId)
    {
        this.merchantId = merchantId;
    }

    @Override
    public String toString() {
        return new ToStringBuilder(this,ToStringStyle.MULTI_LINE_STYLE)
            .append("albumId", getAlbumId())
            .append("storeId", getStoreId())
            .append("imageUrl", getImageUrl())
            .append("albumType", getAlbumType())
            .append("sort", getSort())
            .append("createBy", getCreateBy())
            .append("createTime", getCreateTime())
            .append("updateBy", getUpdateBy())
            .append("updateTime", getUpdateTime())
            .toString();
    }
}
