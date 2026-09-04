package com.ruoyi.biz.domain;

import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.annotation.Sensitive;
import com.ruoyi.common.enums.DesensitizedType;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 商户对象 biz_merchant
 *
 * <p>一个商户对应唯一小程序 appid，可拥有多个门店。</p>
 *
 * @author dytuangou
 */
public class Merchant extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 商户ID */
    private Long merchantId;

    /** 商户编号 */
    @Excel(name = "商户编号")
    private String merchantNo;

    /** 商户名称 */
    @Excel(name = "商户名称")
    private String merchantName;

    /** 所属代理商ID（0=平台直营） */
    private Long agentId;

    /** 所属代理商名称（展示用，非表字段） */
    @Excel(name = "所属代理商")
    private String agentName;

    /** 对应部门ID */
    private Long deptId;

    /** 商户Logo */
    private String logo;

    /** 联系人 */
    @Excel(name = "联系人")
    private String contact;

    /** 联系电话 */
    @Sensitive(desensitizedType = DesensitizedType.PHONE)
    @Excel(name = "联系电话")
    private String phone;

    /** 客服电话（门店未配时兜底） */
    @Excel(name = "客服电话")
    private String servicePhone;

    /** 客服二维码（门店未配时兜底） */
    @Excel(name = "客服二维码")
    private String serviceQrcode;

    /** 营业时间（门店未配时兜底） */
    @Excel(name = "营业时间")
    private String businessHours;

    /** 客服服务时间（门店未配时兜底） */
    @Excel(name = "客服服务时间")
    private String serviceHours;

    /** 商家简介 */
    @Excel(name = "商家简介")
    private String intro;

    /** 营业执照号 */
    private String licenseNo;

    /** 营业执照图片 */
    private String licenseImg;

    /** 小程序AppId */
    @Excel(name = "小程序AppId")
    private String appid;

    /** 小程序AppSecret */
    private String appSecret;

    /** 小程序接入方式（0商户自有密钥 1第三方平台代管） */
    private String mpAuthMode;

    /** 支付方式（0商户自有商户号 1平台统一收款） */
    private String payMode;

    /** 微信支付商户号 */
    private String payMchId;

    /** 微信支付AppId */
    private String payAppid;

    /** 微信支付证书序列号 */
    private String payCertSerial;

    /** 微信支付私钥路径 */
    private String payKeyPath;

    /** 微信支付APIv3密钥 */
    private String payApiV3Key;

    /** 支付回调地址 */
    private String payNotifyUrl;

    /** 联调mock开关（0开启 1关闭） */
    private String mockEnabled;

    /** 推客功能是否启用（1=启用 0=关闭） */
    private String promoterEnabled;

    /**
     * 商品详情页是否展示销量（1=展示 0=隐藏）。
     * 新品还没卖过就明晃晃写着「已售 0」，对商家是负面信号。
     */
    private String showSales;

    /**
     * 商品详情页是否展示库存（1=展示 0=隐藏）。
     * 有的商家不愿把余量透给顾客（剩得多会被读成“不好卖”）。
     */
    private String showStock;

    /** 服务到期时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date serviceExpire;

    /** 状态（0正常 1停用） */
    @Excel(name = "状态", readConverterExp = "0=正常,1=停用")
    private String status;

    /** 删除标志（0存在 2删除） */
    private String delFlag;

    public Long getMerchantId()
    {
        return merchantId;
    }

    public void setMerchantId(Long merchantId)
    {
        this.merchantId = merchantId;
    }

    /**
     * 「本次请求显式把 appid 提交为空」标记（非表字段，不落库）。
     *
     * <p>用来区分两种 appid==null：一是编辑商户名时 JSON 根本没带 appid 字段（不能动 appid），
     * 二是用户在微信配置里把 appid 清空要求解绑（必须置 NULL）。只凭 getAppid()==null 无法区分，
     * 误判会导致改个商户名就把小程序 appid 抹掉。</p>
     */
    private boolean appidCleared;

    public boolean isAppidCleared()
    {
        return appidCleared;
    }

    public void setAppidCleared(boolean appidCleared)
    {
        this.appidCleared = appidCleared;
    }

    /** 自动开通的老板登录账号（非表字段，仅新增商户时回带一次） */
    private String ownerUserName;

    /** 自动开通的老板初始密码明文（非表字段，不落库，仅新增时回带一次供平台交付给老板） */
    private String ownerInitPassword;

    public String getOwnerUserName()
    {
        return ownerUserName;
    }

    public void setOwnerUserName(String ownerUserName)
    {
        this.ownerUserName = ownerUserName;
    }

    public String getOwnerInitPassword()
    {
        return ownerInitPassword;
    }

    public void setOwnerInitPassword(String ownerInitPassword)
    {
        this.ownerInitPassword = ownerInitPassword;
    }

    public String getMerchantNo()
    {
        return merchantNo;
    }

    public void setMerchantNo(String merchantNo)
    {
        this.merchantNo = merchantNo;
    }

    public String getMerchantName()
    {
        return merchantName;
    }

    public void setMerchantName(String merchantName)
    {
        this.merchantName = merchantName;
    }

    public Long getAgentId()
    {
        return agentId;
    }

    public void setAgentId(Long agentId)
    {
        this.agentId = agentId;
    }

    public String getAgentName()
    {
        return agentName;
    }

    public void setAgentName(String agentName)
    {
        this.agentName = agentName;
    }

    public Long getDeptId()
    {
        return deptId;
    }

    public void setDeptId(Long deptId)
    {
        this.deptId = deptId;
    }

    public String getLogo()
    {
        return logo;
    }

    public void setLogo(String logo)
    {
        this.logo = logo;
    }

    public String getContact()
    {
        return contact;
    }

    public void setContact(String contact)
    {
        this.contact = contact;
    }

    public String getPhone()
    {
        return phone;
    }

    public void setPhone(String phone)
    {
        this.phone = phone;
    }

    public String getLicenseNo()
    {
        return licenseNo;
    }

    public void setLicenseNo(String licenseNo)
    {
        this.licenseNo = licenseNo;
    }

    public String getLicenseImg()
    {
        return licenseImg;
    }

    public void setLicenseImg(String licenseImg)
    {
        this.licenseImg = licenseImg;
    }

    public String getAppid()
    {
        return appid;
    }

    public void setAppid(String appid)
    {
        this.appid = appid;
    }

    public String getAppSecret()
    {
        return appSecret;
    }

    public void setAppSecret(String appSecret)
    {
        this.appSecret = appSecret;
    }

    public String getMpAuthMode()
    {
        return mpAuthMode;
    }

    public void setMpAuthMode(String mpAuthMode)
    {
        this.mpAuthMode = mpAuthMode;
    }

    public String getPayMode()
    {
        return payMode;
    }

    public void setPayMode(String payMode)
    {
        this.payMode = payMode;
    }

    public String getPayMchId()
    {
        return payMchId;
    }

    public void setPayMchId(String payMchId)
    {
        this.payMchId = payMchId;
    }

    public String getPayAppid()
    {
        return payAppid;
    }

    public void setPayAppid(String payAppid)
    {
        this.payAppid = payAppid;
    }

    public String getPayCertSerial()
    {
        return payCertSerial;
    }

    public void setPayCertSerial(String payCertSerial)
    {
        this.payCertSerial = payCertSerial;
    }

    public String getPayKeyPath()
    {
        return payKeyPath;
    }

    public void setPayKeyPath(String payKeyPath)
    {
        this.payKeyPath = payKeyPath;
    }

    public String getPayApiV3Key()
    {
        return payApiV3Key;
    }

    public void setPayApiV3Key(String payApiV3Key)
    {
        this.payApiV3Key = payApiV3Key;
    }

    public String getPayNotifyUrl()
    {
        return payNotifyUrl;
    }

    public void setPayNotifyUrl(String payNotifyUrl)
    {
        this.payNotifyUrl = payNotifyUrl;
    }

    public String getMockEnabled()
    {
        return mockEnabled;
    }

    public void setMockEnabled(String mockEnabled)
    {
        this.mockEnabled = mockEnabled;
    }

    public String getPromoterEnabled()
    {
        return promoterEnabled;
    }

    public void setPromoterEnabled(String promoterEnabled)
    {
        this.promoterEnabled = promoterEnabled;
    }

    public String getShowSales()
    {
        return showSales;
    }

    public void setShowSales(String showSales)
    {
        this.showSales = showSales;
    }

    public String getShowStock()
    {
        return showStock;
    }

    public void setShowStock(String showStock)
    {
        this.showStock = showStock;
    }

    public Date getServiceExpire()
    {
        return serviceExpire;
    }

    public void setServiceExpire(Date serviceExpire)
    {
        this.serviceExpire = serviceExpire;
    }

    public String getStatus()
    {
        return status;
    }

    public void setStatus(String status)
    {
        this.status = status;
    }

    public String getDelFlag()
    {
        return delFlag;
    }

    public void setDelFlag(String delFlag)
    {
        this.delFlag = delFlag;
    }

    public String getServicePhone() { return servicePhone; }
    public void setServicePhone(String servicePhone) { this.servicePhone = servicePhone; }
    public String getServiceQrcode() { return serviceQrcode; }
    public void setServiceQrcode(String serviceQrcode) { this.serviceQrcode = serviceQrcode; }
    public String getBusinessHours() { return businessHours; }

    public void setServiceHours(String serviceHours)
    {
        this.serviceHours = serviceHours;
    }

    public String getServiceHours()
    {
        return serviceHours;
    }
    public void setBusinessHours(String businessHours) { this.businessHours = businessHours; }
    public String getIntro() { return intro; }
    public void setIntro(String intro) { this.intro = intro; }

    @Override
    public String toString()
    {
        return new ToStringBuilder(this, ToStringStyle.MULTI_LINE_STYLE)
            .append("merchantId", getMerchantId())
            .append("merchantNo", getMerchantNo())
            .append("merchantName", getMerchantName())
            .append("agentId", getAgentId())
            .append("appid", getAppid())
            .append("status", getStatus())
            .toString();
    }
}
