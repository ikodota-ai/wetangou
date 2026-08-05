package com.ruoyi.biz.domain;

import java.math.BigDecimal;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.annotation.Sensitive;
import com.ruoyi.common.enums.DesensitizedType;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 门店对象 biz_store
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public class Store extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 商户ID（多商户隔离字段） */
    private Long merchantId;

    /** 门店ID */
    private Long storeId;

    /** 门店名称 */
    @Excel(name = "门店名称")
    private String storeName;

    /** 门店Logo */
    @Excel(name = "门店Logo")
    private String logo;

    /** 省 */
    @Excel(name = "省")
    private String province;

    /** 市 */
    @Excel(name = "市")
    private String city;

    /** 区 */
    @Excel(name = "区")
    private String district;

    /** 详细地址 */
    @Excel(name = "详细地址")
    private String address;

    /** 经度 */
    @Excel(name = "经度")
    private BigDecimal longitude;

    /** 纬度 */
    @Excel(name = "纬度")
    private BigDecimal latitude;

    /** 门店电话 */
    @Sensitive(desensitizedType = DesensitizedType.PHONE)
    @Excel(name = "门店电话")
    private String phone;

    /** 客服电话 */
    @Sensitive(desensitizedType = DesensitizedType.PHONE)
    @Excel(name = "客服电话")
    private String servicePhone;

    /** 客服二维码 */
    @Excel(name = "客服二维码")
    private String serviceQrcode;

    /** 营业时间 */
    @Excel(name = "营业时间")
    private String businessHours;

    /** 客服服务时间 */
    @Excel(name = "客服服务时间")
    private String serviceHours;

    /** 门店简介 */
    @Excel(name = "门店简介")
    private String intro;

    /** 服务设置（字典biz_store_service，多选逗号分隔） */
    @Excel(name = "服务设置")
    private String services;

    /** 显示顺序 */
    @Excel(name = "显示顺序")
    private Integer sort;

    /** 状态（0正常 1停用） */
    @Excel(name = "状态", readConverterExp = "0=正常,1=停用")
    private String status;

    /** 删除标志（0存在 2删除） */
    private String delFlag;

    public void setStoreId(Long storeId) 
    {
        this.storeId = storeId;
    }

    public Long getStoreId() 
    {
        return storeId;
    }

    public void setStoreName(String storeName) 
    {
        this.storeName = storeName;
    }

    public String getStoreName() 
    {
        return storeName;
    }

    public void setLogo(String logo) 
    {
        this.logo = logo;
    }

    public String getLogo() 
    {
        return logo;
    }

    public void setProvince(String province) 
    {
        this.province = province;
    }

    public String getProvince() 
    {
        return province;
    }

    public void setCity(String city) 
    {
        this.city = city;
    }

    public String getCity() 
    {
        return city;
    }

    public void setDistrict(String district) 
    {
        this.district = district;
    }

    public String getDistrict() 
    {
        return district;
    }

    public void setAddress(String address) 
    {
        this.address = address;
    }

    public String getAddress() 
    {
        return address;
    }

    public void setLongitude(BigDecimal longitude) 
    {
        this.longitude = longitude;
    }

    public BigDecimal getLongitude() 
    {
        return longitude;
    }

    public void setLatitude(BigDecimal latitude) 
    {
        this.latitude = latitude;
    }

    public BigDecimal getLatitude() 
    {
        return latitude;
    }

    public void setPhone(String phone) 
    {
        this.phone = phone;
    }

    public String getPhone() 
    {
        return phone;
    }

    public void setServicePhone(String servicePhone) 
    {
        this.servicePhone = servicePhone;
    }

    public String getServicePhone() 
    {
        return servicePhone;
    }

    public void setServiceQrcode(String serviceQrcode) 
    {
        this.serviceQrcode = serviceQrcode;
    }

    public String getServiceQrcode() 
    {
        return serviceQrcode;
    }

    public void setBusinessHours(String businessHours) 
    {
        this.businessHours = businessHours;
    }

    public String getBusinessHours() 
    {
        return businessHours;
    }

    public void setServiceHours(String serviceHours)
    {
        this.serviceHours = serviceHours;
    }

    public String getServiceHours()
    {
        return serviceHours;
    }

    public void setIntro(String intro) 
    {
        this.intro = intro;
    }

    public String getIntro() 
    {
        return intro;
    }

    public void setServices(String services) 
    {
        this.services = services;
    }

    public String getServices() 
    {
        return services;
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
            .append("storeId", getStoreId())
            .append("storeName", getStoreName())
            .append("logo", getLogo())
            .append("province", getProvince())
            .append("city", getCity())
            .append("district", getDistrict())
            .append("address", getAddress())
            .append("longitude", getLongitude())
            .append("latitude", getLatitude())
            .append("phone", getPhone())
            .append("servicePhone", getServicePhone())
            .append("serviceQrcode", getServiceQrcode())
            .append("businessHours", getBusinessHours())
            .append("serviceHours", getServiceHours())
            .append("intro", getIntro())
            .append("services", getServices())
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

    /** 距离（米）— 仅供 /api/store/nearest 运行时计算用，不入库 */
    @com.ruoyi.common.annotation.Excel(name = "距离(米)")
    private java.math.BigDecimal distance;

    public java.math.BigDecimal getDistance() { return distance; }
    public void setDistance(java.math.BigDecimal distance) { this.distance = distance; }
}
