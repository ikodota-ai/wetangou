package com.ruoyi.biz.domain;

import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 小程序第三方平台授权对象 biz_mp_auth
 * 
 * @author dytuangou
 * @date 2026-08-02
 */
public class MpAuth extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 授权ID */
    private Long authId;

    /** 商户ID */
    @Excel(name = "商户ID")
    private Long merchantId;

    /** 商户名称（联表） */
    @Excel(name = "商户名称")
    private String merchantName;

    /** 授权方小程序AppId */
    @Excel(name = "AppId")
    private String appid;

    /** 小程序名称 */
    @Excel(name = "小程序名称")
    private String nickName;

    /** 小程序头像 */
    private String headImg;

    /** 主体名称 */
    @Excel(name = "主体名称")
    private String principalName;

    /** 认证类型 */
    @Excel(name = "认证类型")
    private String verifyType;

    /** 授权方刷新令牌（长期有效，需加密存储） */
    private String refreshToken;

    /** 已授权权限集ID列表（逗号分隔） */
    private String funcInfo;

    /** 授权状态 */
    @Excel(name = "授权状态", readConverterExp = "0=已授权,1=已取消,2=已过期")
    private String authStatus;

    /** 授权时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    @Excel(name = "授权时间", width = 30, dateFormat = "yyyy-MM-dd")
    private Date authTime;

    public void setAuthId(Long authId) { this.authId = authId; }
    public Long getAuthId() { return authId; }
    public void setMerchantId(Long merchantId) { this.merchantId = merchantId; }
    public Long getMerchantId() { return merchantId; }
    public void setMerchantName(String merchantName) { this.merchantName = merchantName; }
    public String getMerchantName() { return merchantName; }
    public void setAppid(String appid) { this.appid = appid; }
    public String getAppid() { return appid; }
    public void setNickName(String nickName) { this.nickName = nickName; }
    public String getNickName() { return nickName; }
    public void setHeadImg(String headImg) { this.headImg = headImg; }
    public String getHeadImg() { return headImg; }
    public void setPrincipalName(String principalName) { this.principalName = principalName; }
    public String getPrincipalName() { return principalName; }
    public void setVerifyType(String verifyType) { this.verifyType = verifyType; }
    public String getVerifyType() { return verifyType; }
    public void setRefreshToken(String refreshToken) { this.refreshToken = refreshToken; }
    public String getRefreshToken() { return refreshToken; }
    public void setFuncInfo(String funcInfo) { this.funcInfo = funcInfo; }
    public String getFuncInfo() { return funcInfo; }
    public void setAuthStatus(String authStatus) { this.authStatus = authStatus; }
    public String getAuthStatus() { return authStatus; }
    public void setAuthTime(Date authTime) { this.authTime = authTime; }
    public Date getAuthTime() { return authTime; }

    @Override
    public String toString() {
        return new ToStringBuilder(this, ToStringStyle.MULTI_LINE_STYLE)
                .append("authId", getAuthId())
                .append("merchantId", getMerchantId())
                .append("appid", getAppid())
                .append("nickName", getNickName())
                .append("authStatus", getAuthStatus())
                .append("authTime", getAuthTime())
                .toString();
    }
}
