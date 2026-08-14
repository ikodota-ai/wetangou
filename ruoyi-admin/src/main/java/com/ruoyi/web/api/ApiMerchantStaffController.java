package com.ruoyi.web.api;

import java.util.ArrayList;
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
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.alibaba.fastjson2.JSONObject;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.biz.api.annotation.LoginRequired;
import com.ruoyi.biz.api.domain.LoginMember;
import com.ruoyi.biz.api.service.WxMaService;
import com.ruoyi.biz.api.util.MemberContextHolder;
import com.ruoyi.biz.api.util.MemberTokenService;
import com.ruoyi.biz.domain.MerchantStaff;
import com.ruoyi.biz.domain.MerchantStaffInvite;
import com.ruoyi.biz.domain.Store;
import com.ruoyi.biz.domain.Booking;
import com.ruoyi.biz.domain.BookingMember;
import com.ruoyi.biz.domain.Order;
import com.ruoyi.biz.domain.PayBill;
import com.ruoyi.biz.service.IMerchantStaffInviteService;
import com.ruoyi.biz.service.IMerchantStaffService;
import com.ruoyi.biz.service.IOrderService;
import com.ruoyi.biz.service.IPayBillService;
import com.ruoyi.biz.service.IBookingService;
import com.ruoyi.biz.service.IStoreService;
import com.ruoyi.system.service.ISysUserService;

/**
 * 小程序商家端（新）/api/merchant/staff/*
 *
 * <p>支持：
 * 1) 账号密码登录（旧链路）→ 强制绑定微信
 * 2) 微信自动登录（用 openid 命中 sys_user）→ 扫码核销场景
 * 3) 邀请码接受（扫商家邀请码后自动建账号 + 绑门店 + 微信登录）
 * 4) 当前商家信息 / 退出登录
 * </p>
 */
@Anonymous
@RestController
@RequestMapping("/api/merchant/staff")
public class ApiMerchantStaffController
{
    @Autowired private ISysUserService userService;
    @Autowired private IMerchantStaffService staffService;
    @Autowired private IMerchantStaffInviteService inviteService;
    @Autowired private MemberTokenService memberTokenService;
    @Autowired private WxMaService wxMaService;
    @Autowired private IStoreService storeService;
    @Autowired private IOrderService orderService;
    @Autowired private IPayBillService payBillService;
    @Autowired private IBookingService bookingService;

    /** 账号密码登录（兼容旧 staff 链路） */
    @PostMapping("/login")
    public AjaxResult login(@RequestBody JSONObject body)
    {
        String username = body.getString("username");
        String password = body.getString("password");
        if (username == null || password == null) throw new ServiceException("账号或密码不能为空");

        SysUser user = userService.selectUserByUserName(username);
        if (user == null) throw new ServiceException("账号或密码错误");
        if (!"0".equals(user.getStatus())) throw new ServiceException("账号已被停用");
        if (!SecurityUtils.matchesPassword(password, user.getPassword())) throw new ServiceException("账号或密码错误");

        // 必须有商家员工关联
        List<MerchantStaff> links = staffService.selectList(new MerchantStaff() {{ setUserId(user.getUserId()); }});
        if (links == null || links.isEmpty()) throw new ServiceException("该账号未关联商家");

        LoginMember lm = buildLoginMember(user, links, "merchant");
        String token = memberTokenService.createToken(lm);
        lm.setToken(token);

        return packLoginResult(lm, user, links);
    }

    /**
     * 微信自动登录（用 openid 命中）
     * 入参: { code: 微信jscode, merchantId?: 多商户场景 }
     */
    @PostMapping("/wxLogin")
    public AjaxResult wxLogin(@RequestBody JSONObject body)
    {
        String code = body.getString("code");
        if (StringUtils.isEmpty(code)) throw new ServiceException("缺少 code");
        Long merchantId = body.getLong("merchantId");

        JSONObject session = wxMaService.code2Session(code, merchantId);
        String openid = session.getString("openid");
        if (StringUtils.isEmpty(openid)) throw new ServiceException("微信登录失败");

        SysUser user = userService.selectUserByOpenId(openid);
        if (user == null) throw new ServiceException("NOT_BOUND", 600); // 600: 尚未绑定，前端引导走"扫码邀请"流程

        List<MerchantStaff> links = staffService.selectList(new MerchantStaff() {{ setUserId(user.getUserId()); }});
        if (links == null || links.isEmpty()) throw new ServiceException("该微信未关联商家");

        LoginMember lm = buildLoginMember(user, links, "merchant");
        String token = memberTokenService.createToken(lm);
        lm.setToken(token);

        return packLoginResult(lm, user, links);
    }

