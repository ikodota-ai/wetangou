package com.ruoyi.biz.domain;

import java.util.Date;
import java.util.List;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 商品搭配-商品组 biz_product_subitem_group
 *
 * @author dytuangou
 * @date 2026-08-13
 */
public class ProductSubitemGroup extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    private Long groupId;
    private Long productId;
    private String groupName;
    private String pickRule;
    private Integer sort;
    private Date createTime;

    /** 子品列表（查询时填充） */
    private List<ProductSubitem> subitems;

    public Long getGroupId() { return groupId; }
    public void setGroupId(Long groupId) { this.groupId = groupId; }
    public Long getProductId() { return productId; }
    public void setProductId(Long productId) { this.productId = productId; }
    public String getGroupName() { return groupName; }
    public void setGroupName(String groupName) { this.groupName = groupName; }
    public String getPickRule() { return pickRule; }
    public void setPickRule(String pickRule) { this.pickRule = pickRule; }
    public Integer getSort() { return sort; }
    public void setSort(Integer sort) { this.sort = sort; }
    public Date getCreateTime() { return createTime; }
    public void setCreateTime(Date createTime) { this.createTime = createTime; }
    public List<ProductSubitem> getSubitems() { return subitems; }
    public void setSubitems(List<ProductSubitem> subitems) { this.subitems = subitems; }

    @Override
    public String toString() {
        return new ToStringBuilder(this, ToStringStyle.MULTI_LINE_STYLE)
            .append("groupId", getGroupId())
            .append("productId", getProductId())
            .append("groupName", getGroupName())
            .append("pickRule", getPickRule())
            .append("sort", getSort())
            .toString();
    }
}
