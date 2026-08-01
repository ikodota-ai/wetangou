package com.ruoyi.biz.domain;

import java.math.BigDecimal;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 商品对象 biz_product
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public class Product extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 商户ID（多商户隔离字段） */
    private Long merchantId;

    /** 商品ID */
    private Long productId;

    /** 门店ID（0=平台商品） */
    @Excel(name = "门店ID", readConverterExp = "0==平台商品")
    private Long storeId;

    /** 分类ID */
    @Excel(name = "分类ID")
    private Long categoryId;

    /** 门店名称（展示用，非表字段） */
    private String storeName;

    /** 适用门店ID集合（逗号分隔，多选） */
    private String storeIds;

    /** 适用门店名称（展示用，非表字段） */
    private String storeNames;

    /** 分类名称（展示用，非表字段） */
    private String categoryName;

    /** 商品名称 */
    @Excel(name = "商品名称")
    private String productName;

    /** 副标题 */
    @Excel(name = "副标题")
    private String subtitle;

    /** 封面图 */
    @Excel(name = "封面图")
    private String cover;

    /** 轮播图（逗号分隔） */
    @Excel(name = "轮播图", readConverterExp = "逗=号分隔")
    private String images;

    /** 类型（0到店自取 1到店买单 2预约服务） */
    @Excel(name = "类型", readConverterExp = "0=到店自取,1=到店买单,2=预约服务")
    private String productType;

    /** 售价 */
    @Excel(name = "售价")
    private BigDecimal price;

    /** 市场价 */
    @Excel(name = "市场价")
    private BigDecimal marketPrice;

    /** 库存 */
    @Excel(name = "库存")
    private Long stock;

    /** 销量 */
    @Excel(name = "销量")
    private Long sales;

    /** 有效天数 */
    @Excel(name = "有效天数")
    private Integer validityDays;

    /** 图文详情 */
    @Excel(name = "图文详情")
    private String detail;

    /** 购买须知 */
    @Excel(name = "购买须知")
    private String notice;

    /** 显示顺序 */
    @Excel(name = "显示顺序")
    private Integer sort;

    /** 状态（0上架 1下架） */
    @Excel(name = "状态", readConverterExp = "0=上架,1=下架")
    private String status;

    /** 删除标志（0存在 2删除） */
    private String delFlag;

    public void setProductId(Long productId) 
    {
        this.productId = productId;
    }

    public Long getProductId() 
    {
        return productId;
    }

    public void setStoreId(Long storeId) 
    {
        this.storeId = storeId;
    }

    public Long getStoreId() 
    {
        return storeId;
    }

    public void setCategoryId(Long categoryId) 
    {
        this.categoryId = categoryId;
    }

    public Long getCategoryId() 
    {
        return categoryId;
    }

    public void setStoreName(String storeName) { this.storeName = storeName; }

    public String getStoreName() { return storeName; }

    public void setStoreIds(String storeIds) { this.storeIds = storeIds; }

    public String getStoreIds() { return storeIds; }

    public void setStoreNames(String storeNames) { this.storeNames = storeNames; }

    public String getStoreNames() { return storeNames; }

    public void setCategoryName(String categoryName) { this.categoryName = categoryName; }

    public String getCategoryName() { return categoryName; }


    public void setProductName(String productName) 
    {
        this.productName = productName;
    }

    public String getProductName() 
    {
        return productName;
    }

    public void setSubtitle(String subtitle) 
    {
        this.subtitle = subtitle;
    }

    public String getSubtitle() 
    {
        return subtitle;
    }

    public void setCover(String cover) 
    {
        this.cover = cover;
    }

    public String getCover() 
    {
        return cover;
    }

    public void setImages(String images) 
    {
        this.images = images;
    }

    public String getImages() 
    {
        return images;
    }

    public void setProductType(String productType) 
    {
        this.productType = productType;
    }

    public String getProductType() 
    {
        return productType;
    }

    public void setPrice(BigDecimal price) 
    {
        this.price = price;
    }

    public BigDecimal getPrice() 
    {
        return price;
    }

    public void setMarketPrice(BigDecimal marketPrice) 
    {
        this.marketPrice = marketPrice;
    }

    public BigDecimal getMarketPrice() 
    {
        return marketPrice;
    }

    public void setStock(Long stock) 
    {
        this.stock = stock;
    }

    public Long getStock() 
    {
        return stock;
    }

    public void setSales(Long sales) 
    {
        this.sales = sales;
    }

    public Long getSales() 
    {
        return sales;
    }

    public void setValidityDays(Integer validityDays) 
    {
        this.validityDays = validityDays;
    }

    public Integer getValidityDays() 
    {
        return validityDays;
    }

    public void setDetail(String detail) 
    {
        this.detail = detail;
    }

    public String getDetail() 
    {
        return detail;
    }

    public void setNotice(String notice) 
    {
        this.notice = notice;
    }

    public String getNotice() 
    {
        return notice;
    }

    public void setSort(Integer sort) 
    {
        this.sort = sort;
    }

    public Integer getSort() 
    {
        return sort;
    }

    public void setStatus(String status) 
    {
        this.status = status;
    }

    public String getStatus() 
    {
        return status;
    }

    public void setDelFlag(String delFlag) 
    {
        this.delFlag = delFlag;
    }

    public String getDelFlag() 
    {
        return delFlag;
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
            .append("productId", getProductId())
            .append("storeId", getStoreId())
            .append("categoryId", getCategoryId())
            .append("productName", getProductName())
            .append("subtitle", getSubtitle())
            .append("cover", getCover())
            .append("images", getImages())
            .append("productType", getProductType())
            .append("price", getPrice())
            .append("marketPrice", getMarketPrice())
            .append("stock", getStock())
            .append("sales", getSales())
            .append("validityDays", getValidityDays())
            .append("detail", getDetail())
            .append("notice", getNotice())
            .append("sort", getSort())
            .append("status", getStatus())
            .append("delFlag", getDelFlag())
            .append("createBy", getCreateBy())
            .append("createTime", getCreateTime())
            .append("updateBy", getUpdateBy())
            .append("updateTime", getUpdateTime())
            .append("remark", getRemark())
            .toString();
    }
}
