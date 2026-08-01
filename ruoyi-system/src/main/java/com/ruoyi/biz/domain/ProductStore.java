package com.ruoyi.biz.domain;

import java.math.BigDecimal;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 商品门店上架关系对象 biz_product_store
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public class ProductStore extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 商户ID（多商户隔离字段） */
    private Long merchantId;

    /** 主键 */
    private Long id;

    /** 商品ID */
    @Excel(name = "商品ID")
    private Long productId;

    /** 门店ID */
    @Excel(name = "门店ID")
    private Long storeId;

    /** 门店覆盖价格（空=用商品价） */
    @Excel(name = "门店覆盖价格", readConverterExp = "空==用商品价")
    private BigDecimal price;

    /** 门店库存 */
    @Excel(name = "门店库存")
    private Long stock;

    /** 是否上架（0上架 1下架） */
    @Excel(name = "是否上架", readConverterExp = "0=上架,1=下架")
    private String onSale;

    public void setId(Long id) 
    {
        this.id = id;
    }

    public Long getId() 
    {
        return id;
    }

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

    public void setPrice(BigDecimal price) 
    {
        this.price = price;
    }

    public BigDecimal getPrice() 
    {
        return price;
    }

    public void setStock(Long stock) 
    {
        this.stock = stock;
    }

    public Long getStock() 
    {
        return stock;
    }

    public void setOnSale(String onSale) 
    {
        this.onSale = onSale;
    }

    public String getOnSale() 
    {
        return onSale;
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
            .append("id", getId())
            .append("productId", getProductId())
            .append("storeId", getStoreId())
            .append("price", getPrice())
            .append("stock", getStock())
            .append("onSale", getOnSale())
            .append("createTime", getCreateTime())
            .toString();
    }
}
