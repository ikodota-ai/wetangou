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

    @Autowired
    private com.ruoyi.system.service.ISysDictDataService dictDataService;

    /** 预约类型字典（后台「字典管理 → 预约类型」维护，商家可自行增删） */
    private static final String DICT_BOOKING_TYPE = "biz_booking_type";

    /**
     * 可选的预约类型
     *
     * <p>小程序预约首页原先写死一张「堂食预约」卡片，后台在字典里加了
     * 「到店消费」「其他预约」也不显示 —— 等于配置项没有出口。
     * 这里把字典开放给小程序，前端按返回条数渲染卡片。</p>
     *
     * <p>只返 status='0'（正常）的项：字典里停用的类型不该出现在顾客端。
     * dictDataService.selectDictDataList 已按 dict_sort 排序，顺序即后台配的顺序。</p>
     */
    @GetMapping("/types")
    public AjaxResult types()
    {
        com.ruoyi.common.core.domain.entity.SysDictData query = new com.ruoyi.common.core.domain.entity.SysDictData();
        query.setDictType(DICT_BOOKING_TYPE);
        query.setStatus("0");
        List<com.ruoyi.common.core.domain.entity.SysDictData> list = dictDataService.selectDictDataList(query);
        List<java.util.Map<String, Object>> rows = new ArrayList<java.util.Map<String, Object>>();
        for (com.ruoyi.common.core.domain.entity.SysDictData d : list)
        {
            java.util.Map<String, Object> vo = new java.util.LinkedHashMap<String, Object>();
            vo.put("code", d.getDictValue());
            vo.put("name", d.getDictLabel());
            vo.put("sort", d.getDictSort());
            rows.add(vo);
        }
        return AjaxResult.success(rows);
    }

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
     * 门店可预约日期列表
     *
     * <p>小程序预约页原先写死「未来 7 天」，运营既收不窄也放不宽，
     * 也没法把歇业日排掉（门店周一休息，顾客照样能选周一，提交才被拒）。
     * 现在天数取门店 booking_ahead_days，歇业日按 booking_closed_days 标出。</p>
     *
     * <p>匿名可访问，理由同 /slots：未登录也要能先看能约哪天。</p>
     *
     * @param storeId 门店ID
     */
    @GetMapping("/days")
    public AjaxResult days(@RequestParam Long storeId)
    {
        return AjaxResult.success(bookingService.selectBookableDays(storeId));
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
            // 预约类型（堂食预约 / 到店消费 / ...）。必须在字典里，
            // 否则前端随便传个值就会落进库里，后台列表按类型筛选时对不上。
            String bookingType = body.getString("bookingType");
            if (StringUtils.isNotEmpty(bookingType)
                    && StringUtils.isEmpty(dictDataService.selectDictLabel(DICT_BOOKING_TYPE, bookingType)))
            {
                throw new ServiceException("预约类型不存在或已停用");
            }

            // 可约范围必须在后端再判一次：日期条置灰、时段标 closed 都只是界面效果，
            // 实测直接 POST 过来时歇业日 / 超出可提前天数 / 已过去的时段 / 非营业时间
            // 一律返 200 落库，商家会收到根本没法接待的单子。
            bookingService.assertSlotBookable(storeId,
                    com.ruoyi.common.utils.DateUtils.parseDateToStr("yyyy-MM-dd", bookingDate), timeSlot);

            // 同门店同日同时段已有场次时直接复用，避免每人报名都新建一个场次
            Booking query = new Booking();
            query.setStoreId(storeId);
            query.setBookingDate(bookingDate);
            query.setTimeSlot(timeSlot);
            // 类型也要参与复用判断：同门店同时段的「堂食预约」和「到店消费」
            // 是两个不同场次，不加这个条件会把后来者并进先建的那个类型里。
            query.setBookingType(bookingType);
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
                booking.setBookingType(bookingType);
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
            // 门店信息（BookingMember 已 left join biz_store，字段在实体里）
            vo.put("storeId", signup.getStoreId());
            vo.put("storeName", signup.getStoreName());
            vo.put("storeAddress", signup.getStoreAddress());
            // 门店电话是公开信息（顾客要用它打给店里），脱敏后前端
            // wx.makePhoneCall 拨的是 134****3069 —— 根本拨不出去。
            // Store.java 里 phone/servicePhone 特意没加 @Sensitive 就是这个原因，
            // 这里手动脱一次等于把那个决定推翻了。
            vo.put("storePhone", signup.getStorePhone());
            vo.put("storeLatitude", signup.getStoreLatitude());
            vo.put("storeLongitude", signup.getStoreLongitude());
            vo.put("serviceName", signup.getServiceName());
            vo.put("bookingDate", signup.getBookingDate());
            vo.put("timeSlot", signup.getTimeSlot());
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
        // 注释写的是「自己看自己 → phone 明文」，做的却是脱敏 —— 和
        // /api/member/profile 一模一样的问题。这是本人报名时自己填的联系电话
        // （上面已按 memberId 校验过归属），脱敏没有意义，还会让顾客核对不了
        // 自己填的号码对不对。
        vo.put("phone", signup.getPhone());
        vo.put("people", signup.getPeople());
        vo.put("status", signup.getStatus());
        vo.put("confirmUser", signup.getConfirmUser());
        vo.put("confirmTime", signup.getConfirmTime());
        vo.put("reviewRemark", signup.getReviewRemark());
        vo.put("remark", signup.getRemark());
        vo.put("createTime", signup.getCreateTime());
        // 门店信息（与 list 同源）
        vo.put("storeId", signup.getStoreId());
        vo.put("storeName", signup.getStoreName());
        vo.put("storeAddress", signup.getStoreAddress());
        // 同 list：门店电话要能拨出去，不能脱敏
        vo.put("storePhone", signup.getStorePhone());
        vo.put("storeLatitude", signup.getStoreLatitude());
        vo.put("storeLongitude", signup.getStoreLongitude());
        vo.put("serviceName", signup.getServiceName());
        vo.put("bookingDate", signup.getBookingDate());
        vo.put("timeSlot", signup.getTimeSlot());
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
        // 不能直接 return 实体：BookingMember.phone / storePhone 上都挂着
        // @Sensitive(PHONE)，而 SensitiveJsonSerializer 在拿不到 LoginUser 时一律脱敏
        // （小程序 /api/** 全是 @Anonymous），嵌套的报名手机号会变 138****7777、
        // 门店电话会变成拨不出去的 134****3069。这里只回本人的报名，手工转 Map 保明文。
        java.util.Map<String, Object> vo = new java.util.LinkedHashMap<>();
        vo.put("bookingId", booking.getBookingId());
        vo.put("merchantId", booking.getMerchantId());
        vo.put("bookingNo", booking.getBookingNo());
        vo.put("storeId", booking.getStoreId());
        vo.put("storeName", booking.getStoreName());
        vo.put("productId", booking.getProductId());
        vo.put("serviceName", booking.getServiceName());
        vo.put("bookingType", booking.getBookingType());
        vo.put("bookingDate", booking.getBookingDate());
        vo.put("timeSlot", booking.getTimeSlot());
        vo.put("status", booking.getStatus());
        vo.put("signupCount", booking.getSignupCount());
        vo.put("signupPeople", booking.getSignupPeople());
        vo.put("remark", booking.getRemark());
        vo.put("createTime", booking.getCreateTime());
        vo.put("bookingMembers", toSignupVoList(mine));
        return AjaxResult.success(vo);
    }

    /**
     * 报名实体列表 → 明文 VO 列表（与 /api/booking/list 字段口径一致）
     */
    private java.util.List<java.util.Map<String, Object>> toSignupVoList(List<BookingMember> list)
    {
        java.util.List<java.util.Map<String, Object>> rows = new java.util.ArrayList<>();
        if (list == null) return rows;
        for (BookingMember signup : list)
        {
            java.util.Map<String, Object> row = new java.util.LinkedHashMap<>();
            row.put("id", signup.getId());
            row.put("bookingId", signup.getBookingId());
            row.put("memberId", signup.getMemberId());
            row.put("memberName", signup.getMemberName());
            row.put("contact", signup.getContact());
            row.put("phone", signup.getPhone());
            row.put("people", signup.getPeople());
            row.put("status", signup.getStatus());
            row.put("confirmUser", signup.getConfirmUser());
            row.put("confirmTime", signup.getConfirmTime());
            row.put("reviewRemark", signup.getReviewRemark());
            row.put("remark", signup.getRemark());
            row.put("createTime", signup.getCreateTime());
            row.put("storeId", signup.getStoreId());
            row.put("storeName", signup.getStoreName());
            row.put("storeAddress", signup.getStoreAddress());
            row.put("storePhone", signup.getStorePhone());
            row.put("storeLatitude", signup.getStoreLatitude());
            row.put("storeLongitude", signup.getStoreLongitude());
            row.put("serviceName", signup.getServiceName());
            row.put("bookingDate", signup.getBookingDate());
            row.put("timeSlot", signup.getTimeSlot());
            rows.add(row);
        }
        return rows;
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
        if (loginMember.isStaffSession())
        {
            // 员工端（门店端 store + 商家端 owner/manager/staff）：必须是该场次所属门店的员工
            Booking booking = bookingService.selectBookingByBookingId(signup.getBookingId());
            if (booking == null || !loginMember.hasStore(booking.getStoreId()))
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
