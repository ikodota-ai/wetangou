package com.ruoyi.biz.domain;

import java.util.Date;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 商家员工邀请码 biz_merchant_staff_invite
 */
public class MerchantStaffInvite extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    private Long inviteId;
    private String inviteCode;
    private String scene;
    private String wxacodeUrl;
    private Long merchantId;
    private Long storeId;
    private String role;
    private Date expireAt;
    private Date usedAt;
    private Long usedBy;
    private String status;
    private String remark;
    private Date createTime;

    private String storeName;
    private String merchantName;
    private String usedByName;

    public Long getInviteId() { return inviteId; }
    public void setInviteId(Long inviteId) { this.inviteId = inviteId; }
    public String getInviteCode() { return inviteCode; }
    public void setInviteCode(String inviteCode) { this.inviteCode = inviteCode; }
    public String getScene() { return scene; }
    public void setScene(String scene) { this.scene = scene; }
    public String getWxacodeUrl() { return wxacodeUrl; }
    public void setWxacodeUrl(String wxacodeUrl) { this.wxacodeUrl = wxacodeUrl; }
    public Long getMerchantId() { return merchantId; }
    public void setMerchantId(Long merchantId) { this.merchantId = merchantId; }
    public Long getStoreId() { return storeId; }
    public void setStoreId(Long storeId) { this.storeId = storeId; }
    public String getRole() { return role; }
    public void setRole(String role) { this.role = role; }
    public Date getExpireAt() { return expireAt; }
    public void setExpireAt(Date expireAt) { this.expireAt = expireAt; }
    public Date getUsedAt() { return usedAt; }
    public void setUsedAt(Date usedAt) { this.usedAt = usedAt; }
    public Long getUsedBy() { return usedBy; }
    public void setUsedBy(Long usedBy) { this.usedBy = usedBy; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public String getRemark() { return remark; }
    public void setRemark(String remark) { this.remark = remark; }
    public Date getCreateTime() { return createTime; }
    public void setCreateTime(Date createTime) { this.createTime = createTime; }
    public String getStoreName() { return storeName; }
    public void setStoreName(String storeName) { this.storeName = storeName; }
    public String getMerchantName() { return merchantName; }
    public void setMerchantName(String merchantName) { this.merchantName = merchantName; }
    public String getUsedByName() { return usedByName; }
    public void setUsedByName(String usedByName) { this.usedByName = usedByName; }

    @Override
    public String toString() {
        return new ToStringBuilder(this, ToStringStyle.MULTI_LINE_STYLE)
            .append("inviteId", getInviteId())
            .append("inviteCode", getInviteCode())
            .append("merchantId", getMerchantId())
            .append("storeId", getStoreId())
            .toString();
    }
}
