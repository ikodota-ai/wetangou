package com.ruoyi.web.api;

import java.util.Calendar;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.biz.api.annotation.StoreStaffRequired;
import com.ruoyi.biz.api.domain.LoginMember;
import com.ruoyi.biz.api.util.MemberContextHolder;
import com.ruoyi.biz.domain.Booking;
import com.ruoyi.biz.domain.BookingMember;
import com.ruoyi.biz.domain.Order;
import com.ruoyi.biz.domain.PayBill;
import com.ruoyi.biz.domain.Store;
import com.ruoyi.biz.mapper.MerchantMapper;
import com.ruoyi.biz.service.IBookingService;
import com.ruoyi.biz.service.IOrderService;
import com.ruoyi.biz.service.IPayBillService;
import com.ruoyi.biz.service.IStoreService;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.system.service.ISysUserService;

/**
 * 小程序门店端-员工工作台（核销台/今日数据/预约审核）
 *
 * <p>所有端点都用 {@code @StoreStaffRequired} 走 MemberAuthInterceptor，
 * 校验 userType=store + storeId 与 token 一致；token 失效直接 401。</p>
 *
 * @author dytuangou
 */
@Anonymous
@RestController
@RequestMapping("/api/store/staff")
public class ApiStoreStaffDashboardController
{
    @Autowired
    private IOrderService orderService;

    @Autowired
    private IPayBillService payBillService;

    @Autowired
    private IBookingService bookingService;

    @Autowired
    private IStoreService storeService;

    @Autowired
    private MerchantMapper merchantMapper;

    @Autowired
    private ISysUserService userService;

    /**
     * 当前登录员工个人信息 + 所属门店
     */
    @StoreStaffRequired
    @GetMapping("/me")
    public AjaxResult me()
    {
        LoginMember m = MemberContextHolder.get();
        SysUser user = userService.selectUserById(m.getMemberId());
        Store store = storeService.selectStoreByStoreId(m.getStoreId());

        Map<String, Object> data = new HashMap<>();
        data.put("userType", "store");
        data.put("userId", m.getMemberId());
        data.put("realName", user == null ? "" : (user.getNickName() == null ? user.getUserName() : user.getNickName()));
        data.put("userName", user == null ? "" : user.getUserName());
        data.put("avatar", user == null ? "" : (user.getAvatar() == null ? "" : user.getAvatar()));
        data.put("storeId", m.getStoreId());
        data.put("storeName", store == null ? "" : store.getStoreName());
        data.put("merchantId", m.getMerchantId());
        return AjaxResult.success(data);
    }

    /**
     * 工作台首页聚合数据：今日核销数 / 核销金额 / 待确认买单 / 待审核预约 / 最近 5 单
     */
    @StoreStaffRequired
    @GetMapping("/home")
    public AjaxResult home()
    {
        LoginMember m = MemberContextHolder.get();
        Long storeId = m.getStoreId();
        Date todayStart = startOfToday();
        Date todayEnd = endOfToday();
        Store store = storeService.selectStoreByStoreId(storeId);

        // 1) 今日核销：order.status=2 + verify_time 在今天
        Order q1 = new Order();
        q1.setStoreId(storeId);
        q1.setStatus("2");
        List<Order> verifiedToday = orderService.selectOrderList(q1);
        int verifyCount = 0;
        java.math.BigDecimal verifyAmount = java.math.BigDecimal.ZERO;
        for (Order o : verifiedToday)
        {
            if (o.getVerifyTime() != null && !o.getVerifyTime().before(todayStart) && o.getVerifyTime().before(todayEnd))
            {
                verifyCount++;
                if (o.getPayAmount() != null)
                {
                    verifyAmount = verifyAmount.add(o.getPayAmount());
                }
            }
        }

        // 2) 今日新订单（待使用 status=1）
        Order q2 = new Order();
        q2.setStoreId(storeId);
        q2.setStatus("1");
        List<Order> unusedList = orderService.selectOrderList(q2);
        int unusedCount = 0;
        for (Order o : unusedList)
        {
            if (o.getPayTime() != null && !o.getPayTime().before(todayStart) && o.getPayTime().before(todayEnd))
            {
                unusedCount++;
            }
        }

        // 3) 待确认买单 status=0
        PayBill bq = new PayBill();
        bq.setStoreId(storeId);
        bq.setStatus("0");
        int pendingBillCount = payBillService.selectPayBillList(bq).size();

        // 4) 今日预约（按 storeId，status=0 开放中 且 日期=今天）
        Booking bookingQ = new Booking();
        bookingQ.setStoreId(storeId);
        bookingQ.setStatus("0");
        List<Booking> bookings = bookingService.selectBookingList(bookingQ);
        int todayBookingCount = 0;
        for (Booking b : bookings)
        {
            if (b.getBookingDate() != null && isSameDay(b.getBookingDate(), new Date()))
            {
                todayBookingCount++;
            }
        }

        // 5) 最近 5 单
        Order q5 = new Order();
        q5.setStoreId(storeId);
        List<Order> recent = orderService.selectOrderList(q5);
        if (recent.size() > 5) recent = recent.subList(0, 5);

        Map<String, Object> data = new HashMap<>();
        data.put("storeId", storeId);
        data.put("storeName", store == null ? "" : store.getStoreName());
        data.put("todayVerifyCount", verifyCount);
        data.put("todayVerifyAmount", verifyAmount);
        data.put("todayOrderCount", unusedCount);
        data.put("pendingBillCount", pendingBillCount);
        data.put("todayBookingCount", todayBookingCount);
        data.put("recentOrders", recent);
        return AjaxResult.success(data);
    }

