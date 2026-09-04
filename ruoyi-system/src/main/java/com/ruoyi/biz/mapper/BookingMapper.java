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

    /**
     * 把预约日期已过去、却还挂在「开放中」的场次关掉。
     *
     * <p>为什么必须关：{@code /api/booking/slots} 统计某时段已约人数时按
     * 场次聚合，过期场次一直留在 status='0' 会让历史日期的容量持续被占；
     * 后台预约列表按状态筛「开放中」也会混进一堆去年的场次。</p>
     *
     * @return 关闭的场次数
     */
    @IgnoreTenant
    public int closeOverdueBookings();

    /**
     * 取消过期场次下仍处于「已报名」的报名记录。
     *
     * <p>只关场次不动报名，会员的「我的预约」里那条会永远显示「待确认」——
     * 因为列表文案取的是 {@code bookingStatus}/{@code status} 组合，
     * 场次关了但报名 status 还是 '0'，前端算出来仍是 wait 组。</p>
     *
     * @return 取消的报名数
     */
    @IgnoreTenant
    public int cancelOverdueBookingMembers();
}
