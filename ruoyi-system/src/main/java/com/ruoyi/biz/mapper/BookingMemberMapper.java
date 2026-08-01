package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.biz.domain.BookingMember;

/**
 * 预约报名明细Mapper接口
 *
 * @author dytuangou
 */
public interface BookingMemberMapper
{
    /**
     * 查询报名明细
     */
    public BookingMember selectBookingMemberById(Long id);

    /**
     * 查询报名明细列表
     */
    public List<BookingMember> selectBookingMemberList(BookingMember bookingMember);

    /**
     * 统计场次报名条数
     */
    public int countByBookingId(Long bookingId);

    /**
     * 统计场次报名总人数
     */
    public Integer sumPeopleByBookingId(Long bookingId);

    /**
     * 新增报名明细
     */
    public int insertBookingMember(BookingMember bookingMember);

    /**
     * 修改报名明细
     */
    public int updateBookingMember(BookingMember bookingMember);

    /**
     * 删除报名明细
     */
    public int deleteBookingMemberById(Long id);

    /**
     * 按场次删除报名明细
     */
    public int deleteBookingMemberByBookingIds(Long[] bookingIds);
}