    /**
     * 接受邀请（扫商家邀请码后用）
     * 入参: { code: 微信jscode, scene: invite:MID:SID:CODE, merchantId?, profile? }
     * 自动建账号（若 openid 未绑） + 绑门店 + 微信登录
     */
    @PostMapping("/acceptInvite")
    public AjaxResult acceptInvite(@RequestBody JSONObject body)
    {
        String code = body.getString("code");
        String scene = body.getString("scene");
        if (StringUtils.isEmpty(code) || StringUtils.isEmpty(scene)) throw new ServiceException("缺少 code 或 scene");

        // 1) 解析 scene（格式：invite:MID:SID:CODE）
        String[] parts = scene.split(":");
        if (parts.length != 4 || !"invite".equals(parts[0])) throw new ServiceException("邀请码格式错误");
        Long mid = Long.parseLong(parts[1]);
        Long sid = Long.parseLong(parts[2]);
        String inviteCode = parts[3];

        // 2) 校验邀请码有效性
        MerchantStaffInvite invite = inviteService.selectByCode(inviteCode);
        if (invite == null) throw new ServiceException("邀请码不存在");
        if (!"0".equals(invite.getStatus())) throw new ServiceException("邀请码已失效");
        if (invite.getExpireAt() != null && invite.getExpireAt().before(new Date())) {
            invite.setStatus("2");
            inviteService.update(invite);
            throw new ServiceException("邀请码已过期");
        }
        if (!mid.equals(invite.getMerchantId()) || !sid.equals(invite.getStoreId())) throw new ServiceException("邀请码与门店不匹配");

        // 3) code2Session
        JSONObject session = wxMaService.code2Session(code, mid);
        String openid = session.getString("openid");
        if (StringUtils.isEmpty(openid)) throw new ServiceException("微信登录失败");

        // 4) openid 命中 → 复用；未命中 → 自动建账号
        SysUser user = userService.selectUserByOpenId(openid);
        if (user == null)
        {
            user = createStaffByOpenid(openid, session, body, invite);
        }

        // 5) 校验员工关联（可能已存在 / 可能新绑）
        final SysUser boundUser = user;
        List<MerchantStaff> links = staffService.selectList(new MerchantStaff() {{ setUserId(boundUser.getUserId()); }});
        boolean alreadyBound = links != null && links.stream().anyMatch(l -> sid.equals(l.getStoreId()) && mid.equals(l.getMerchantId()));
        if (!alreadyBound)
        {
            MerchantStaff ms = new MerchantStaff();
            ms.setMerchantId(mid);
            ms.setStoreId(sid);
            ms.setUserId(user.getUserId());
            ms.setRole(invite.getRole() == null ? "STAFF" : invite.getRole());
            ms.setStatus("0");
            ms.setCreateTime(new Date());
            staffService.insert(ms);
            // 重新查关联
            links = staffService.selectList(new MerchantStaff() {{ setUserId(boundUser.getUserId()); }});
        }

        // 6) 标记邀请码已用
        invite.setUsedAt(new Date());
        invite.setUsedBy(user.getUserId());
        invite.setStatus("1");
        inviteService.update(invite);

        // 7) 自动登录
        LoginMember lm = buildLoginMember(user, links, "merchant");
        String token = memberTokenService.createToken(lm);
        lm.setToken(token);

        return packLoginResult(lm, user, links);
    }

    /** 绑定当前登录员工的微信（首次登录后必做） */
    @LoginRequired
    @PostMapping("/bindWx")
    public AjaxResult bindWx(@RequestBody JSONObject body)
    {
        LoginMember lm = MemberContextHolder.get();
        if (lm == null || (!"store".equals(lm.getUserType()) && !"merchant".equals(lm.getUserType()))) {
            throw new ServiceException("此操作仅限商家端");
        }
        String code = body.getString("code");
        if (StringUtils.isEmpty(code)) throw new ServiceException("缺少 code");
        JSONObject session = wxMaService.code2Session(code, lm.getMerchantId());
        String openid = session.getString("openid");
        if (StringUtils.isEmpty(openid)) throw new ServiceException("微信登录失败");

        // openid 已被其他账号绑定？
        SysUser exist = userService.selectUserByOpenId(openid);
        if (exist != null && !exist.getUserId().equals(lm.getMemberId())) {
            throw new ServiceException("该微信已绑定其他账号");
        }

        SysUser user = userService.selectUserByUserId(lm.getMemberId());
        if (user == null) throw new ServiceException("员工账号不存在");
        user.setOpenid(openid);
        user.setOpenidBound(1);
        userService.updateUser(user);

        AjaxResult r = AjaxResult.success("绑定成功");
        r.put("openid", openid);
        return r;
    }

