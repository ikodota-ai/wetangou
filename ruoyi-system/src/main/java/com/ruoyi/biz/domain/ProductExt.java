package com.ruoyi.biz.domain;

import java.math.BigDecimal;
import java.util.Date;

/**
 * 商品扩展属性 biz_product_ext
 * 类型差异(代金券/组合券包/团购) + 6 tab 详细字段
 * 1:1 关联 biz_product
 */
public class ProductExt {
    private Long productId;
    // 代金券 4 列
    private Integer voucherAutoName;
    private BigDecimal voucherMinConsume;
    private String voucherScopeType;
    private String voucherScopeIds;
    // 组合券包 5 列
    private BigDecimal comboTotalValue;
    private String comboSaleType;
    private Integer comboAutoExtendDays;
    private String outerSubitemId;
    private String comboItemsJson;
    // 团购 2 列
    private String grouponPickRule;
    private Integer grouponActualCount;
    // 通用 2 列
    private Integer dailyUseLimit;
    private String refundRuleType;
    private Date createTime;
    private Date updateTime;

    public Long getProductId() { return productId; }
    public void setProductId(Long productId) { this.productId = productId; }
    public Integer getVoucherAutoName() { return voucherAutoName; }
    public void setVoucherAutoName(Integer voucherAutoName) { this.voucherAutoName = voucherAutoName; }
    public BigDecimal getVoucherMinConsume() { return voucherMinConsume; }
    public void setVoucherMinConsume(BigDecimal voucherMinConsume) { this.voucherMinConsume = voucherMinConsume; }
    public String getVoucherScopeType() { return voucherScopeType; }
    public void setVoucherScopeType(String voucherScopeType) { this.voucherScopeType = voucherScopeType; }
    public String getVoucherScopeIds() { return voucherScopeIds; }
    public void setVoucherScopeIds(String voucherScopeIds) { this.voucherScopeIds = voucherScopeIds; }
    public BigDecimal getComboTotalValue() { return comboTotalValue; }
    public void setComboTotalValue(BigDecimal comboTotalValue) { this.comboTotalValue = comboTotalValue; }
    public String getComboSaleType() { return comboSaleType; }
    public void setComboSaleType(String comboSaleType) { this.comboSaleType = comboSaleType; }
    public Integer getComboAutoExtendDays() { return comboAutoExtendDays; }
    public void setComboAutoExtendDays(Integer comboAutoExtendDays) { this.comboAutoExtendDays = comboAutoExtendDays; }
    public String getOuterSubitemId() { return outerSubitemId; }
    public void setOuterSubitemId(String outerSubitemId) { this.outerSubitemId = outerSubitemId; }
    public String getComboItemsJson() { return comboItemsJson; }
    public void setComboItemsJson(String comboItemsJson) { this.comboItemsJson = comboItemsJson; }
    public String getGrouponPickRule() { return grouponPickRule; }
    public void setGrouponPickRule(String grouponPickRule) { this.grouponPickRule = grouponPickRule; }
    public Integer getGrouponActualCount() { return grouponActualCount; }
    public void setGrouponActualCount(Integer grouponActualCount) { this.grouponActualCount = grouponActualCount; }
    public Integer getDailyUseLimit() { return dailyUseLimit; }
    public void setDailyUseLimit(Integer dailyUseLimit) { this.dailyUseLimit = dailyUseLimit; }
    public String getRefundRuleType() { return refundRuleType; }
    public void setRefundRuleType(String refundRuleType) { this.refundRuleType = refundRuleType; }
    public Date getCreateTime() { return createTime; }
    public void setCreateTime(Date createTime) { this.createTime = createTime; }
    public Date getUpdateTime() { return updateTime; }
    public void setUpdateTime(Date updateTime) { this.updateTime = updateTime; }
}
