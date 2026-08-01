package com.ruoyi.biz.domain;

import java.math.BigDecimal;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 佣金规则对象 biz_commission_rule
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public class CommissionRule extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 商户ID（多商户隔离字段） */
    private Long merchantId;

    /** 规则ID */
    private Long ruleId;

    /** 规则名称 */
    @Excel(name = "规则名称")
    private String ruleName;

    /** 门店ID（0=全平台） */
    @Excel(name = "门店ID", readConverterExp = "0==全平台")
    private Long storeId;

    /** 门店名称（展示用，非表字段） */
    private String storeName;

    /** 分类ID */
    @Excel(name = "分类ID")
    private Long categoryId;

    /** 商品ID */
    @Excel(name = "商品ID")
    private Long productId;

    /** 分类名称（展示用，非表字段） */
    private String categoryName;

    /** 商品名称（展示用，非表字段） */
    private String productName;

    /** 适用推客等级 */
    @Excel(name = "适用推客等级")
    private Integer level;

    /** 佣金比例(%) */
    @Excel(name = "佣金比例(%)")
    private BigDecimal rate;

    /** 结算冷静期(天) */
    @Excel(name = "结算冷静期(天)")
    private Integer settleDays;

    /** 状态（0启用 1停用） */
    @Excel(name = "状态", readConverterExp = "0=启用,1=停用")
    private String status;

    public void setRuleId(Long ruleId) 
    {
        this.ruleId = ruleId;
    }

    public Long getRuleId() 
    {
        return ruleId;
    }

    public void setRuleName(String ruleName) 
    {
        this.ruleName = ruleName;
    }

    public String getRuleName() 
    {
        return ruleName;
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

    public void setCategoryName(String categoryName) { this.categoryName = categoryName; }

    public String getCategoryName() { return categoryName; }

    public void setProductName(String productName) { this.productName = productName; }

    public String getProductName() { return productName; }


    public void setCategoryId(Long categoryId) 
    {
        this.categoryId = categoryId;
    }

    public Long getCategoryId() 
    {
        return categoryId;
    }

    public void setProductId(Long productId) 
    {
        this.productId = productId;
    }

    public Long getProductId() 
    {
        return productId;
    }

    public void setLevel(Integer level) 
    {
        this.level = level;
    }

    public Integer getLevel() 
    {
        return level;
    }

    public void setRate(BigDecimal rate) 
    {
        this.rate = rate;
    }

    public BigDecimal getRate() 
    {
        return rate;
    }

    public void setSettleDays(Integer settleDays) 
    {
        this.settleDays = settleDays;
    }

    public Integer getSettleDays() 
    {
        return settleDays;
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

    @Override
    public String toString() {
        return new ToStringBuilder(this,ToStringStyle.MULTI_LINE_STYLE)
            .append("ruleId", getRuleId())
            .append("ruleName", getRuleName())
            .append("storeId", getStoreId())
            .append("categoryId", getCategoryId())
            .append("productId", getProductId())
            .append("level", getLevel())
            .append("rate", getRate())
            .append("settleDays", getSettleDays())
            .append("status", getStatus())
            .append("createBy", getCreateBy())
            .append("createTime", getCreateTime())
            .append("updateBy", getUpdateBy())
            .append("updateTime", getUpdateTime())
            .toString();
    }
}