    /** 当前商家员工信息 */
    @LoginRequired
    @GetMapping("/me")
    public AjaxResult me()
    {
        LoginMember lm = MemberContextHolder.get();
        if (lm == null) throw new ServiceException("未登录");
        SysUser u = userService.selectUserByUserId(lm.getMemberId());
        MerchantStaff ms = staffService.selectByUserId(lm.getMemberId());

        JSONObject r = new JSONObject();
        r.put("userId", u.getUserId());
        r.put("userName", u.getUserName());
        r.put("nickName", u.getNickName());
        r.put("avatar", u.getAvatar());
        r.put("openid", u.getOpenid());
        r.put("openidBound", u.getOpenidBound());
        r.put("userType", lm.getUserType());
        r.put("merchantId", lm.getMerchantId());
        r.put("storeId", lm.getStoreId());
        r.put("storeIds", lm.getStoreIds());
        r.put("stores", resolveStores(lm.getStoreIds()));
        if (ms != null) {
            r.put("role", ms.getRole());
            r.put("realName", ms.getRealName());
            r.put("phone", ms.getPhone());
            r.put("staffNo", ms.getStaffNo());
        }
        return AjaxResult.success(r);
    }

    /** 补录员工姓名/手机号（用户后续自助补全） */
    @LoginRequired
    @PostMapping("/profile")
    public AjaxResult updateProfile(@RequestBody JSONObject body)
    {
        LoginMember lm = MemberContextHolder.get();
        if (lm == null) throw new ServiceException("未登录");
        String realName = body.getString("realName");
        String phone = body.getString("phone");
        if (realName == null && phone == null) throw new ServiceException("无更新内容");

        MerchantStaff upd = new MerchantStaff();
        upd.setUserId(lm.getMemberId());
        upd.setRealName(realName);
        upd.setPhone(phone);
        upd.setUpdateBy(String.valueOf(lm.getMemberId()));
        upd.setUpdateTime(new Date());
        staffService.updateByUserId(upd);
        return AjaxResult.success("已更新");
    }

    /** 退出登录 */
    @LoginRequired
    @PostMapping("/logout")
    public AjaxResult logout()
    {
        LoginMember lm = MemberContextHolder.get();
        if (lm != null && lm.getToken() != null) memberTokenService.delLoginMember(lm.getToken());
        return AjaxResult.success("已退出");
    }

    // ===== helpers =====

    private LoginMember buildLoginMember(SysUser user, List<MerchantStaff> links, String userType)
    {
        List<Long> storeIds = new ArrayList<>();
        Long merchantId = null;
        for (MerchantStaff l : links) {
            if (l.getStoreId() != null && !storeIds.contains(l.getStoreId())) storeIds.add(l.getStoreId());
            if (merchantId == null && l.getMerchantId() != null) merchantId = l.getMerchantId();
        }
        Long currentStoreId = storeIds.isEmpty() ? null : storeIds.get(0);
        LoginMember lm = new LoginMember();
        lm.setUserType(userType);
        lm.setStoreId(currentStoreId);
        lm.setStoreIds(storeIds);
        lm.setMerchantId(merchantId);
        lm.setMemberId(user.getUserId());
        lm.setOpenid(user.getOpenid() == null ? "staff:" + user.getUserId() : user.getOpenid());
        return lm;
    }

    private AjaxResult packLoginResult(LoginMember lm, SysUser user, List<MerchantStaff> links)
    {
        List<Long> storeIds = lm.getStoreIds();
        Map<Long, String> storeNameMap = new HashMap<>();
        for (Long sid : storeIds) {
            Store s = storeService.selectStoreByStoreId(sid);
            if (s != null) storeNameMap.put(sid, s.getStoreName());
        }
        MerchantStaff me = links == null || links.isEmpty() ? null : links.get(0);
        AjaxResult ajax = AjaxResult.success();
        ajax.put("token", lm.getToken());
        ajax.put("userType", lm.getUserType());
        ajax.put("storeId", lm.getStoreId());
        ajax.put("storeIds", storeIds);
        ajax.put("storeName", storeNameMap.getOrDefault(lm.getStoreId(), ""));
        ajax.put("merchantId", lm.getMerchantId());
        ajax.put("realName", me != null && StringUtils.isNotEmpty(me.getRealName()) ? me.getRealName() : user.getNickName());
        ajax.put("openidBound", user.getOpenidBound() == null ? 0 : user.getOpenidBound());
        ajax.put("needBindWx", user.getOpenidBound() == null || user.getOpenidBound() == 0);
        return ajax;
    }

