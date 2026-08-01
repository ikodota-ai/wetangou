package com.ruoyi.biz.domain;

import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 首页轮播图对象 biz_banner
 * <p>
 * 平台级 banner：可关联 merchantId=0（全平台可见）或具体 merchantId（指定商户可见）。
 * position 区分小程序首页 / 商户工作台 / 推客中心等。
 *
 * @author dytuangou
 * @date 2026-08-02
 */
public class Banner extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 商户ID（0=全平台） */
    private Long merchantId;

    /** Banner ID */
    private Long bannerId;

    /** 标题 */
    @Excel(name = "标题")
    private String title;

    /** 图片URL */
    @Excel(name = "图片URL")
    private String imageUrl;

    /** 跳转链接（小程序页面路径或外链） */
    @Excel(name = "跳转链接")
    private String linkUrl;

    /** 位置（home / agent / distributor） */
    @Excel(name = "位置")
    private String position;

    /** 状态（0启用 1停用） */
    @Excel(name = "状态", readConverterExp = "0=启用,1=停用")
    private String status;

    /** 显示顺序 */
    @Excel(name = "显示顺序")
    private Integer sort;

    /** 生效时间 */
    @Excel(name = "生效时间")
    private java.util.Date activeFrom;

    /** 失效时间 */
    @Excel(name = "失效时间")
    private java.util.Date activeTo;

    public Long getMerchantId() { return merchantId; }
    public void setMerchantId(Long merchantId) { this.merchantId = merchantId; }

    public Long getBannerId() { return bannerId; }
    public void setBannerId(Long bannerId) { this.bannerId = bannerId; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }

    public String getLinkUrl() { return linkUrl; }
    public void setLinkUrl(String linkUrl) { this.linkUrl = linkUrl; }

    public String getPosition() { return position; }
    public void setPosition(String position) { this.position = position; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public Integer getSort() { return sort; }
    public void setSort(Integer sort) { this.sort = sort; }

    public java.util.Date getActiveFrom() { return activeFrom; }
    public void setActiveFrom(java.util.Date activeFrom) { this.activeFrom = activeFrom; }

    public java.util.Date getActiveTo() { return activeTo; }
    public void setActiveTo(java.util.Date activeTo) { this.activeTo = activeTo; }

    @Override
    public String toString() {
        return new ToStringBuilder(this, ToStringStyle.MULTI_LINE_STYLE)
            .append("bannerId", getBannerId())
            .append("merchantId", getMerchantId())
            .append("title", getTitle())
            .append("imageUrl", getImageUrl())
            .append("position", getPosition())
            .append("status", getStatus())
            .append("sort", getSort())
            .toString();
    }
}
