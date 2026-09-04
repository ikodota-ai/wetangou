package com.ruoyi.biz.domain;

import java.util.Date;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 商品类型字典 biz_product_type
 *
 * @author dytuangou
 * @date 2026-08-13
 */
public class ProductType extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 类型代码（GROUPON/VOUCHER/...） */
    private String typeCode;

    /** 类型名称 */
    private String typeName;

    /** 业务说明（给后台运营看的招商话术，不对顾客展示） */
    private String typeDesc;

    /**
     * 面向顾客的类型使用说明（商品详情页「……说明」卡的正文）。
     *
     * 与 typeDesc 分开：typeDesc 是「搭配自由，快速吸引顾客」这种写给商家看的招商话术，
     * 直接搬到顾客面前不知所云。原先这段文案硬编码在小程序 WXML 里（且只覆盖 5 种类型），
     * 运营想改一个字都得发版。
     */
    private String typeTips;

    /** 字段配置 JSON */
    private String fieldConfig;

    /** 类型图标 */
    private String icon;

    /** 显示顺序 */
    private Integer sort;

    /** App端是否可创建 0否 1是 */
    private Integer appCanCreate;

    /** 是否需要冷静期 0否 1是 */
    private Integer needLicense;

    /** 状态（0启用 1停用） */
    private String status;

    private Date createTime;
    private Date updateTime;

    public String getTypeCode() { return typeCode; }
    public void setTypeCode(String typeCode) { this.typeCode = typeCode; }
    public String getTypeName() { return typeName; }
    public void setTypeName(String typeName) { this.typeName = typeName; }
    public String getTypeDesc() { return typeDesc; }
    public void setTypeDesc(String typeDesc) { this.typeDesc = typeDesc; }

    public String getTypeTips() { return typeTips; }
    public void setTypeTips(String typeTips) { this.typeTips = typeTips; }
    public String getFieldConfig() { return fieldConfig; }
    public void setFieldConfig(String fieldConfig) { this.fieldConfig = fieldConfig; }
    public String getIcon() { return icon; }
    public void setIcon(String icon) { this.icon = icon; }
    public Integer getSort() { return sort; }
    public void setSort(Integer sort) { this.sort = sort; }
    public Integer getAppCanCreate() { return appCanCreate; }
    public void setAppCanCreate(Integer appCanCreate) { this.appCanCreate = appCanCreate; }
    public Integer getNeedLicense() { return needLicense; }
    public void setNeedLicense(Integer needLicense) { this.needLicense = needLicense; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public Date getCreateTime() { return createTime; }
    public void setCreateTime(Date createTime) { this.createTime = createTime; }
    public Date getUpdateTime() { return updateTime; }
    public void setUpdateTime(Date updateTime) { this.updateTime = updateTime; }

    @Override
    public String toString() {
        return new ToStringBuilder(this, ToStringStyle.MULTI_LINE_STYLE)
            .append("typeCode", getTypeCode())
            .append("typeName", getTypeName())
            .append("typeDesc", getTypeDesc())
            .append("sort", getSort())
            .toString();
    }
}
