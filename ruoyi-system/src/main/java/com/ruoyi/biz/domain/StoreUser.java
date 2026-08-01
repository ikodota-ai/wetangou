package com.ruoyi.biz.domain;

import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 账号门店关联对象 biz_store_user
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public class StoreUser extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 商户ID（多商户隔离字段） */
    private Long merchantId;

    /** 主键 */
    private Long id;

    /** 门店ID */
    @Excel(name = "门店ID")
    private Long storeId;

    /** 系统用户ID */
    @Excel(name = "系统用户ID")
    private Long userId;

    /** 门店名称（展示用，非表字段） */
    private String storeName;

    /** 系统用户名（展示用，非表字段） */
    private String userName;

    public void setId(Long id) 
    {
        this.id = id;
    }

    public Long getId() 
    {
        return id;
    }

    public void setStoreId(Long storeId) 
    {
        this.storeId = storeId;
    }

    public Long getStoreId() 
    {
        return storeId;
    }

    public void setUserId(Long userId) 
    {
        this.userId = userId;
    }

    public Long getUserId() 
    {
        return userId;
    }

    public void setStoreName(String storeName) { this.storeName = storeName; }

    public String getStoreName() { return storeName; }

    public void setUserName(String userName) { this.userName = userName; }

    public String getUserName() { return userName; }


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
            .append("id", getId())
            .append("storeId", getStoreId())
            .append("userId", getUserId())
            .append("createTime", getCreateTime())
            .toString();
    }
}
