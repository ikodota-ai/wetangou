package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.common.annotation.IgnoreTenant;
import com.ruoyi.biz.domain.Booking;

/**
 * 在线预约场次Mapper接口
 *
 * @author dytuangou
 * @date 2026-07-24
 */
public interface BookingMapper
{
    /**
     * 查询在线预约场次
     */
    @IgnoreTenant
    public Booking selectBookingByBookingId(Long bookingId);

    /**
     * 查询在线预约场次列表
     */
    public List<Booking> selectBookingList(Booking booking);

    /**
     * 新增在线预约场次
     */
    public int insertBooking(Booking booking);

    /**
     * 修改在线预约场次
     */
    public int updateBooking(Booking booking);

    /**
     * 删除在线预约场次
     */
    public int deleteBookingByBookingId(Long bookingId);

    /**
     * 批量删除在线预约场次
     */
    public int deleteBookingByBookingIds(Long[] bookingIds);
}
