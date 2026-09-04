package com.ruoyi.biz.domain;

import java.util.Date;
import java.util.List;
import com.fasterxml.jackson.annotation.JsonFormat;
import org.apache.commons.lang3.builder.ToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 在线预约场次对象 biz_booking
 *
 * <p>预约改造为「场次 + 报名明细」：主表描述一个可预约的场次（门店/服务/日期/时段），
 * 会员报名写入 {@link BookingMember}，一个场次可被多个会员报名。</p>
 *
 * @author dytuangou
 * @date 2026-07-24
 */
public class Booking extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 商户ID（多商户隔离字段） */
    private Long merchantId;

    /** 预约场次ID */
    private Long bookingId;

    /** 预约场次编号 */
    @Excel(name = "预约编号")
    private String bookingNo;

    /** 门店ID */
    private Long storeId;

    /** 门店名称（展示用，非表字段） */
    @Excel(name = "门店")
    private String storeName;

    /** 预约服务/商品ID */
    private Long productId;

    /**
     * 预约项目名（= 关联 BOOKING 商品的商品名）。
     *
     * <p>列名还是 service_name，但语义已收口：不再是任人填的自由文本，
     * 由 ApiBookingController.resolveItemName 按 product_id 查商品名写入。
     * 原先它存的是字典 biz_booking_type 的类型名（「堂食预约」），
     * 和真正上架的预约商品是两回事。</p>
     */
    @Excel(name = "预约项目")
    private String serviceName;

    /** 预约日期 */
    // 库里 booking_date 是 DATE 类型（无时分秒），前端日期选择器发的也是 "2026-08-31"。
    // 原来按 "yyyy-MM-dd HH:mm:ss" 反序列化，新增预约直接 400：
    // Cannot deserialize value of type java.util.Date from String "2026-08-31"。
    @JsonFormat(pattern = "yyyy-MM-dd")
    @Excel(name = "预约日期", width = 30, dateFormat = "yyyy-MM-dd")
    private Date bookingDate;

    /** 预约时段 */
    @Excel(name = "预约时段")
    private String timeSlot;

    /** 状态（0开放中 1已确认 2已完成 3已关闭） */
    @Excel(name = "状态", readConverterExp = "0=开放中,1=已确认,2=已完成,3=已关闭")
    private String status;

    /** 已报名条数（聚合，非表字段） */
    @Excel(name = "报名人次")
    private Integer signupCount;

    /** 已报名总人数（聚合，非表字段） */
    @Excel(name = "报名总人数")
    private Integer signupPeople;

    /** 报名明细（详情用，非表字段） */
    private List<BookingMember> bookingMembers;

    public void setBookingId(Long bookingId)
    {
        this.bookingId = bookingId;
    }

    public Long getBookingId()
    {
        return bookingId;
    }

    public void setBookingNo(String bookingNo)
    {
        this.bookingNo = bookingNo;
    }

    public String getBookingNo()
    {
        return bookingNo;
    }

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

    public void setProductId(Long productId)
    {
        this.productId = productId;
    }

    public Long getProductId()
    {
        return productId;
    }

    public void setServiceName(String serviceName)
    {
        this.serviceName = serviceName;
    }

    public String getServiceName()
    {
        return serviceName;
    }

    public void setBookingDate(Date bookingDate)
    {
        this.bookingDate = bookingDate;
    }

    public Date getBookingDate()
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

    public void setStatus(String status)
    {
        this.status = status;
    }

    public String getStatus()
    {
        return status;
    }

    public void setSignupCount(Integer signupCount)
    {
        this.signupCount = signupCount;
    }

    public Integer getSignupCount()
    {
        return signupCount;
    }

    public void setSignupPeople(Integer signupPeople)
    {
        this.signupPeople = signupPeople;
    }

    public Integer getSignupPeople()
    {
        return signupPeople;
    }

    public void setBookingMembers(List<BookingMember> bookingMembers)
    {
        this.bookingMembers = bookingMembers;
    }

    public List<BookingMember> getBookingMembers()
    {
        return bookingMembers;
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
            .append("bookingId", getBookingId())
            .append("bookingNo", getBookingNo())
            .append("storeId", getStoreId())
            .append("productId", getProductId())
            .append("serviceName", getServiceName())
            .append("bookingDate", getBookingDate())
            .append("timeSlot", getTimeSlot())
            .append("status", getStatus())
            .append("signupCount", getSignupCount())
            .append("signupPeople", getSignupPeople())
            .append("remark", getRemark())
            .append("createBy", getCreateBy())
            .append("createTime", getCreateTime())
            .append("updateBy", getUpdateBy())
            .append("updateTime", getUpdateTime())
            .toString();
    }
}
