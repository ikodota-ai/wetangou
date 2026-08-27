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
    /*
     * v4 补落库的 9 列。
     *
     * 这些字段在后台商品编辑页早就有输入框，但因为 Product/ProductExt 两个域都没有
     * 对应属性，Jackson 反序列化时直接丢弃 —— 运营填完保存看不出异常，库里却什么都没有。
     * 佐证：357 个商品里只有 2 个有 extra_fee_desc、35 个有 sale_start_date，
     * 说明这些框从上线起就没生效过。
     */
    /** 投放渠道代码集合（逗号分隔，取值见 biz_sale_channel） */
    private String saleChannels;
    /** 职人带货 0否 1是 */
    private Integer staffPromote;
    /** 券码类型 MERCHANT商家券 / PLATFORM平台券 */
    private String codeType;
    /** 顾客可消费开始时间 */
    private Date consumeStartDate;
    /** 顾客可消费结束时间 */
    private Date consumeEndDate;
    /** 顾客不可消费日期段，JSON 数组：[["2026-01-01","2026-01-03"]] */
    private String excludeDates;
    /** 每日可消费时段开始 HH:mm:ss */
    private String dailyTimeStart;
    /** 每日可消费时段结束 HH:mm:ss */
    private String dailyTimeEnd;
    /** 代金券适用规则集合（逗号分隔 ALL_CATEGORY/ALL_BRAND/...） */
    private String voucherRules;
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
    public String getSaleChannels() { return saleChannels; }
    public void setSaleChannels(String saleChannels) { this.saleChannels = saleChannels; }
    public Integer getStaffPromote() { return staffPromote; }
    public void setStaffPromote(Integer staffPromote) { this.staffPromote = staffPromote; }
    public String getCodeType() { return codeType; }
    public void setCodeType(String codeType) { this.codeType = codeType; }
    public Date getConsumeStartDate() { return consumeStartDate; }
    public void setConsumeStartDate(Date consumeStartDate) { this.consumeStartDate = consumeStartDate; }
    public Date getConsumeEndDate() { return consumeEndDate; }
    public void setConsumeEndDate(Date consumeEndDate) { this.consumeEndDate = consumeEndDate; }
    public String getExcludeDates() { return excludeDates; }
    public void setExcludeDates(String excludeDates) { this.excludeDates = excludeDates; }
    public String getDailyTimeStart() { return dailyTimeStart; }
    public void setDailyTimeStart(String dailyTimeStart) { this.dailyTimeStart = dailyTimeStart; }
    public String getDailyTimeEnd() { return dailyTimeEnd; }
    public void setDailyTimeEnd(String dailyTimeEnd) { this.dailyTimeEnd = dailyTimeEnd; }
    public String getVoucherRules() { return voucherRules; }
    public void setVoucherRules(String voucherRules) { this.voucherRules = voucherRules; }
    public Date getCreateTime() { return createTime; }
    public void setCreateTime(Date createTime) { this.createTime = createTime; }
    public Date getUpdateTime() { return updateTime; }
    public void setUpdateTime(Date updateTime) { this.updateTime = updateTime; }
}
