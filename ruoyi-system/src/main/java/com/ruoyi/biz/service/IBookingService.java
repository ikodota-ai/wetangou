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

    /**
     * 关闭预约日期已过去、状态却还停在「开放中」的场次，并把这些场次下
     * 仍是「已报名」的报名记录一并置为已取消。
     *
     * <p>门店不会回头去手工关场次，于是后台预约列表筛「开放中」会混进一堆
     * 历史日期的场次，会员「我的预约」里去年的那条也永远显示「待确认」。</p>
     *
     * @return 下标 0 = 关闭的场次数，下标 1 = 取消的报名数
     */
    public int[] closeOverdueBookings();
}
