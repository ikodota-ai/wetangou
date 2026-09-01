package com.ruoyi.biz.service;

import java.util.List;
import java.util.Map;
import com.ruoyi.biz.domain.Booking;
import com.ruoyi.biz.domain.BookingMember;

/**
 * 在线预约场次Service接口
 *
 * @author dytuangou
 * @date 2026-07-24
 */
public interface IBookingService
{
    /**
     * 查询在线预约场次（含报名明细）
     */
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
     * 批量删除在线预约场次（同时删除报名明细）
     */
    public int deleteBookingByBookingIds(Long[] bookingIds);

    /**
     * 删除在线预约场次（同时删除报名明细）
     */
    public int deleteBookingByBookingId(Long bookingId);

    /**
     * 查询报名明细列表
     */
    public List<BookingMember> selectBookingMemberList(BookingMember bookingMember);

    /**
     * 查询单条报名明细
     */
    public BookingMember selectBookingMemberById(Long id);

    /**
     * 会员报名（新增一条报名明细）
     */
    public int signup(BookingMember bookingMember);

    /**
     * 更新报名明细
     */
    public int updateBookingMember(BookingMember bookingMember);

    /**
     * 查询门店某天的可预约时段
     *
     * <p>按门店营业时间切分时段，扣除已满与已过期的时段，供小程序预约页直接渲染。</p>
     *
     * @param storeId 门店ID
     * @param date 预约日期（yyyy-MM-dd，为空取今天）
     * @return 时段信息（含白天/晚上分组与剩余可约数）
     */
    public Map<String, Object> selectAvailableSlots(Long storeId, String date);

    /**
     * 查询门店可预约日期列表
     *
     * <p>天数取门店 booking_ahead_days（原先小程序写死 7 天），
     * 并按 booking_closed_days 标出歇业日。</p>
     *
     * @param storeId 门店 ID
     * @return aheadDays / closedDays / openCount / days[{date,label,weekday,weekdayText,closed,closedReason}]
     */
    public Map<String, Object> selectBookableDays(Long storeId);

    /**
     * 校验某门店某日某时段是否真的可以被预约，不可约直接抛 ServiceException
     *
     * <p>为什么单独提出来：可约范围原先只在小程序端拦（日期条置灰、时段标 closed），
     * 直接 POST /api/booking 时后端一律放行，歇业日、超出可提前天数的日期、
     * 已过去的日期、营业时间外的时刻、甚至非法时段串都能落库。</p>
     *
     * @param storeId  门店 ID
     * @param date     预约日期 yyyy-MM-dd
     * @param timeSlot 时段，"10:00" 或 "10:00-11:00"
     */
    public void assertSlotBookable(Long storeId, String date, String timeSlot);
}
