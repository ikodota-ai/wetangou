package com.ruoyi.web.api;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.alibaba.fastjson2.JSONObject;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.biz.api.domain.LoginMember;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.biz.api.annotation.LoginRequired;
import com.ruoyi.biz.api.util.MemberContextHolder;
import com.ruoyi.biz.domain.Booking;
import com.ruoyi.biz.domain.BookingMember;
import com.ruoyi.biz.domain.Booking;
import com.ruoyi.biz.service.IBookingService;

/**
 * 小程序-在线预约（场次报名）
 *
 * <p>预约为「场次 + 报名」模型：会员选择门店/服务/日期/时段进行报名，
 * 若无对应场次则自动创建场次，再写入一条本人报名明细；一个场次可多人报名。</p>
 *
 * @author dytuangou
 */
@Anonymous
@RestController
@RequestMapping("/api/booking")
public class ApiBookingController
{
    @Autowired
    private IBookingService bookingService;

    /**
     * 门店某天的可预约时段
     *
     * <p>匿名可访问，便于未登录用户先看时段再登录下单。</p>
     *
     * @param storeId 门店ID
     * @param date 预约日期（yyyy-MM-dd，缺省取今天）
     */
    @GetMapping("/slots")
    public AjaxResult slots(@RequestParam Long storeId,
            @RequestParam(required = false) String date)
    {
        return AjaxResult.success(bookingService.selectAvailableSlots(storeId, date));
    }

    /**
     * 会员报名预约
     */
    @LoginRequired
    @PostMapping
    public AjaxResult create(@RequestBody JSONObject body)
    {
        Long memberId = MemberContextHolder.getMemberId();
        Long bookingId = body.getLong("bookingId");

        // 未指定场次时，按门店/服务/日期/时段复用或自动建场次
        if (bookingId == null)
        {
            Long storeId = body.getLong("storeId");
            if (storeId == null)
            {
                throw new ServiceException("门店不能为空");
            }
            Date bookingDate = body.getDate("bookingDate");
            String timeSlot = body.getString("timeSlot");
            if (bookingDate == null || StringUtils.isEmpty(timeSlot))
            {
                throw new ServiceException("预约日期与时段必填");
            }

            // 同门店同日同时段已有场次时直接复用，避免每人报名都新建一个场次
            Booking query = new Booking();
            query.setStoreId(storeId);
            query.setBookingDate(bookingDate);
            query.setTimeSlot(timeSlot);
            List<Booking> exists = bookingService.selectBookingList(query);
            Booking reuse = null;
            for (Booking item : exists)
            {
                if (!"3".equals(item.getStatus()))
                {
                    reuse = item;
                    break;
                }
            }
            if (reuse != null)
            {
                bookingId = reuse.getBookingId();
            }
            else
            {
                Booking booking = new Booking();
                booking.setStoreId(storeId);
                booking.setProductId(body.getLong("productId"));
                booking.setServiceName(body.getString("serviceName"));
                booking.setBookingDate(bookingDate);
                booking.setTimeSlot(timeSlot);
                booking.setBookingNo("B" + System.currentTimeMillis() + (int) (Math.random() * 900 + 100));
                booking.setStatus("0");
                bookingService.insertBooking(booking);
                bookingId = booking.getBookingId();
            }
        }

        // 同一会员在同一场次只保留一条有效报名，避免连点重复占位
        BookingMember existsQuery = new BookingMember();
        existsQuery.setBookingId(bookingId);
        existsQuery.setMemberId(memberId);
        existsQuery.setStatus("0");
        if (!bookingService.selectBookingMemberList(existsQuery).isEmpty())
        {
            throw new ServiceException("您已预约该时段，可在我的预约中查看");
        }

        BookingMember signup = new BookingMember();
        signup.setBookingId(bookingId);
        signup.setMemberId(memberId);
        signup.setContact(body.getString("contact"));
        signup.setPhone(body.getString("phone"));
        Integer people = body.getInteger("people");
        signup.setPeople(people == null ? 1 : people);
        signup.setRemark(body.getString("remark"));
        signup.setStatus("0");
        bookingService.signup(signup);

        AjaxResult ajax = AjaxResult.success();
        ajax.put("bookingId", bookingId);
        ajax.put("signupId", signup.getId());
        return ajax;
    }