    /**
     * 本店今日订单流水
     */
    @StoreStaffRequired
    @GetMapping("/today/orders")
    public AjaxResult todayOrders()
    {
        LoginMember m = MemberContextHolder.get();
        Order q = new Order();
        q.setStoreId(m.getStoreId());
        List<Order> all = orderService.selectOrderList(q);
        Date todayStart = startOfToday();
        Date todayEnd = endOfToday();
        // 按 create_time 倒序，过滤今天（无 create_time 也保留 — 历史订单也能看）
        all.sort((a, b) -> {
            Date t1 = a.getCreateTime() == null ? new Date(0) : a.getCreateTime();
            Date t2 = b.getCreateTime() == null ? new Date(0) : b.getCreateTime();
            return t2.compareTo(t1);
        });
        java.util.List<Order> today = new java.util.ArrayList<>();
        for (Order o : all)
        {
            if (o.getCreateTime() != null && o.getCreateTime().before(todayStart)) continue;
            if (o.getCreateTime() != null && !o.getCreateTime().before(todayEnd)) continue;
            today.add(o);
        }
        return AjaxResult.success(today);
    }

    /**
     * 本店今日买单流水
     */
    @StoreStaffRequired
    @GetMapping("/today/bills")
    public AjaxResult todayBills()
    {
        LoginMember m = MemberContextHolder.get();
        PayBill q = new PayBill();
        q.setStoreId(m.getStoreId());
        List<PayBill> all = payBillService.selectPayBillList(q);
        Date todayStart = startOfToday();
        Date todayEnd = endOfToday();
        java.util.List<PayBill> today = new java.util.ArrayList<>();
        for (PayBill b : all)
        {
            if (b.getCreateTime() != null && b.getCreateTime().before(todayStart)) continue;
            if (b.getCreateTime() != null && !b.getCreateTime().before(todayEnd)) continue;
            today.add(b);
        }
        return AjaxResult.success(today);
    }

    /**
     * 本店今日预约列表（含报名人）
     */
    @StoreStaffRequired
    @GetMapping("/today/bookings")
    public AjaxResult todayBookings()
    {
        LoginMember m = MemberContextHolder.get();
        Booking q = new Booking();
        q.setStoreId(m.getStoreId());
        List<Booking> bookings = bookingService.selectBookingList(q);
        java.util.List<Booking> today = new java.util.ArrayList<>();
        for (Booking b : bookings)
        {
            if (b.getBookingDate() != null && isSameDay(b.getBookingDate(), new Date()))
            {
                today.add(b);
            }
        }
        return AjaxResult.success(today);
    }

    /**
     * 预约报名人到场确认（员工点「确认到场」）
     *
     * <p>把 biz_booking_member.status 维持 0（已到场），
     * 写 confirm_user=当前员工、confirm_time=now。</p>
     */
    @StoreStaffRequired
    @PostMapping("/booking/confirm/{signupId}")
    public AjaxResult confirmSignup(@PathVariable Long signupId, @RequestBody(required=false) java.util.Map<String,Object> body)
    {
        LoginMember m = MemberContextHolder.get();
        BookingMember bm = bookingService.selectBookingMemberById(signupId);
        if (bm == null) return AjaxResult.error("报名记录不存在");
        Booking parent = bookingService.selectBookingByBookingId(bm.getBookingId());
        if (parent == null || !m.getStoreId().equals(parent.getStoreId())) return AjaxResult.error("无权操作该报名");
        if ("1".equals(bm.getStatus())) return AjaxResult.error("该报名已取消");
        if ("2".equals(bm.getStatus())) return AjaxResult.error("该报名已确认");
        if ("3".equals(bm.getStatus())) return AjaxResult.error("该报名已拒绝");
        bm.setStatus("2");
        bm.setConfirmUser(m.getMemberId() == null ? "store-staff" : ("staff-" + m.getMemberId()));
        bm.setConfirmTime(new Date());
        String remark = body == null ? null : (String) body.get("remark");
        if (remark != null && !remark.isEmpty()) bm.setReviewRemark(remark);
        bookingService.updateBookingMember(bm);
        return AjaxResult.success("已确认");
    }

