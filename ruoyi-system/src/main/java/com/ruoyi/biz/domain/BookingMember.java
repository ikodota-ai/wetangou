package com.ruoyi.biz.domain;

import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.annotation.Sensitive;
import com.ruoyi.common.enums.DesensitizedType;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 预约报名明细对象 biz_booking_member
 *
 * @author dytuangou
 * @date 2026-07-24
 */
public class BookingMember extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 商户ID（多商户隔离字段） */
    private Long merchantId;

    /** 报名ID */
    private Long id;

    /** 预约场次ID */
    private Long bookingId;

    /** 报名会员ID */
    private Long memberId;

    /** 报名会员昵称（展示用，非表字段） */
    @Excel(name = "会员")
    private String memberName;

    /** 场次-服务名称（展示用，非表字段） */
    @Excel(name = "服务名称")
    private String serviceName;

    /** 场次-预约日期（展示用，非表字段） */
    @Excel(name = "预约日期")
    private String bookingDate;

    /** 场次-时段（展示用，非表字段） */
    @Excel(name = "时段")
    private String timeSlot;

    /** 场次-门店ID（查询用，非表字段） */
    private Long storeId;

    /** 场次-门店名称（展示用，非表字段） */
    @Excel(name = "门店")
    private String storeName;

    /** 场次-门店地址（展示用，非表字段） */
    private String storeAddress;

    /** 场次-门店客服电话（展示用，非表字段） */
    @Sensitive(desensitizedType = DesensitizedType.PHONE)
    private String storePhone;

    /** 场次-门店经度（展示用，非表字段） */
    private java.math.BigDecimal storeLongitude;

    /** 场次-门店纬度（展示用，非表字段） */
    private java.math.BigDecimal storeLatitude;

    /** 场次状态（0待确认 1已确认 2已完成 3已取消，展示用，非表字段） */
    private String bookingStatus;

    /** 场次编号（展示用，非表字段） */
    private String bookingNo;

    /** 联系人 */
    @Excel(name = "联系人")
    private String contact;

    /** 联系电话 */
    @Sensitive(desensitizedType = DesensitizedType.PHONE)
    @Excel(name = "联系电话")
    private String phone;

    /** 本条报名人数 */
    @Excel(name = "报名人数")
    private Integer people;

    /** 状态（0已报名 1已取消） */
    @Excel(name = "状态", readConverterExp = "0=已报名,1=已取消,2=已确认,3=已拒绝")
    private String status;


    /** 确认/拒绝员工用户名 */
    @Excel(name = "审核员工")
    private String confirmUser;

    /** 确认/拒绝时间 */
    @Excel(name = "审核时间")
    private java.util.Date confirmTime;

    /** 审核备注（拒绝原因/到场备注） */
    @Excel(name = "审核备注")
    private String reviewRemark;

    /**
     * 排除某个状态（用于"我的预约"默认不显示已取消的）
     * <p>此字段不持久化，仅作为 SQL 查询条件。</p>
     */
    private String notStatus;

    public String getNotStatus() { return notStatus; }
    public void setNotStatus(String notStatus) { this.notStatus = notStatus; }

    public void setId(Long id)
    {
        this.id = id;
    }

    public Long getId()
    {
        return id;
    }

    public void setBookingId(Long bookingId)
    {
        this.bookingId = bookingId;
    }

    public Long getBookingId()
    {
        return bookingId;
    }

    public void setMemberId(Long memberId)
    {
        this.memberId = memberId;
    }

    public Long getMemberId()
    {
        return memberId;
    }

    public void setMemberName(String memberName)
    {
        this.memberName = memberName;
    }

    public String getMemberName()
    {
        return memberName;
    }

    public void setServiceName(String serviceName)
    {
        this.serviceName = serviceName;
    }

    public String getServiceName()
    {
        return serviceName;
    }

    public void setBookingDate(String bookingDate)
    {
        this.bookingDate = bookingDate;
    }

    public String getBookingDate()
    {
        return bookingDate;
    }

    public void setTimeSlot(String timeSlot)
    {
        this.timeSlot = timeSlot;
    }

    public String getTimeSlot()
    {
        return timeSlot;
    }

    public void setStoreName(String storeName)
    {
        this.storeName = storeName;
    }

    public String getStoreName()
    {
        return storeName;
    }

    public void setStoreId(Long storeId)
    {
        this.storeId = storeId;
    }

    public Long getStoreId()
    {
        return storeId;
    }

    public void setContact(String contact)
    {
        this.contact = contact;
    }

    public String getContact()
    {
        return contact;
    }

    public void setPhone(String phone)
    {
        this.phone = phone;
    }

    public String getPhone()
    {
        return phone;
    }

    public void setPeople(Integer people)
    {
        this.people = people;
    }

    public Integer getPeople()
    {
        return people;
    }

    public void setStoreAddress(String storeAddress) 
    {
        this.storeAddress = storeAddress;
    }

    public String getStoreAddress() 
    {
        return storeAddress;
    }

    public void setStorePhone(String storePhone) 
    {
        this.storePhone = storePhone;
    }

    public String getStorePhone() 
    {
        return storePhone;
    }

    public void setStoreLongitude(java.math.BigDecimal storeLongitude) 
    {
        this.storeLongitude = storeLongitude;
    }

    public java.math.BigDecimal getStoreLongitude() 
    {
        return storeLongitude;
    }

    public void setStoreLatitude(java.math.BigDecimal storeLatitude) 
    {
        this.storeLatitude = storeLatitude;
    }

    public java.math.BigDecimal getStoreLatitude() 
    {
        return storeLatitude;
    }

    public void setBookingStatus(String bookingStatus) 
    {
        this.bookingStatus = bookingStatus;
    }

    public String getBookingStatus() 
    {
        return bookingStatus;
    }

    public void setBookingNo(String bookingNo) 
    {
        this.bookingNo = bookingNo;
    }

    public String getBookingNo() 
    {
        return bookingNo;
    }

    public void setStatus(String status)
    {
        this.status = status;
    }

    public String getStatus()
    {
        return status;
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
            .append("id", getId())
            .append("bookingId", getBookingId())
            .append("memberId", getMemberId())
            .append("memberName", getMemberName())
            .append("contact", getContact())
            .append("phone", getPhone())
            .append("people", getPeople())
            .append("status", getStatus())
            .append("createTime", getCreateTime())
            .toString();
    }

    public void setConfirmUser(String confirmUser)
    {
        this.confirmUser = confirmUser;
    }
    public String getConfirmUser()
    {
        return confirmUser;
    }

    public void setConfirmTime(java.util.Date confirmTime)
    {
        this.confirmTime = confirmTime;
    }
    public java.util.Date getConfirmTime()
    {
        return confirmTime;
    }

    public void setReviewRemark(String reviewRemark)
    {
        this.reviewRemark = reviewRemark;
    }
    public String getReviewRemark()
    {
        return reviewRemark;
    }

}