    private List<JSONObject> resolveStores(List<Long> storeIds)
    {
        List<JSONObject> out = new ArrayList<>();
        if (storeIds == null) return out;
        for (Long sid : storeIds) {
            Store s = storeService.selectStoreByStoreId(sid);
            if (s != null) {
                JSONObject o = new JSONObject();
                o.put("storeId", s.getStoreId());
                o.put("storeName", s.getStoreName());
                o.put("address", s.getAddress());
                out.add(o);
            }
        }
        return out;
    }

    private SysUser createStaffByOpenid(String openid, JSONObject session, JSONObject body, MerchantStaffInvite invite)
    {
        // 自动建账号：staff_ + 6 位随机
        String username = "staff_" + randomSix();
        String rawPwd = randomSix();
        String encPwd = SecurityUtils.encryptPassword(rawPwd);
        SysUser u = new SysUser();
        u.setUserName(username);
        u.setPassword(encPwd);
        u.setNickName((body != null && body.getString("nickName") != null) ? body.getString("nickName") : "新员工");
        u.setAvatar((body != null && body.getString("avatarUrl") != null) ? body.getString("avatarUrl") : "");
        u.setOpenid(openid);
        u.setOpenidBound(1);
        u.setStatus("0");
        u.setDelFlag("0");
        u.setCreateBy("invite:" + invite.getInviteCode());
        u.setCreateTime(new Date());
        u.setUserType("00"); // RuoYi 默认普通用户
        u.setMerchantId(invite.getMerchantId()); // 多商户隔离
        userService.insertUser(u);
        return u;
    }


    // =============================================================
    // 商家工作台（数据 / 核销 / 预约审核）
    // 端点对标旧 /api/store/staff/{home,today/*,booking/*}，
    // 区别：userType=merchant，门店 ID 直接用 token.storeId
    // =============================================================

    private LoginMember requireMerchantLogin()
    {
        LoginMember m = MemberContextHolder.get();
        if (m == null) throw new ServiceException("未登录");
        if (!"merchant".equals(m.getUserType())) throw new ServiceException("非商家员工身份");
        if (m.getStoreId() == null) throw new ServiceException("未绑定门店");
        return m;
    }

    @LoginRequired
    @GetMapping("/home")
    public AjaxResult dashboardHome()
    {
        LoginMember m = requireMerchantLogin();
        Long storeId = m.getStoreId();
        Store store = storeService.selectStoreByStoreId(storeId);
        Date todayStart = startOfToday();
        Date todayEnd = endOfToday();

        // 1) 今日核销
        Order q1 = new Order(); q1.setStoreId(storeId); q1.setStatus("2");
        List<Order> verified = orderService.selectOrderList(q1);
        int verifyCount = 0;
        java.math.BigDecimal verifyAmount = java.math.BigDecimal.ZERO;
        for (Order o : verified) {
            if (o.getVerifyTime() != null && !o.getVerifyTime().before(todayStart) && o.getVerifyTime().before(todayEnd)) {
                verifyCount++;
                if (o.getPayAmount() != null) verifyAmount = verifyAmount.add(o.getPayAmount());
            }
        }

        // 2) 今日新订单（待使用）
        Order q2 = new Order(); q2.setStoreId(storeId); q2.setStatus("1");
        List<Order> unused = orderService.selectOrderList(q2);
        int orderCount = 0;
        for (Order o : unused) {
            if (o.getPayTime() != null && !o.getPayTime().before(todayStart) && o.getPayTime().before(todayEnd)) orderCount++;
        }

        // 3) 待确认买单
        PayBill bq = new PayBill(); bq.setStoreId(storeId); bq.setStatus("0");
        int pendingBillCount = payBillService.selectPayBillList(bq).size();

        // 4) 今日预约
        Booking bookingQ = new Booking(); bookingQ.setStoreId(storeId); bookingQ.setStatus("0");
        int todayBookingCount = 0;
        for (Booking b : bookingService.selectBookingList(bookingQ)) {
            if (b.getBookingDate() != null && isSameDay(b.getBookingDate(), new Date())) todayBookingCount++;
        }

        // 5) 最近 5 单
        Order q5 = new Order(); q5.setStoreId(storeId);
        List<Order> recent = orderService.selectOrderList(q5);
        if (recent.size() > 5) recent = recent.subList(0, 5);

        Map<String, Object> data = new HashMap<>();
        data.put("storeId", storeId);
        data.put("storeName", store == null ? "" : store.getStoreName());
        data.put("todayVerifyCount", verifyCount);
        data.put("todayVerifyAmount", verifyAmount);
        data.put("todayOrderCount", orderCount);
        data.put("pendingBillCount", pendingBillCount);
        data.put("todayBookingCount", todayBookingCount);
        data.put("recentOrders", recent);
        return AjaxResult.success(data);
    }