    @StoreStaffRequired
    @PostMapping("/booking/reject/{signupId}")
    public AjaxResult rejectSignup(@PathVariable Long signupId, @RequestBody(required=false) java.util.Map<String,Object> body)
    {
        LoginMember m = MemberContextHolder.get();
        BookingMember bm = bookingService.selectBookingMemberById(signupId);
        if (bm == null) return AjaxResult.error("报名记录不存在");
        Booking parent = bookingService.selectBookingByBookingId(bm.getBookingId());
        if (parent == null || !m.getStoreId().equals(parent.getStoreId())) return AjaxResult.error("无权操作该报名");
        if ("1".equals(bm.getStatus())) return AjaxResult.error("该报名已取消");
        if ("2".equals(bm.getStatus())) return AjaxResult.error("已确认，不能拒绝");
        if ("3".equals(bm.getStatus())) return AjaxResult.error("该报名已拒绝");
        String reason = body == null ? null : (String) body.get("reason");
        if (reason == null || reason.trim().isEmpty()) return AjaxResult.error("请填写拒绝原因");
        bm.setStatus("3");
        bm.setConfirmUser(m.getMemberId() == null ? "store-staff" : ("staff-" + m.getMemberId()));
        bm.setConfirmTime(new Date());
        bm.setReviewRemark(reason);
        bookingService.updateBookingMember(bm);
        return AjaxResult.success("已拒绝");
    }

    @StoreStaffRequired
    @GetMapping("/booking/signup/list")
    public AjaxResult bookingSignupList()
    {
        LoginMember m = MemberContextHolder.get();
        // 拿本店今日所有预约
        Booking bq = new Booking();
        bq.setStoreId(m.getStoreId());
        List<Booking> today = new java.util.ArrayList<>();
        for (Booking b : bookingService.selectBookingList(bq))
        {
            if (b.getBookingDate() != null && isSameDay(b.getBookingDate(), new Date()))
            {
                today.add(b);
            }
        }
        // 拉每个预约的报名人列表
        java.util.List<java.util.Map<String, Object>> out = new java.util.ArrayList<>();
        for (Booking b : today)
        {
            BookingMember q = new BookingMember();
            q.setBookingId(b.getBookingId());
            for (BookingMember s : bookingService.selectBookingMemberList(q))
            {
                java.util.Map<String, Object> row = new HashMap<>();
                row.put("signupId", s.getId());
                row.put("bookingId", b.getBookingId());
                row.put("serviceName", b.getServiceName());
                row.put("timeSlot", b.getTimeSlot());
                row.put("contact", s.getContact());
                row.put("phone", s.getPhone());
                row.put("people", s.getPeople());
                row.put("status", s.getStatus());
                row.put("remark", s.getRemark());
                row.put("reviewRemark", s.getReviewRemark());
                row.put("confirmUser", s.getConfirmUser());
                row.put("confirmTime", s.getConfirmTime());
                row.put("createTime", s.getCreateTime());
                out.add(row);
            }
        }
        return AjaxResult.success(out);
    }

    private Date startOfToday()
    {
        Calendar c = Calendar.getInstance();
        c.set(Calendar.HOUR_OF_DAY, 0);
        c.set(Calendar.MINUTE, 0);
        c.set(Calendar.SECOND, 0);
        c.set(Calendar.MILLISECOND, 0);
        return c.getTime();
    }

    private Date endOfToday()
    {
        Calendar c = Calendar.getInstance();
        c.set(Calendar.HOUR_OF_DAY, 23);
        c.set(Calendar.MINUTE, 59);
        c.set(Calendar.SECOND, 59);
        c.set(Calendar.MILLISECOND, 999);
        return c.getTime();
    }

    private boolean isSameDay(Date d1, Date d2)
    {
        if (d1 == null || d2 == null) return false;
        Calendar a = Calendar.getInstance();
        a.setTime(d1);
        Calendar b = Calendar.getInstance();
        b.setTime(d2);
        return a.get(Calendar.YEAR) == b.get(Calendar.YEAR)
            && a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR);
    }
}
