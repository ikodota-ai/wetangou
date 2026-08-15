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

    /** 类型代码（v2：GROUPON/VOUCHER/TIMECARD/...） */
    private String typeCode;

    /** 行业编码（CATERING/EDUCATION/...） */
    private String industryCode;

    /** 面值/划线价（代金券面值/次卡总价值） */
    private BigDecimal faceValue;

    /** 最低消费门槛（代金券用） */
    private BigDecimal minConsume;

    /** 总次数（次卡用） */
    private Long totalTimes;
    // 续篇 9 · 主表加列覆盖 3 类型差异 + 6 tab 详细字段
    private Integer voucherAutoName;
    private java.math.BigDecimal voucherMinConsume;
    private java.math.BigDecimal comboTotalValue;
    private String comboSaleType;
    private Integer comboAutoExtendDays;
    private String outerSubitemId;
    private String comboItemsJson;
    private String voucherScopeType;
    private String voucherScopeIds;
    private String grouponPickRule;
    private Integer grouponActualCount;
    private Integer dailyUseLimit;
    private String refundRuleType;

    /** 周期类型 MONTH/QUARTER/YEAR */
    private String periodType;

    /** 周期数 */
    private Integer periodCount;

    /** 售卖开始时间 */
    private java.util.Date saleStartDate;

    /** 售卖结束时间 */
    private java.util.Date saleEndDate;

    /** 顾客可消费起始天数（自购买次日起） */
    private Integer consumeStartDays;

    /** 顾客可消费有效天数 */
    private Integer consumeValidDays;

    /** 购买当天是否可用 0否 1是 */
    private Integer consumeStartToday;

    /** 每人限购件数（0=不限） */
    private Long limitPerUser;

    /** 单次消费最多使用张数 */
    private Integer maxPerOrder;

    /** 每张券最多使用人数（团购用，0=不限） */
    private Integer maxPersons;

    /** 售后政策 */
    private String refundPolicy;

    /** 是否需要预约 0否 1是 */
    private Integer bookingRequired;

    /** 预约是否仅工作日 0否 1是 */
    private Integer bookingWorkdayOnly;

    /** 券码类型 PLATFORM/THIRD_PARTY/MERCHANT_OWN */
    private String collectMethod;

    /** 是否与店内优惠互斥 0否 1是 */
    private Integer mutexWithStorePromotion;

    /** 额外费用说明 */
    private String extraFeeDesc;

    /** 其他说明（500字内） */
    private String otherNotice;

    /** 推客佣金比例（%） */
    private BigDecimal commissionRate;

    /** 组合券包总价值（划线价） */
    private BigDecimal totalValue;

    /** 子品 N 选 M 规则：1选1/2选2/ALL */
    private String subitemPickRule;

    /** 是否需要冷静期（次卡/储值卡/周期卡/惠享卡=1） */
    private Integer requireXiaoxin;

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

    public String getTypeCode() { return typeCode; }
    public void setTypeCode(String typeCode) { this.typeCode = typeCode; }
    public String getIndustryCode() { return industryCode; }
    public void setIndustryCode(String industryCode) { this.industryCode = industryCode; }
    public java.math.BigDecimal getFaceValue() { return faceValue; }
    public void setFaceValue(java.math.BigDecimal faceValue) { this.faceValue = faceValue; }
    public java.math.BigDecimal getMinConsume() { return minConsume; }
    public void setMinConsume(java.math.BigDecimal minConsume) { this.minConsume = minConsume; }
    public Long getTotalTimes() { return totalTimes; }
    public void setTotalTimes(Long totalTimes) { this.totalTimes = totalTimes; }
    public Integer getVoucherAutoName() { return voucherAutoName; }
    public void setVoucherAutoName(Integer voucherAutoName) { this.voucherAutoName = voucherAutoName; }
    public java.math.BigDecimal getVoucherMinConsume() { return voucherMinConsume; }
    public void setVoucherMinConsume(java.math.BigDecimal voucherMinConsume) { this.voucherMinConsume = voucherMinConsume; }
    public java.math.BigDecimal getComboTotalValue() { return comboTotalValue; }
    public void setComboTotalValue(java.math.BigDecimal comboTotalValue) { this.comboTotalValue = comboTotalValue; }
    public String getComboSaleType() { return comboSaleType; }
    public void setComboSaleType(String comboSaleType) { this.comboSaleType = comboSaleType; }
    public Integer getComboAutoExtendDays() { return comboAutoExtendDays; }
    public void setComboAutoExtendDays(Integer comboAutoExtendDays) { this.comboAutoExtendDays = comboAutoExtendDays; }
    public String getOuterSubitemId() { return outerSubitemId; }
    public void setOuterSubitemId(String outerSubitemId) { this.outerSubitemId = outerSubitemId; }
    public String getComboItemsJson() { return comboItemsJson; }
    public void setComboItemsJson(String comboItemsJson) { this.comboItemsJson = comboItemsJson; }
    public String getVoucherScopeType() { return voucherScopeType; }
    public void setVoucherScopeType(String voucherScopeType) { this.voucherScopeType = voucherScopeType; }
    public String getVoucherScopeIds() { return voucherScopeIds; }
    public void setVoucherScopeIds(String voucherScopeIds) { this.voucherScopeIds = voucherScopeIds; }
    public String getGrouponPickRule() { return grouponPickRule; }
    public void setGrouponPickRule(String grouponPickRule) { this.grouponPickRule = grouponPickRule; }
    public Integer getGrouponActualCount() { return grouponActualCount; }
    public void setGrouponActualCount(Integer grouponActualCount) { this.grouponActualCount = grouponActualCount; }
    public Integer getDailyUseLimit() { return dailyUseLimit; }
    public void setDailyUseLimit(Integer dailyUseLimit) { this.dailyUseLimit = dailyUseLimit; }
    public String getRefundRuleType() { return refundRuleType; }
    public void setRefundRuleType(String refundRuleType) { this.refundRuleType = refundRuleType; }
    public String getPeriodType() { return periodType; }
    public void setPeriodType(String periodType) { this.periodType = periodType; }
    public Integer getPeriodCount() { return periodCount; }
    public void setPeriodCount(Integer periodCount) { this.periodCount = periodCount; }
    public java.util.Date getSaleStartDate() { return saleStartDate; }
    public void setSaleStartDate(java.util.Date saleStartDate) { this.saleStartDate = saleStartDate; }
    public java.util.Date getSaleEndDate() { return saleEndDate; }
    public void setSaleEndDate(java.util.Date saleEndDate) { this.saleEndDate = saleEndDate; }
    public Integer getConsumeStartDays() { return consumeStartDays; }
    public void setConsumeStartDays(Integer consumeStartDays) { this.consumeStartDays = consumeStartDays; }
    public Integer getConsumeValidDays() { return consumeValidDays; }
    public void setConsumeValidDays(Integer consumeValidDays) { this.consumeValidDays = consumeValidDays; }
    public Integer getConsumeStartToday() { return consumeStartToday; }
    public void setConsumeStartToday(Integer consumeStartToday) { this.consumeStartToday = consumeStartToday; }
    public Long getLimitPerUser() { return limitPerUser; }
    public void setLimitPerUser(Long limitPerUser) { this.limitPerUser = limitPerUser; }
    public Integer getMaxPerOrder() { return maxPerOrder; }
    public void setMaxPerOrder(Integer maxPerOrder) { this.maxPerOrder = maxPerOrder; }
    public Integer getMaxPersons() { return maxPersons; }
    public void setMaxPersons(Integer maxPersons) { this.maxPersons = maxPersons; }
    public String getRefundPolicy() { return refundPolicy; }
    public void setRefundPolicy(String refundPolicy) { this.refundPolicy = refundPolicy; }
    public Integer getBookingRequired() { return bookingRequired; }
    public void setBookingRequired(Integer bookingRequired) { this.bookingRequired = bookingRequired; }
    public Integer getBookingWorkdayOnly() { return bookingWorkdayOnly; }
    public void setBookingWorkdayOnly(Integer bookingWorkdayOnly) { this.bookingWorkdayOnly = bookingWorkdayOnly; }
    public String getCollectMethod() { return collectMethod; }
    public void setCollectMethod(String collectMethod) { this.collectMethod = collectMethod; }
    public Integer getMutexWithStorePromotion() { return mutexWithStorePromotion; }
    public void setMutexWithStorePromotion(Integer mutexWithStorePromotion) { this.mutexWithStorePromotion = mutexWithStorePromotion; }
    public String getExtraFeeDesc() { return extraFeeDesc; }
    public void setExtraFeeDesc(String extraFeeDesc) { this.extraFeeDesc = extraFeeDesc; }
    public String getOtherNotice() { return otherNotice; }
    public void setOtherNotice(String otherNotice) { this.otherNotice = otherNotice; }
    public java.math.BigDecimal getCommissionRate() { return commissionRate; }
    public void setCommissionRate(java.math.BigDecimal commissionRate) { this.commissionRate = commissionRate; }
    public java.math.BigDecimal getTotalValue() { return totalValue; }
    public void setTotalValue(java.math.BigDecimal totalValue) { this.totalValue = totalValue; }
    public String getSubitemPickRule() { return subitemPickRule; }
    public void setSubitemPickRule(String subitemPickRule) { this.subitemPickRule = subitemPickRule; }
    public Integer getRequireXiaoxin() { return requireXiaoxin; }
    public void setRequireXiaoxin(Integer requireXiaoxin) { this.requireXiaoxin = requireXiaoxin; }

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