    @LoginRequired
    @GetMapping("/today/orders")
    public AjaxResult todayOrders()
    {
        LoginMember m = requireMerchantLogin();
        Order q = new Order(); q.setStoreId(m.getStoreId());
        List<Order> all = orderService.selectOrderList(q);
        all.sort((a, b) -> {
            Date t1 = a.getCreateTime() == null ? new Date(0) : a.getCreateTime();
            Date t2 = b.getCreateTime() == null ? new Date(0) : b.getCreateTime();
            return t2.compareTo(t1); // String compare as fallback (dates are yyyy-MM-dd)
        });
        List<Order> today = new ArrayList<>();
        Date todayStart = startOfToday();
        Date todayEnd = endOfToday();
        for (Order o : all) {
            if (o.getCreateTime() == null) continue;
            if (o.getCreateTime().before(todayStart) || !o.getCreateTime().before(todayEnd)) continue;
            today.add(o);
        }
        return AjaxResult.success(today);
    }

    @LoginRequired
    @GetMapping("/today/bills")
    public AjaxResult todayBills()
    {
        LoginMember m = requireMerchantLogin();
        PayBill q = new PayBill(); q.setStoreId(m.getStoreId());
        List<PayBill> all = payBillService.selectPayBillList(q);
        Date todayStart = startOfToday();
        Date todayEnd = endOfToday();
        List<PayBill> today = new ArrayList<>();
        for (PayBill b : all) {
            if (b.getCreateTime() == null) continue;
            if (b.getCreateTime().before(todayStart) || !b.getCreateTime().before(todayEnd)) continue;
            today.add(b);
        }
        return AjaxResult.success(today);
    }

    @LoginRequired
    @GetMapping("/today/bookings")
    public AjaxResult todayBookings()
    {
        LoginMember m = requireMerchantLogin();
        Booking q = new Booking(); q.setStoreId(m.getStoreId());
        List<Booking> bookings = bookingService.selectBookingList(q);
        List<Booking> today = new ArrayList<>();
        for (Booking b : bookings) {
            if (b.getBookingDate() != null && isSameDay(b.getBookingDate(), new Date())) today.add(b);
        }
        return AjaxResult.success(today);
    }

    @LoginRequired
    @PostMapping("/booking/confirm/{signupId}")
    public AjaxResult confirmSignup(@PathVariable Long signupId, @RequestBody(required = false) java.util.Map<String, Object> body)
    {
        LoginMember m = requireMerchantLogin();
        BookingMember bm = bookingService.selectBookingMemberById(signupId);
        if (bm == null) return AjaxResult.error("报名记录不存在");
        Booking parent = bookingService.selectBookingByBookingId(bm.getBookingId());
        if (parent == null || !m.getStoreId().equals(parent.getStoreId())) return AjaxResult.error("无权操作该报名");
        if ("1".equals(bm.getStatus())) return AjaxResult.error("该报名已取消");
        if ("2".equals(bm.getStatus())) return AjaxResult.error("该报名已确认");
        if ("3".equals(bm.getStatus())) return AjaxResult.error("该报名已拒绝");
        bm.setStatus("2");
        bm.setConfirmUser(m.getMemberId() == null ? "merchant-staff" : ("mstaff-" + m.getMemberId()));
        bm.setConfirmTime(new Date());
        if (body != null && body.get("remark") != null) bm.setReviewRemark(String.valueOf(body.get("remark")));
        bookingService.updateBookingMember(bm);
        return AjaxResult.success("已确认");
    }