    /**
     * 我的预约列表（我报名过的场次明细）
     *
     * <p>自己看自己 → phone 明文；过滤 status=2（已取消）默认排除，避免列表噪音。</p>
     */
    @LoginRequired
    @GetMapping("/list")
    public AjaxResult list(@RequestParam(required = false) String status)
    {
        BookingMember query = new BookingMember();
        query.setMemberId(MemberContextHolder.getMemberId());
        if (status == null || status.isEmpty()) {
            // 默认排除已取消
            query.setNotStatus("2");
        } else {
            query.setStatus(status);
        }
        List<BookingMember> list = bookingService.selectBookingMemberList(query);
        java.util.List<java.util.Map<String, Object>> rows = new java.util.ArrayList<>();
        for (BookingMember signup : list) {
            java.util.Map<String, Object> vo = new java.util.LinkedHashMap<>();
            vo.put("id", signup.getId());
            vo.put("bookingId", signup.getBookingId());
            vo.put("memberId", signup.getMemberId());
            vo.put("contact", signup.getContact());
            vo.put("phone", signup.getPhone());
            vo.put("people", signup.getPeople());
            vo.put("status", signup.getStatus());
            vo.put("confirmUser", signup.getConfirmUser());
            vo.put("confirmTime", signup.getConfirmTime());
            vo.put("createTime", signup.getCreateTime());
            // 兼容字段：前端 booking/detail 用 bookingStatus
            vo.put("bookingStatus", signup.getStatus());
            rows.add(vo);
        }
        return AjaxResult.success(rows);
    }

    /**
     * 我的单条预约详情
     *
     * <p>小程序详情页用，仅允许查看本人报名，避免越权读取他人联系方式。</p>
     * <p>自己看自己 → phone 明文；不返回实体，避免 @Sensitive 把它变 138****0000。</p>
     */
    @LoginRequired
    @GetMapping("/signup/{signupId}")
    public AjaxResult signupDetail(@PathVariable Long signupId)
    {
        BookingMember signup = bookingService.selectBookingMemberById(signupId);
        if (signup == null || !signup.getMemberId().equals(MemberContextHolder.getMemberId()))
        {
            throw new ServiceException("预约记录不存在");
        }
        java.util.Map<String, Object> vo = new java.util.LinkedHashMap<>();
        vo.put("id", signup.getId());
        vo.put("bookingId", signup.getBookingId());
        vo.put("memberId", signup.getMemberId());
        vo.put("contact", signup.getContact());
        vo.put("phone", signup.getPhone());   // 明文
        vo.put("people", signup.getPeople());
        vo.put("status", signup.getStatus());
        vo.put("confirmUser", signup.getConfirmUser());
        vo.put("confirmTime", signup.getConfirmTime());
        vo.put("reviewRemark", signup.getReviewRemark());
        vo.put("remark", signup.getRemark());
        vo.put("createTime", signup.getCreateTime());
        return AjaxResult.success(vo);
    }

    /**
     * 预约场次详情
     *
     * <p>场次可被多人报名，此处只回传本人的报名明细，
     * 其他会员的联系人与手机号不对外暴露。</p>
     */
    @LoginRequired
    @GetMapping("/{bookingId}")
    public AjaxResult detail(@PathVariable Long bookingId)
    {
        Booking booking = bookingService.selectBookingByBookingId(bookingId);
        if (booking == null)
        {
            throw new ServiceException("预约场次不存在");
        }
        Long memberId = MemberContextHolder.getMemberId();
        List<BookingMember> mine = new ArrayList<BookingMember>();
        if (booking.getBookingMembers() != null)
        {
            for (BookingMember item : booking.getBookingMembers())
            {
                if (memberId.equals(item.getMemberId()))
                {
                    mine.add(item);
                }
            }
        }
        booking.setBookingMembers(mine);
        return AjaxResult.success(booking);
    }

    /**
     * 取消我的报名
     */
    /**
     * 会员或门店端取消报名
     *
     * <p>会员可以取消自己的报名；门店端员工可以代会员取消（需校验门店归属）。
     * 取消动作由请求头 userType 决定：member 走本人校验，store 走门店归属校验。</p>
     */
    @LoginRequired
    @PostMapping("/cancel/{signupId}")
    public AjaxResult cancel(@PathVariable Long signupId)
    {
        BookingMember signup = bookingService.selectBookingMemberById(signupId);
        if (signup == null)
        {
            throw new ServiceException("预约记录不存在");
        }
        if ("1".equals(signup.getStatus()))
        {
            throw new ServiceException("该预约已取消");
        }
        if ("2".equals(signup.getBookingStatus()))
        {
            throw new ServiceException("已完成的预约不能取消");
        }
        LoginMember loginMember = MemberContextHolder.get();
        if ("store".equals(loginMember.getUserType()))
        {
            // 门店端：必须是该场次所属门店的员工
            Booking booking = bookingService.selectBookingByBookingId(signup.getBookingId());
            if (booking == null || !loginMember.getStoreId().equals(booking.getStoreId()))
            {
                throw new ServiceException("仅场次所属门店可代取消");
            }
        }
        else
        {
            // 普通会员：只能取消自己的报名
            if (!signup.getMemberId().equals(loginMember.getMemberId()))
            {
                throw new ServiceException("预约记录不存在");
            }
        }
        BookingMember update = new BookingMember();
        update.setId(signupId);
        update.setStatus("1");
        bookingService.updateBookingMember(update);
        return AjaxResult.success();
    }
}
