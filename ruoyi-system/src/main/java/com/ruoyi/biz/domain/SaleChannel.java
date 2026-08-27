package com.ruoyi.biz.domain;

import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 投放渠道字典 biz_sale_channel
 *
 * <p>为什么要建成字典表而不是前端硬编码：抖音来客的「投放渠道」是一个独立子页，
 * 每个渠道条目下方都有各自的投放规则说明、并且按分组展示 —— 它是有业务语义的实体。
 * 原先 create.vue 里硬编码的 DOUPIN/TOUTIAO/OTHER 直接照抄了抖音来客的渠道名，
 * 与本项目（微信小程序生态）的实际分发场景不符，而且这个字段从未落库，
 * 没有存量兼容负担，所以本轮按自有场景重新定义。</p>
 */
public class SaleChannel extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 渠道代码 */
    private String channelCode;

    /** 渠道名称 */
    private String channelName;

    /** 渠道分组（前端按此分组展示：SELF自有/SOCIAL社交/OFFLINE线下） */
    private String channelGroup;

    /** 投放规则说明（前端字段级灰字提示） */
    private String channelDesc;

    /** 渠道图标 */
    private String icon;

    /** 显示顺序 */
    private Integer sort;

    /** 新建商品是否默认勾选 0否 1是 */
    private Integer isDefault;

    /** 状态（0启用 1停用） */
    private String status;

    public String getChannelCode() { return channelCode; }
    public void setChannelCode(String channelCode) { this.channelCode = channelCode; }
    public String getChannelName() { return channelName; }
    public void setChannelName(String channelName) { this.channelName = channelName; }
    public String getChannelGroup() { return channelGroup; }
    public void setChannelGroup(String channelGroup) { this.channelGroup = channelGroup; }
    public String getChannelDesc() { return channelDesc; }
    public void setChannelDesc(String channelDesc) { this.channelDesc = channelDesc; }
    public String getIcon() { return icon; }
    public void setIcon(String icon) { this.icon = icon; }
    public Integer getSort() { return sort; }
    public void setSort(Integer sort) { this.sort = sort; }
    public Integer getIsDefault() { return isDefault; }
    public void setIsDefault(Integer isDefault) { this.isDefault = isDefault; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
}