    @LoginRequired
    @PostMapping("/booking/reject/{signupId}")
    public AjaxResult rejectSignup(@PathVariable Long signupId, @RequestBody(required = false) java.util.Map<String, Object> body)
    {
        LoginMember m = requireMerchantLogin();
        BookingMember bm = bookingService.selectBookingMemberById(signupId);
        if (bm == null) return AjaxResult.error("报名记录不存在");
        Booking parent = bookingService.selectBookingByBookingId(bm.getBookingId());
        if (parent == null || !m.getStoreId().equals(parent.getStoreId())) return AjaxResult.error("无权操作该报名");
        if ("1".equals(bm.getStatus())) return AjaxResult.error("该报名已取消");
        if ("2".equals(bm.getStatus())) return AjaxResult.error("已确认，不能拒绝");
        if ("3".equals(bm.getStatus())) return AjaxResult.error("该报名已拒绝");
        String reason = body == null ? null : String.valueOf(body.get("reason"));
        if (reason == null || reason.trim().isEmpty()) return AjaxResult.error("请填写拒绝原因");
        bm.setStatus("3");
        bm.setConfirmUser(m.getMemberId() == null ? "merchant-staff" : ("mstaff-" + m.getMemberId()));
        bm.setConfirmTime(new Date());
        bm.setReviewRemark(reason);
        bookingService.updateBookingMember(bm);
        return AjaxResult.success("已拒绝");
    }

    @LoginRequired
    @GetMapping("/booking/signup/list")
    public AjaxResult bookingSignupList()
    {
        LoginMember m = requireMerchantLogin();
        Booking q = new Booking(); q.setStoreId(m.getStoreId());
        List<Booking> bookings = bookingService.selectBookingList(q);
        List<java.util.Map<String, Object>> out = new ArrayList<>();
        for (Booking b : bookings) {
            BookingMember bmq = new BookingMember(); bmq.setBookingId(b.getBookingId());
            List<BookingMember> members = bookingService.selectBookingMemberList(bmq);
            for (BookingMember bm : members) {
                java.util.Map<String, Object> o = new HashMap<>();
                o.put("signupId", bm.getId());
                o.put("bookingId", b.getBookingId());
                o.put("bookingDate", b.getBookingDate());
                o.put("bookingTime", b.getTimeSlot());
                o.put("storeName", b.getStoreName());
                o.put("memberId", bm.getMemberId());
                o.put("memberName", bm.getMemberName());
                o.put("memberPhone", bm.getPhone());
                o.put("status", bm.getStatus());
                o.put("confirmUser", bm.getConfirmUser());
                o.put("confirmTime", bm.getConfirmTime());
                o.put("reviewRemark", bm.getReviewRemark());
                o.put("signupTime", bm.getBookingDate());
                out.add(o);
            }
        }
        out.sort((a, b) -> {
            String t1 = String.valueOf(a.get("signupTime")); if (t1 == null) t1 = "";
            String t2 = String.valueOf(b.get("signupTime")); if (t2 == null) t2 = "";
            return t2.compareTo(t1); // String compare as fallback (dates are yyyy-MM-dd)
        });
        return AjaxResult.success(out);
    }

    // ===== 时间工具 =====
    private static Date startOfToday()
    {
        Calendar c = Calendar.getInstance();
        c.set(Calendar.HOUR_OF_DAY, 0); c.set(Calendar.MINUTE, 0);
        c.set(Calendar.SECOND, 0); c.set(Calendar.MILLISECOND, 0);
        return c.getTime();
    }
    private static Date endOfToday()
    {
        Calendar c = Calendar.getInstance();
        c.set(Calendar.HOUR_OF_DAY, 23); c.set(Calendar.MINUTE, 59);
        c.set(Calendar.SECOND, 59); c.set(Calendar.MILLISECOND, 999);
        return c.getTime();
    }
    private static boolean isSameDay(Date a, Date b)
    {
        if (a == null || b == null) return false;
        Calendar x = Calendar.getInstance(); x.setTime(a);
        Calendar y = Calendar.getInstance(); y.setTime(b);
        return x.get(Calendar.YEAR) == y.get(Calendar.YEAR)
            && x.get(Calendar.DAY_OF_YEAR) == y.get(Calendar.DAY_OF_YEAR);
    }
    private String randomSix()
    {
        String chars = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
        StringBuilder sb = new StringBuilder(6);
        java.util.Random r = new java.util.Random();
        for (int i = 0; i < 6; i++) sb.append(chars.charAt(r.nextInt(chars.length())));
        return sb.toString();
    }
}
