package com.ruoyi.biz.domain;

import java.math.BigDecimal;
import java.util.Date;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 商品搭配-子品 biz_product_subitem
 *
 * @author dytuangou
 * @date 2026-08-13
 */
public class ProductSubitem extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    private Long subitemId;
    private Long groupId;
    private String subitemType;
    private Long productId;
    private String subitemName;
    private Integer quantity;
    private Integer pickQuantity;
    private BigDecimal totalValue;
    private BigDecimal price;
    private Integer sort;
    private Date createTime;

    public Long getSubitemId() { return subitemId; }
    public void setSubitemId(Long subitemId) { this.subitemId = subitemId; }
    public Long getGroupId() { return groupId; }
    public void setGroupId(Long groupId) { this.groupId = groupId; }
    public String getSubitemType() { return subitemType; }
    public void setSubitemType(String subitemType) { this.subitemType = subitemType; }
    public Long getProductId() { return productId; }
    public void setProductId(Long productId) { this.productId = productId; }
    public String getSubitemName() { return subitemName; }
    public void setSubitemName(String subitemName) { this.subitemName = subitemName; }
    public Integer getQuantity() { return quantity; }
    public void setQuantity(Integer quantity) { this.quantity = quantity; }
    public Integer getPickQuantity() { return pickQuantity; }
    public void setPickQuantity(Integer pickQuantity) { this.pickQuantity = pickQuantity; }
    public BigDecimal getTotalValue() { return totalValue; }
    public void setTotalValue(BigDecimal totalValue) { this.totalValue = totalValue; }
    public BigDecimal getPrice() { return price; }
    public void setPrice(BigDecimal price) { this.price = price; }
    public Integer getSort() { return sort; }
    public void setSort(Integer sort) { this.sort = sort; }
    public Date getCreateTime() { return createTime; }
    public void setCreateTime(Date createTime) { this.createTime = createTime; }

    @Override
    public String toString() {
        return new ToStringBuilder(this, ToStringStyle.MULTI_LINE_STYLE)
            .append("subitemId", getSubitemId())
            .append("groupId", getGroupId())
            .append("subitemType", getSubitemType())
            .append("subitemName", getSubitemName())
            .append("quantity", getQuantity())
            .append("pickQuantity", getPickQuantity())
            .append("totalValue", getTotalValue())
            .append("price", getPrice())
            .toString();
    }
}
