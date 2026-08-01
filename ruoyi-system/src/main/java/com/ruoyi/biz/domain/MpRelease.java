package com.ruoyi.biz.domain;

import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 小程序发布记录对象 biz_mp_release
 *
 * <p>记录一次「代上传 → 体验版 → 提审 → 发布」的全流程状态。
 * 真正调用微信第三方平台接口需完成开放平台认证，当前先提供留痕与状态流转。</p>
 *
 * @author dytuangou
 */
public class MpRelease extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 发布ID */
    private Long releaseId;

    /** 商户ID */
    private Long merchantId;

    /** 商户名称（关联查询） */
    @Excel(name = "商户")
    private String merchantName;

    /** 小程序AppId */
    @Excel(name = "小程序AppId")
    private String appid;

    /** 代码模板ID */
    private String templateId;

    /** 版本号 */
    @Excel(name = "版本号")
    private String userVersion;

    /** 版本描述 */
    @Excel(name = "版本描述")
    private String userDesc;

    /** 提交时使用的ext.json */
    private String extJson;

    /** 微信审核单号 */
    private String auditId;

    /** 审核状态（0待提交 1审核中 2审核通过 3审核失败 4已撤回） */
    @Excel(name = "审核状态", readConverterExp = "0=待提交,1=审核中,2=审核通过,3=审核失败,4=已撤回")
    private String auditStatus;

    /** 审核失败原因 */
    private String auditReason;

    /** 发布状态（0未发布 1已发布 2已回退） */
    @Excel(name = "发布状态", readConverterExp = "0=未发布,1=已发布,2=已回退")
    private String releaseStatus;

    /** 发布时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    @Excel(name = "发布时间", width = 30, dateFormat = "yyyy-MM-dd HH:mm:ss")
    private Date releaseTime;

    /** 体验版二维码 */
    private String qrcodeUrl;

    public Long getReleaseId()
    {
        return releaseId;
    }

    public void setReleaseId(Long releaseId)
    {
        this.releaseId = releaseId;
    }

    public Long getMerchantId()
    {
        return merchantId;
    }

    public void setMerchantId(Long merchantId)
    {
        this.merchantId = merchantId;
    }

    public String getMerchantName()
    {
        return merchantName;
    }

    public void setMerchantName(String merchantName)
    {
        this.merchantName = merchantName;
    }

    public String getAppid()
    {
        return appid;
    }

    public void setAppid(String appid)
    {
        this.appid = appid;
    }

    public String getTemplateId()
    {
        return templateId;
    }

    public void setTemplateId(String templateId)
    {
        this.templateId = templateId;
    }

    public String getUserVersion()
    {
        return userVersion;
    }

    public void setUserVersion(String userVersion)
    {
        this.userVersion = userVersion;
    }

    public String getUserDesc()
    {
        return userDesc;
    }

    public void setUserDesc(String userDesc)
    {
        this.userDesc = userDesc;
    }

    public String getExtJson()
    {
        return extJson;
    }

    public void setExtJson(String extJson)
    {
        this.extJson = extJson;
    }

    public String getAuditId()
    {
        return auditId;
    }

    public void setAuditId(String auditId)
    {
        this.auditId = auditId;
    }

    public String getAuditStatus()
    {
        return auditStatus;
    }

    public void setAuditStatus(String auditStatus)
    {
        this.auditStatus = auditStatus;
    }

    public String getAuditReason()
    {
        return auditReason;
    }

    public void setAuditReason(String auditReason)
    {
        this.auditReason = auditReason;
    }

    public String getReleaseStatus()
    {
        return releaseStatus;
    }

    public void setReleaseStatus(String releaseStatus)
    {
        this.releaseStatus = releaseStatus;
    }

    public Date getReleaseTime()
    {
        return releaseTime;
    }

    public void setReleaseTime(Date releaseTime)
    {
        this.releaseTime = releaseTime;
    }

    public String getQrcodeUrl()
    {
        return qrcodeUrl;
    }

    public void setQrcodeUrl(String qrcodeUrl)
    {
        this.qrcodeUrl = qrcodeUrl;
    }
}
