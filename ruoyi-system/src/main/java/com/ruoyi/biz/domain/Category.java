package com.ruoyi.biz.domain;

import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 商品品类对象 biz_product_category（v2：合并原店内分类 + 抖音来客行业品类）
 *
 * @author dytuangou
 * @date 2026-07-24
 */
public class Category extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 商户ID（多商户隔离字段） */
    private Long merchantId;

    /** 分类ID */
    private Long categoryId;

    /** 门店ID（0=平台通用） */
    @Excel(name = "门店ID", readConverterExp = "0==平台通用")
    private Long storeId;

    /** 门店名称（展示用，非表字段） */
    private String storeName;

    /** 分类名称 */
    @Excel(name = "分类名称")
    private String categoryName;

    /** 分类图标 */
    @Excel(name = "分类图标")
    private String icon;

    /** 父级ID（0=顶级） */
    private Long parentId;

    /** 完整路径（如：购物·服饰鞋帽·服装） */
    private String fullPath;

    /** 层级 1/2/3 */
    private Integer level;

    /** 行业编码（CATERING/EDUCATION/...） */
    private String industryCode;

    /** 行业保证金（分） */
    private Long depositAmount;

    /** 允许的商品类型（逗号分隔） */
    private String allowedTypes;

    /** 必填资质（JSON） */
    private String licenseRequired;

    /** 平台统一说明模板 */
    private String complianceNotice;

    /** 显示顺序 */
    @Excel(name = "显示顺序")
    private Integer sort;

    /** 状态（0正常 1停用） */
    @Excel(name = "状态", readConverterExp = "0=正常,1=停用")
    private String status;

    public void setCategoryId(Long categoryId) 
    {
        this.categoryId = categoryId;
    }

    public Long getCategoryId() 
    {
        return categoryId;
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


    public void setCategoryName(String categoryName) 
    {
        this.categoryName = categoryName;
    }

    public String getCategoryName() 
    {
        return categoryName;
    }

    public void setIcon(String icon) 
    {
        this.icon = icon;
    }

    public String getIcon() 
    {
        return icon;
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

    public Long getMerchantId()
    {
        return merchantId;
    }

    public void setMerchantId(Long merchantId)
    {
        this.merchantId = merchantId;
    }

    public Long getParentId() { return parentId; }
    public void setParentId(Long parentId) { this.parentId = parentId; }
    public String getFullPath() { return fullPath; }
    public void setFullPath(String fullPath) { this.fullPath = fullPath; }
    public Integer getLevel() { return level; }
    public void setLevel(Integer level) { this.level = level; }
    public String getIndustryCode() { return industryCode; }
    public void setIndustryCode(String industryCode) { this.industryCode = industryCode; }
    public Long getDepositAmount() { return depositAmount; }
    public void setDepositAmount(Long depositAmount) { this.depositAmount = depositAmount; }
    public String getAllowedTypes() { return allowedTypes; }
    public void setAllowedTypes(String allowedTypes) { this.allowedTypes = allowedTypes; }
    public String getLicenseRequired() { return licenseRequired; }
    public void setLicenseRequired(String licenseRequired) { this.licenseRequired = licenseRequired; }
    public String getComplianceNotice() { return complianceNotice; }
    public void setComplianceNotice(String complianceNotice) { this.complianceNotice = complianceNotice; }

    @Override
    public String toString() {
        return new ToStringBuilder(this,ToStringStyle.MULTI_LINE_STYLE)
            .append("categoryId", getCategoryId())
            .append("storeId", getStoreId())
            .append("categoryName", getCategoryName())
            .append("icon", getIcon())
            .append("sort", getSort())
            .append("status", getStatus())
            .append("createBy", getCreateBy())
            .append("createTime", getCreateTime())
            .append("updateBy", getUpdateBy())
            .append("updateTime", getUpdateTime())
            .toString();
    }
}
