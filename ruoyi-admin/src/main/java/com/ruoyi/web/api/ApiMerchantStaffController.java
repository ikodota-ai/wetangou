package com.ruoyi.web.api;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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
import com.ruoyi.common.enums.DesensitizedType;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.exception.ServiceException;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.biz.api.annotation.LoginRequired;
import com.ruoyi.biz.api.annotation.RequireRole;
import com.ruoyi.biz.api.role.BizRole;
import com.ruoyi.biz.api.domain.LoginMember;
import com.ruoyi.biz.domain.Agent;
import com.ruoyi.biz.api.service.WxMaService;
import com.ruoyi.biz.api.util.MemberContextHolder;
import com.ruoyi.biz.api.util.MemberTokenService;
import com.ruoyi.biz.api.util.StaffLoginMemberBuilder;
import com.ruoyi.biz.domain.MerchantStaff;
import com.ruoyi.biz.domain.MerchantStaffInvite;
import com.ruoyi.biz.domain.Store;
import com.ruoyi.biz.domain.Booking;
import com.ruoyi.biz.domain.BookingMember;
import com.ruoyi.biz.domain.Order;
import com.ruoyi.biz.domain.PayBill;
import com.ruoyi.biz.service.IMerchantStaffInviteService;
import com.ruoyi.biz.service.IMerchantStaffService;
import com.ruoyi.biz.service.IAgentService;
import com.ruoyi.biz.service.IOrderService;
import com.ruoyi.biz.service.IPayBillService;
import com.ruoyi.biz.service.IBookingService;
import com.ruoyi.biz.service.IStoreService;
import com.ruoyi.system.service.ISysUserService;
import com.ruoyi.system.mapper.SysRoleMapper;
import com.ruoyi.common.core.domain.entity.SysRole;
import com.ruoyi.common.constant.TenantConstants;
import com.ruoyi.biz.api.role.BizRole;

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
    /** biz_merchant_staff.status：0=在职 1=离职 3=待审核 */
    private static final String STAFF_STATUS_ACTIVE = "0";
    private static final String STAFF_STATUS_PENDING = "3";

    private static final Logger log = LoggerFactory.getLogger(ApiMerchantStaffController.class);

    @Autowired private ISysUserService userService;
    @Autowired private SysRoleMapper roleMapper;
    @Autowired private com.ruoyi.framework.config.ServerConfig serverConfig;

    /** PC 后台「商户管理员」角色的 role_key（老板/店长复用） */
    private static final String MERCHANT_PC_ROLE_KEY = "merchant";
    @Autowired private IMerchantStaffService staffService;
    @Autowired
    private IAgentService agentService;
    @Autowired private IMerchantStaffInviteService inviteService;
    @Autowired private MemberTokenService memberTokenService;
    @Autowired private WxMaService wxMaService;
    @Autowired private IStoreService storeService;
    @Autowired private IOrderService orderService;
    @Autowired private IPayBillService payBillService;
    @Autowired private IBookingService bookingService;
    @Autowired private com.ruoyi.biz.service.IMerchantService merchantService;
    @Autowired private com.ruoyi.biz.service.ITenantService tenantService;

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

        // 必须有商家员工关联（平台/代理商可无关联）
        // 必须绕开租户 SQL 过滤：MemberAuthInterceptor 对匿名 /api/** 会按 X-App-Id 设租户上下文，
        // 未带/未匹配 appid 时兜底为默认商户 1，于是 TenantSqlInterceptor 会给这条查询追加
        // "and ms.merchant_id = 1"。按 user_id 查自己的员工关联属于身份解析，商户归属由账号本身决定，
        // 被 appid 上下文限制会导致「商户 201 的老板用密码登录报该账号未关联商家」。
        List<MerchantStaff> allLinks = com.ruoyi.common.utils.TenantContextHolder.ignoreTenant(
                () -> staffService.selectList(new MerchantStaff() {{ setUserId(user.getUserId()); }}));
        String ut = user.getUserType();
        // 平台/代理商可无员工关联；但一旦有关联就说明是商户侧账号，不再当特权处理
        boolean isPrivileged = ("00".equals(ut) || "01".equals(ut)) && (allLinks == null || allLinks.isEmpty());
        // 只认在职关联：待审核/离职不得登录商家端
        List<MerchantStaff> links = filterActiveLinks(allLinks);
        if (links.isEmpty() && !isPrivileged) {
            if (hasPendingLink(allLinks)) {
                throw new ServiceException("入职申请待店长审核通过后才能登录", 601);
            }
            throw new ServiceException("该账号未关联商家");
        }

        // 密码登录成功后自动绑定当前微信 openid，让该员工下次能免密切换。
        // 仅在「本账号尚未绑过」且「该 openid 未被别的账号占用」时绑，避免 A 在 B 手机上登录导致绑错人。
        boolean autoBound = autoBindOpenid(user, body);

        // 根据 user_type 决定顶层 userType 字符串
        String topUserType;
        if ("00".equals(ut)) topUserType = "platform";
        else if ("01".equals(ut)) topUserType = "agent";
        else topUserType = "merchant"; // 占位，会被 buildLoginMember 按 role 覆盖

        LoginMember lm = buildLoginMember(user, links == null ? java.util.Collections.emptyList() : links, topUserType);
        String token = memberTokenService.createToken(lm);
        lm.setToken(token);

        AjaxResult r = packLoginResult(lm, user, links);
        r.put("openidAutoBound", autoBound);
        return r;
    }

    /**
     * 密码登录时顺带绑定微信 openid（幂等、失败不阻断登录）。
     *
     * @return true 表示本次真的写入了绑定关系
     */
    private boolean autoBindOpenid(SysUser user, JSONObject body)
    {
        String wxCode = body.getString("code");
        if (StringUtils.isEmpty(wxCode)) {
            return false;
        }
        // 已经绑过就不动（换绑必须由 admin 先解绑，避免把老 openid 悄悄顶掉）
        if (StringUtils.isNotEmpty(user.getOpenid())) {
            return false;
        }
        try {
            Long mid = body.getLong("merchantId");
            if (mid == null) {
                mid = resolveMerchantIdByAppid(body.getString("appid"));
            }
            JSONObject session = wxMaService.code2Session(wxCode, mid);
            String openid = session.getString("openid");
            if (StringUtils.isEmpty(openid)) {
                return false;
            }
            SysUser exist = userService.selectUserByOpenId(openid);
            if (exist != null && !exist.getUserId().equals(user.getUserId())) {
                // 该微信已归属其他员工账号，不抢绑
                return false;
            }
            userService.bindOpenid(user.getUserId(), openid);
            return true;
        } catch (Exception e) {
            // 自动绑定是增强项，失败不能影响密码登录本身
            return false;
        }
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
        // 商户定向优先级：显式 merchantId > 按小程序 appid 解析（多商户下由当前 appid 决定身份归属）
        Long merchantId = body.getLong("merchantId");
        if (merchantId == null) {
            merchantId = resolveMerchantIdByAppid(body.getString("appid"));
        }

        JSONObject session = wxMaService.code2Session(code, merchantId);
        String openid = session.getString("openid");
        if (StringUtils.isEmpty(openid)) throw new ServiceException("微信登录失败");

        SysUser user = userService.selectUserByOpenId(openid);
        if (user == null) throw new ServiceException("NOT_BOUND", 600); // 600: 尚未绑定，前端引导走"扫码邀请"流程
        if (!"0".equals(user.getStatus())) throw new ServiceException("账号已被停用");

        // 必须绕开租户 SQL 过滤：MemberAuthInterceptor 对匿名 /api/** 会按 X-App-Id 设租户上下文，
        // 未带/未匹配 appid 时兜底为默认商户 1，于是 TenantSqlInterceptor 会给这条查询追加
        // "and ms.merchant_id = 1"。按 user_id 查自己的员工关联属于身份解析，商户归属由账号本身决定，
        // 被 appid 上下文限制会导致「商户 201 的老板用密码登录报该账号未关联商家」。
        List<MerchantStaff> allLinks = com.ruoyi.common.utils.TenantContextHolder.ignoreTenant(
                () -> staffService.selectList(new MerchantStaff() {{ setUserId(user.getUserId()); }}));
        String ut = user.getUserType();
        boolean isPrivileged = ("00".equals(ut) || "01".equals(ut)) && (allLinks == null || allLinks.isEmpty());
        // 一个 openid 可能在多个商户下都有员工关联；当前小程序 appid 决定用哪一份身份
        allLinks = filterLinksByMerchant(allLinks, merchantId);
        // 只认在职关联：待审核/离职不得登录商家端
        List<MerchantStaff> links = filterActiveLinks(allLinks);
        if (links.isEmpty() && !isPrivileged) {
            if (hasPendingLink(allLinks)) {
                throw new ServiceException("入职申请待店长审核通过后才能登录", 601);
            }
            throw new ServiceException("NOT_BOUND", 600);
        }

        String topUserType;
        if ("00".equals(ut)) topUserType = "platform";
        else if ("01".equals(ut)) topUserType = "agent";
        else topUserType = "merchant";

        LoginMember lm = buildLoginMember(user, links == null ? java.util.Collections.emptyList() : links, topUserType);
        String token = memberTokenService.createToken(lm);
        lm.setToken(token);

        return packLoginResult(lm, user, links);
    }

    /**
     * 接受邀请（扫商家邀请码后用）
     * 入参: { code: 微信jscode, scene: invite:MID:SID:CODE, merchantId?, profile? }
     * 自动建账号（若 openid 未绑） + 绑门店 + 微信登录
     */
    /**
     * 接受邀请（小程序匿名端点）
     *
     * <p>业务流：scene 解析 → 邀请码状态校验（含过期自动转 status=2）→ 微信 code2Session
     *   → openid 命中复用/未命中建账号 → 绑员工关联 → 邀请码置已用 → 自动登录
     *
     * <p>事务：全部 DB 写入（过期态更新 + 邀请码置已用 + 员工关联）放在同一事务。
     * 任何一步失败则全部回滚，避免出现「邀请码已用但员工未绑」或「员工已绑但邀请码仍启用」的不一致态。
     *
     * <p>状态机：status 0→1（已用）/ 0→2（过期）/ 0→3（停用）单向迁移。
     */
    @Transactional(rollbackFor = Exception.class)
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
            // 过期：调用 REQUIRES_NEW 事务独立提交 status=2，再抛错
            // 避免外层 @Transactional 回滚把过期态也吃掉，导致下次再调仍走过期分支（永远卡 status=0）
            inviteService.markExpired(invite.getInviteId());
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
        List<MerchantStaff> links = com.ruoyi.common.utils.TenantContextHolder.ignoreTenant(
                () -> staffService.selectList(new MerchantStaff() {{ setUserId(boundUser.getUserId()); }}));
        MerchantStaff existLink = null;
        if (links != null) {
            for (MerchantStaff l : links) {
                if (sid.equals(l.getStoreId()) && mid.equals(l.getMerchantId())) { existLink = l; break; }
            }
        }
        if (existLink == null)
        {
            MerchantStaff ms = new MerchantStaff();
            ms.setMerchantId(mid);
            ms.setStoreId(sid);
            ms.setUserId(user.getUserId());
            ms.setRole(invite.getRole() == null ? "STAFF" : invite.getRole());
            // 扫码入职默认「待审核」，需 OWNER/MANAGER 在后台 /biz/staffInvite/staff/audit 通过后才在职。
            // 邀请码可能被转发/截图外传，直接给 status=0 等于任何人扫到就能核销。
            ms.setStatus(STAFF_STATUS_PENDING);
            ms.setCreateTime(new Date());
            staffService.insert(ms);
            // 重新查关联
            links = com.ruoyi.common.utils.TenantContextHolder.ignoreTenant(
                    () -> staffService.selectList(new MerchantStaff() {{ setUserId(boundUser.getUserId()); }}));
        }

        // 6) 标记邀请码已用
        invite.setUsedAt(new Date());
        invite.setUsedBy(user.getUserId());
        invite.setStatus("1");
        inviteService.update(invite);

        // 7) 只有「已在职」的关联才发 token。
        //    待审核（status=3）时账号与 openid 已落库，但不给商家端登录态，
        //    否则审核形同虚设（扫到码即可核销）。
        List<MerchantStaff> activeLinks = filterActiveLinks(links);
        if (activeLinks.isEmpty())
        {
            AjaxResult pending = AjaxResult.success("已提交入职申请，请等待店长审核");
            pending.put("pendingAudit", true);
            pending.put("userId", user.getUserId());
            pending.put("merchantId", mid);
            pending.put("storeId", sid);
            pending.put("openidBound", 1);
            pending.put("needBindWx", false);
            pending.put("token", null);
            return pending;
        }

        LoginMember lm = buildLoginMember(user, activeLinks, "merchant");
        String token = memberTokenService.createToken(lm);
        lm.setToken(token);

        AjaxResult ok = packLoginResult(lm, user, activeLinks);
        ok.put("pendingAudit", false);
        return ok;
    }

    /** 绑定当前登录员工的微信（首次登录后必做） */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER, BizRole.STAFF}, includeHigher = true)
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
        if (exist != null && !exist.getUserId().equals(lm.getStaffUserId())) {
            throw new ServiceException("该微信已绑定其他账号");
        }

        SysUser user = userService.selectUserByUserId(lm.getStaffUserId());
        if (user == null) throw new ServiceException("员工账号不存在");
        // 走专用语句：updateUser 的动态 set 不含 openid 列
        userService.bindOpenid(user.getUserId(), openid);

        AjaxResult r = AjaxResult.success("绑定成功");
        r.put("openid", openid);
        return r;
    }

    /** 当前商家员工信息 */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER, BizRole.STAFF}, includeHigher = true)
    @GetMapping("/me")
    public AjaxResult me()
    {
        LoginMember lm = MemberContextHolder.get();
        if (lm == null) throw new ServiceException("未登录");
        SysUser u = userService.selectUserByUserId(lm.getStaffUserId());
        MerchantStaff ms = staffService.selectByUserId(lm.getStaffUserId());

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
            r.put("phone", DesensitizedType.PHONE.desensitizer().apply(ms.getPhone()));
            r.put("staffNo", ms.getStaffNo());
        }
        return AjaxResult.success(r);
    }

    /**
     * 商家端：营收汇总 demo（仅 OWNER/MANAGER 可访问，STAFF/AGENT/PATFORM 不可）
     *
     * <p>平台账号可在小程序端跨店查看，但通过单独的 /api/platform/finance 接口
     * （不在本 Controller，未来加在 ApiPlatformController）</p>
     */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER}, includeHigher = true)
    @GetMapping("/finance/summary")
    public AjaxResult financeSummary()
    {
        LoginMember m = MemberContextHolder.get();
        Long merchantId = m.getMerchantId();
        if (merchantId == null) throw new ServiceException("未关联商家");
        java.math.BigDecimal totalRevenue = java.math.BigDecimal.ZERO;
        int totalOrders = 0;
        // 这里仅 demo：实际从 biz_order / biz_pay_bill 汇总
        com.ruoyi.biz.domain.Order q = new com.ruoyi.biz.domain.Order();
        q.setMerchantId(merchantId);
        java.util.List<com.ruoyi.biz.domain.Order> orders = orderService.selectOrderList(q);
        for (com.ruoyi.biz.domain.Order o : orders) {
            totalOrders++;
            if (o.getPayAmount() != null) totalRevenue = totalRevenue.add(o.getPayAmount());
        }
        java.util.HashMap<String, Object> data = new java.util.HashMap<>();
        data.put("merchantId", merchantId);
        data.put("totalRevenue", totalRevenue);
        data.put("totalOrders", totalOrders);
        data.put("roles", m.getRoles() == null ? java.util.Collections.emptyList() :
                m.getRoles().stream().map(Enum::name).collect(java.util.stream.Collectors.toList()));
        return AjaxResult.success(data);
    }


    /** 补录员工姓名/手机号（用户后续自助补全） */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER, BizRole.STAFF}, includeHigher = true)
    @PostMapping("/profile")
    public AjaxResult updateProfile(@RequestBody JSONObject body)
    {
        LoginMember lm = MemberContextHolder.get();
        if (lm == null) throw new ServiceException("未登录");
        String realName = body.getString("realName");
        String phone = body.getString("phone");
        if (realName == null && phone == null) throw new ServiceException("无更新内容");

        MerchantStaff upd = new MerchantStaff();
        upd.setUserId(lm.getStaffUserId());
        upd.setRealName(realName);
        upd.setPhone(phone);
        upd.setUpdateBy(String.valueOf(lm.getStaffUserId()));
        upd.setUpdateTime(new Date());
        staffService.updateByUserId(upd);
        return AjaxResult.success("已更新");
    }

    
    /**
     * 平台端：跨店营收汇总
     *
     * <p>参数：</p>
     * <ul>
     *   <li>agentId=null 或 0 → 全部商家</li>
     *   <li>agentId=X → 仅该代理商名下商家</li>
     *   <li>scope=SELF_MANAGED → 自营商家（agent_id=0 / null）</li>
     * </ul>
     */
    @LoginRequired
    @RequireRole(BizRole.PLATFORM)
    @GetMapping("/platform/finance/summary")
    public AjaxResult platformFinanceSummary(java.lang.Long agentId, String scope)
    {
        LoginMember m = MemberContextHolder.get();
        if (!m.isOwner() && !m.hasAnyRole(BizRole.PLATFORM)) {
            // 拦截器已挡，这里双保险
            throw new ServiceException("无权限");
        }
        // 汇总维度
        java.math.BigDecimal totalRevenue = java.math.BigDecimal.ZERO;
        int totalOrders = 0;
        int totalMerchants = 0;
        com.ruoyi.biz.domain.Order q = new com.ruoyi.biz.domain.Order();
        java.util.List<com.ruoyi.biz.domain.Order> orders = orderService.selectOrderList(q);
        for (com.ruoyi.biz.domain.Order o : orders) {
            // 过滤：agentId 匹配 或 SELF_MANAGED
            if (agentId != null && agentId > 0) {
                // 检查 merchant 关联的 agent_id
                Long mAgentId = resolveMerchantAgentId(o.getMerchantId());
                if (mAgentId == null || !agentId.equals(mAgentId)) continue;
            } else if ("SELF_MANAGED".equalsIgnoreCase(scope)) {
                Long mAgentId = resolveMerchantAgentId(o.getMerchantId());
                if (mAgentId != null && mAgentId > 0) continue;
            }
            totalOrders++;
            if (o.getPayAmount() != null) totalRevenue = totalRevenue.add(o.getPayAmount());
        }
        java.util.HashMap<String, Object> data = new java.util.HashMap<>();
        data.put("agentId", agentId);
        data.put("scope", scope == null ? "ALL" : scope);
        data.put("totalRevenue", totalRevenue);
        data.put("totalOrders", totalOrders);
        data.put("roles", m.getRoles() == null ? java.util.Collections.emptyList() :
                m.getRoles().stream().map(Enum::name).collect(java.util.stream.Collectors.toList()));
        return AjaxResult.success(data);
    }

    /**
     * helper: 查 merchant 关联的 agent_id
     */
    private Long resolveMerchantAgentId(Long merchantId)
    {
        if (merchantId == null) return null;
        try {
            com.ruoyi.biz.domain.Merchant mer = merchantService.selectMerchantByMerchantId(merchantId);
            return mer == null ? null : mer.getAgentId();
        } catch (Exception e) {
            return null;
        }
    }

/**
     * 商家端切换当前门店。
     *
     * <p>为什么要新加一个：已有的 {@code /api/store/staff/switch-store} 第一行就判
     * {@code !"store".equals(lm.getUserType())} 直接抛「此操作仅限门店端员工」，
     * 而商家端登录链路发的 userType 是 owner/manager/staff —— 也就是说商家端
     * 任何角色调那个端点都必然失败（实测店员 staff001 绑了 3 个店，调用返
     * {"msg":"此操作仅限门店端员工","code":500}）。核销页里那段切店代码是死代码。</p>
     *
     * <p>只允许切到本次登录已解析出的 storeIds 内（老板 store_id=0 已在登录时
     * 展开成该商户全部门店），避免越权切到别家门店。</p>
     */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER, BizRole.STAFF}, includeHigher = true)
    @PostMapping("/switch-store")
    public AjaxResult switchStore(@RequestBody JSONObject body)
    {
        LoginMember lm = MemberContextHolder.get();
        if (lm == null) throw new ServiceException("未登录");
        Long targetStoreId = body == null ? null : body.getLong("storeId");
        if (targetStoreId == null) throw new ServiceException("请选择目标门店");
        if (lm.getStoreIds() == null || !lm.getStoreIds().contains(targetStoreId))
        {
            throw new ServiceException("无权切换到该门店");
        }
        lm.setStoreId(targetStoreId);
        // 刷新 token 缓存，后续请求才能看到新的 storeId
        memberTokenService.refreshToken(lm);

        Store st = storeService.selectStoreByStoreId(targetStoreId);
        AjaxResult ajax = AjaxResult.success("已切换门店");
        ajax.put("storeId", targetStoreId);
        ajax.put("storeName", st == null ? "" : st.getStoreName());
        ajax.put("storeIds", lm.getStoreIds());
        ajax.put("stores", resolveStores(lm.getStoreIds()));
        return ajax;
    }

    /** 退出登录 */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER, BizRole.STAFF}, includeHigher = true)
    @PostMapping("/logout")
    public AjaxResult logout()
    {
        LoginMember lm = MemberContextHolder.get();
        if (lm != null && lm.getToken() != null) memberTokenService.delLoginMember(lm.getToken());
        return AjaxResult.success("已退出");
    }

    // ===== helpers =====

    /**
     * 构建登录身份
     *
     * <p>角色识别规则：</p>
     * <ol>
     *   <li>遍历 biz_merchant_staff 关联，取最高 role（OWNER > MANAGER > STAFF）写入 roles 集合</li>
     *   <li>根据最高 role 决定顶层 userType（owner/manager/staff）</li>
     *   <li>若 sys_user.user_type='01'（代理商/城市合伙人），额外加入 AGENT 角色</li>
     * </ol>
     */
    /**
     * 按小程序 appid 解析所属商户（多商户身份归属的判定依据）。
     *
     * <p>appid 为空时返回 null（表示不限定，沿用旧行为）；
     * appid 非空但查不到 / 商户停用时抛错，避免把 A 商户的微信登录到 B 商户。</p>
     */
    private Long resolveMerchantIdByAppid(String appid)
    {
        if (StringUtils.isEmpty(appid)) {
            return null;
        }
        com.ruoyi.biz.domain.Merchant merchant = tenantService.getMerchantByAppid(appid);
        if (merchant == null) {
            throw new ServiceException("小程序未接入或已停用：" + appid);
        }
        if (!"0".equals(merchant.getStatus())) {
            throw new ServiceException("商户已停用，请联系服务商");
        }
        return merchant.getMerchantId();
    }

    /**
     * 把员工关联收敛到指定商户。
     *
     * <p>merchantId 为空（未按 appid 定向）时原样返回；
     * 过滤后为空则也原样返回 —— 让调用方按"未关联商家"处理，
     * 而不是在这里静默降级到别家商户的身份。</p>
     */
    /**
     * 只保留「在职」员工关联（status=0）。
     *
     * <p>待审核（3）/ 离职（1）的关联不得进入登录态，否则：
     * 待审核 → 审核机制形同虚设；离职 → 前员工仍能核销。</p>
     */
    private List<MerchantStaff> filterActiveLinks(List<MerchantStaff> links)
    {
        List<MerchantStaff> hit = new ArrayList<>();
        if (links == null) return hit;
        for (MerchantStaff l : links) {
            // status 为空视为在职（兼容历史数据未回填的情况）
            if (l.getStatus() == null || STAFF_STATUS_ACTIVE.equals(l.getStatus())) {
                hit.add(l);
            }
        }
        return hit;
    }

    /** 关联里是否存在待审核记录（用于给前端「等待店长审核」提示） */
    private boolean hasPendingLink(List<MerchantStaff> links)
    {
        if (links == null) return false;
        for (MerchantStaff l : links) {
            if (STAFF_STATUS_PENDING.equals(l.getStatus())) return true;
        }
        return false;
    }

    private List<MerchantStaff> filterLinksByMerchant(List<MerchantStaff> links, Long merchantId)
    {
        if (merchantId == null || links == null || links.isEmpty()) {
            return links;
        }
        List<MerchantStaff> hit = new ArrayList<>();
        for (MerchantStaff l : links) {
            if (merchantId.equals(l.getMerchantId())) {
                hit.add(l);
            }
        }
        return hit;
    }

    /**
     * 构建商家端登录态。
     *
     * <p>实现收口到 {@link StaffLoginMemberBuilder}，与 {@code /api/auth/login}
     * 的会员授权链路共用同一份逻辑 —— 此前两处各有一份复制品，其中一份用
     * {@code BizRole.ordinal()} 挑最高角色（等级正好是反的），导致老板兼任店员后
     * 走会员授权链路会被降权成 STAFF。</p>
     */
    private LoginMember buildLoginMember(SysUser user, List<MerchantStaff> links, String userType)
    {
        return StaffLoginMemberBuilder.build(user, links, userType, uid -> {
            Agent agent = agentService.selectAgentByUserId(uid);
            return agent == null ? null : agent.getAgentId();
        }, this::storeIdsOfMerchant);
    }

    /** 查商户下全部启用门店 ID（用于把 store_id=0 展开成真实门店范围） */
    private java.util.List<Long> storeIdsOfMerchant(Long merchantId)
    {
        java.util.List<Long> out = new ArrayList<>();
        if (merchantId == null) return out;
        Store q = new Store();
        q.setMerchantId(merchantId);
        // 同上：展开 store_id=0 时按 merchantId 查门店，不能被 appid 兜底的租户上下文限制，
        // 否则商户 201 的老板会查到商户 1 的门店（或查不到任何门店）。
        java.util.List<Store> list = com.ruoyi.common.utils.TenantContextHolder.ignoreTenant(
                () -> storeService.selectStoreList(q));
        if (list != null)
        {
            for (Store st : list)
            {
                if (st.getStoreId() != null) out.add(st.getStoreId());
            }
        }
        return out;
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
        ajax.put("staffUserId", lm.getStaffUserId());
        ajax.put("userType", lm.getUserType());
        ajax.put("staffRole", lm.getStaffRole() == null ? null : lm.getStaffRole().name());
        ajax.put("roles", lm.getRoles() == null ? java.util.Collections.emptyList() :
                lm.getRoles().stream().map(Enum::name).collect(java.util.stream.Collectors.toList()));
        ajax.put("isOwner", lm.isOwner());
        ajax.put("isManagerOrAbove", lm.isManagerOrAbove());
        ajax.put("isAgent", lm.isAgent());
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
        // 商户员工身份：必须是 02，绝不能给 00（00 会在 buildLoginMember 里被判为 PLATFORM 角色，
        // 导致扫码入职的店员直接拿到平台越权：可读全平台商户/订单/员工名单）
        u.setUserType("02");
        u.setMerchantId(invite.getMerchantId()); // 多商户隔离
        // 必须同步 biz_merchant_user：PC 端的租户身份只认这张表（TenantServiceImpl.buildContextByUserId），
        // 查不到记录会兜底成「平台账号」。实测扫码入职的账号一旦拿到 PC 权限，
        // /biz/store/list 会返回 merchant_id=2/200 等别家门店 —— 跨商户数据泄漏。
        u.setTenantUserType(TenantConstants.USER_TYPE_MERCHANT);
        u.setTenantMerchantId(invite.getMerchantId());
        // 老板/店长要在 PC 后台审核下一个店员、发邀请码、重置密码，必须绑「商户管理员」角色；
        // 不绑角色则 permissions 为空集，实测 /biz/staffInvite/** 四个端点全 403，
        // 「店长审核店员」这一环直接断裂（招进来的第一个店长再也招不了人）。
        // 店员(STAFF)只在小程序端核销，不给 PC 角色。
        Long pcRoleId = resolvePcRoleId(invite.getRole());
        if (pcRoleId != null)
        {
            u.setRoleIds(new Long[] { pcRoleId });
        }
        userService.insertUser(u);
        return u;
    }

    /**
     * 按商家版角色映射 PC 后台角色；返回 null 表示不给后台权限。
     *
     * <p>role_key='merchant'（商户管理员）由 sys_role 查得，不写死 role_id ——
     * role_id 由建库时的插入顺序决定，各环境不一致。</p>
     *
     * <p>必须走 mapper 而不是 ISysRoleService.selectRoleList：后者带 @DataScope，
     * 会从 SecurityContext 取当前后台登录用户来拼数据范围。扫码入职是匿名请求
     * （@Anonymous，没有 PC 端 token），实测直接抛「获取用户信息异常」401，
     * 把整条入职链路打断。checkRoleKeyUnique 是精确匹配且不带数据范围切面。</p>
     */
    private Long resolvePcRoleId(String staffRole)
    {
        if (!"OWNER".equals(staffRole) && !"MANAGER".equals(staffRole))
        {
            return null;
        }
        SysRole role = roleMapper.checkRoleKeyUnique(MERCHANT_PC_ROLE_KEY);
        if (role != null && role.getRoleId() != null)
        {
            return role.getRoleId();
        }
        log.warn("[Staff] 未找到 role_key={} 的 PC 角色，{} 将没有后台权限", MERCHANT_PC_ROLE_KEY, staffRole);
        return null;
    }


    // =============================================================
    // 商家工作台（数据 / 核销 / 预约审核）
    // 端点对标旧 /api/store/staff/{home,today/*,booking/*}，
    // 区别：userType=merchant，门店 ID 直接用 token.storeId
    // =============================================================

    private LoginMember requireMerchantLogin()
    {
        return requireMerchantLogin(true);
    }

    /**
     * 商家端身份校验。
     *
     * @param needStore 是否必须已有激活门店。写操作（核销、审核预约）必须为 true；
     *                  只读的工作台首页传 false —— 平台刚建完商户时该商户还没有任何门店，
     *                  老板（store_id=0 展开后 storeIds 为空）第一次进商家版会被
     *                  「未绑定门店」500 挡成白屏，看不到任何提示也不知道下一步该干什么。
     *                  首页应该返回空数据 + needCreateStore 引导，而不是报错。
     */
    private LoginMember requireMerchantLogin(boolean needStore)
    {
        LoginMember m = MemberContextHolder.get();
        if (m == null) throw new ServiceException("未登录");
        String ut = m.getUserType();
        if (!("merchant".equals(ut) || "owner".equals(ut) || "manager".equals(ut) || "staff".equals(ut))) throw new ServiceException("非商家员工身份");
        if (needStore && m.getStoreId() == null)
        {
            // 老板/店长可自己建门店；店员只能等店长建好再分配
            throw new ServiceException(m.isManagerOrAbove()
                    ? "该商家还没有门店，请先创建门店"
                    : "你的账号还没有分配门店，请联系店长");
        }
        return m;
    }

    @LoginRequired
    @RequireRole(value = BizRole.STAFF, includeHigher = true)
    @GetMapping("/home")
    public AjaxResult dashboardHome()
    {
        LoginMember m = requireMerchantLogin(false);
        Long storeId = m.getStoreId();
        if (storeId == null)
        {
            // 商户还没有门店：返回空数据 + 引导标记，让商家端首页显示「先去创建门店」，
            // 而不是整页 500。needCreateStore 只对能建店的角色为 true。
            Map<String, Object> empty = new HashMap<>();
            empty.put("storeId", null);
            empty.put("storeName", "");
            empty.put("todayVerifyCount", 0);
            empty.put("todayVerifyAmount", java.math.BigDecimal.ZERO);
            empty.put("todayOrderCount", 0);
            empty.put("pendingBillCount", 0);
            empty.put("todayBookingCount", 0);
            empty.put("recentOrders", new ArrayList<Order>());
            empty.put("noStore", true);
            empty.put("needCreateStore", m.isManagerOrAbove());
            empty.put("noStoreTip", m.isManagerOrAbove()
                    ? "该商家还没有门店，请先在管理后台创建门店后再来经营"
                    : "你的账号还没有分配门店，请联系店长");
            return AjaxResult.success(empty);
        }
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
    @RequireRole(value = BizRole.STAFF, includeHigher = true)
    @GetMapping("/today/orders")
    public AjaxResult todayOrders()
    {
        LoginMember m = requireMerchantLogin(false);
        // 无门店（商户刚建、门店还没创建）→ 空列表，不报错
        if (m.getStoreId() == null) return AjaxResult.success(new ArrayList<Order>());
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
    @RequireRole(value = BizRole.STAFF, includeHigher = true)
    @GetMapping("/today/bills")
    public AjaxResult todayBills()
    {
        LoginMember m = requireMerchantLogin(false);
        if (m.getStoreId() == null) return AjaxResult.success(new ArrayList<PayBill>());
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
    @RequireRole(value = BizRole.STAFF, includeHigher = true)
    @GetMapping("/today/bookings")
    public AjaxResult todayBookings()
    {
        LoginMember m = requireMerchantLogin(false);
        if (m.getStoreId() == null) return AjaxResult.success(new ArrayList<Booking>());
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
        // 用授权门店集合判，不是只比当前激活门店：多店员工/老板（store_id=0 展开）
        // 不切店就审不了别的门店的报名
        if (parent == null || !m.hasStore(parent.getStoreId())) return AjaxResult.error("无权操作该报名");
        if ("1".equals(bm.getStatus())) return AjaxResult.error("该报名已取消");
        if ("2".equals(bm.getStatus())) return AjaxResult.error("该报名已确认");
        if ("3".equals(bm.getStatus())) return AjaxResult.error("该报名已拒绝");
        bm.setStatus("2");
        bm.setConfirmUser(m.getStaffUserId() == null ? "merchant-staff" : ("mstaff-" + m.getStaffUserId()));
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
        // 同 confirm：按授权门店集合判
        if (parent == null || !m.hasStore(parent.getStoreId())) return AjaxResult.error("无权操作该报名");
        if ("1".equals(bm.getStatus())) return AjaxResult.error("该报名已取消");
        if ("2".equals(bm.getStatus())) return AjaxResult.error("已确认，不能拒绝");
        if ("3".equals(bm.getStatus())) return AjaxResult.error("该报名已拒绝");
        String reason = body == null ? null : String.valueOf(body.get("reason"));
        if (reason == null || reason.trim().isEmpty()) return AjaxResult.error("请填写拒绝原因");
        bm.setStatus("3");
        bm.setConfirmUser(m.getStaffUserId() == null ? "merchant-staff" : ("mstaff-" + m.getStaffUserId()));
        bm.setConfirmTime(new Date());
        bm.setReviewRemark(reason);
        bookingService.updateBookingMember(bm);
        return AjaxResult.success("已拒绝");
    }

    @LoginRequired
    @GetMapping("/booking/signup/list")
    public AjaxResult bookingSignupList()
    {
        LoginMember m = requireMerchantLogin(false);
        if (m.getStoreId() == null) return AjaxResult.success(new ArrayList<java.util.Map<String, Object>>());
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
                o.put("memberPhone", DesensitizedType.PHONE.desensitizer().apply(bm.getPhone()));
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

    // =============================================================
    // 商家端「店员管理」（OWNER / MANAGER）
    //
    // 为什么必须做在小程序里：招店员的四个动作（看名单、审待审、发邀请码、重置密码）
    // 此前只有 PC 后台有。而店长的实际工作场景就在店里、手上只有手机 ——
    // 新店员站在柜台前扫码入职，店长得先跑去开电脑登后台才能点通过，
    // 这个流程在真实门店里没人会走。店员管理是商家端最基础的一环，不能只在 PC 上。
    //
    // 权限：OWNER / MANAGER 才可见（STAFF 只核销，不得管人，否则店员能给自己发
    // OWNER 邀请码提权）。范围一律按 token 里的 merchantId + 授权门店集合判，
    // 不信任请求体传上来的任何 id。
    // =============================================================

    /** 商家端可管理的角色白名单：绝不能放开到任意字符串，否则能造出未定义角色 */
    private static final java.util.List<String> ASSIGNABLE_ROLES = java.util.Arrays.asList("MANAGER", "STAFF");

    /**
     * 店员名单（当前商户，按授权门店过滤）。
     *
     * <p>status: 0 在职 / 1 离职 / 3 待审核。手机号脱敏后返回 ——
     * 店长看名单不需要完整号码，避免整店员工手机号在小程序端明文流转。</p>
     */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER})
    @GetMapping("/staff/list")
    public AjaxResult staffList(@RequestParam(required = false) String status)
    {
        LoginMember m = requireMerchantLogin(false);
        MerchantStaff q = new MerchantStaff();
        q.setMerchantId(m.getMerchantId());
        if (StringUtils.isNotEmpty(status)) q.setStatus(status);
        List<MerchantStaff> list = staffService.selectList(q);
        List<Map<String, Object>> out = new ArrayList<>();
        if (list != null)
        {
            for (MerchantStaff ms : list)
            {
                // 老板 store_id=0（全商户），其名下门店集合已在登录时展开；
                // 这里按授权门店过滤，店长只该看到自己管的门店的人。
                if (!isStaffVisible(m, ms)) continue;
                out.add(toStaffView(ms));
            }
        }
        return AjaxResult.success(out);
    }

    /** 待审核列表（扫码入职后 status=3，等 OWNER/MANAGER 点通过） */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER})
    @GetMapping("/staff/audit/list")
    public AjaxResult staffAuditList()
    {
        return staffList("3");
    }

    /**
     * 审核扫码入职申请：approve=true → 在职；false → 删除关联（账号保留，可重发码）。
     *
     * <p>与 PC 端 BizStaffInviteController.audit 同语义，差别只在身份来源：
     * 这里用小程序 token 的 merchantId + 门店集合，PC 端用 TenantFilterHelper。</p>
     */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER})
    @PostMapping("/staff/audit")
    public AjaxResult staffAudit(@RequestBody Map<String, Object> body)
    {
        LoginMember m = requireMerchantLogin(false);
        Long id = asLong(body == null ? null : body.get("id"));
        if (id == null) return AjaxResult.error("缺少 id");
        Object approveRaw = body.get("approve");
        if (approveRaw == null) return AjaxResult.error("缺少 approve 字段");
        boolean approve = Boolean.parseBoolean(String.valueOf(approveRaw));

        MerchantStaff db = staffService.selectById(id);
        if (db == null) return AjaxResult.error("员工关联不存在");
        if (!isStaffVisible(m, db)) return AjaxResult.error("无权审核该员工");
        if (!STAFF_STATUS_PENDING.equals(db.getStatus())) return AjaxResult.error("该员工不在待审核状态");
        // 不许审出一个比自己权限还高的人（店长审出老板 = 自我提权）
        if (!canManageRole(m, db.getRole())) return AjaxResult.error("无权审核该角色的员工");

        if (approve)
        {
            db.setStatus("0");
            db.setUpdateBy(currentStaffTag(m));
            return staffService.update(db) > 0 ? AjaxResult.success("已通过") : AjaxResult.error("操作失败");
        }
        return staffService.deleteById(db.getId()) > 0 ? AjaxResult.success("已拒绝") : AjaxResult.error("操作失败");
    }

    /**
     * 生成店员邀请码（含小程序码，供店长在店里当场让新人「扫一扫」）。
     *
     * <p>storeId 不传时默认当前激活门店；传了必须在授权门店集合内 ——
     * 否则会造出「自己商户 + 别家门店」的死码（PC 端同型缺陷已修，见
     * BizStaffInviteController.add 的注释）。</p>
     */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER})
    @PostMapping("/staff/invite")
    public AjaxResult createStaffInvite(@RequestBody(required = false) Map<String, Object> body)
    {
        LoginMember m = requireMerchantLogin();
        Long storeId = asLong(body == null ? null : body.get("storeId"));
        if (storeId == null) storeId = m.getStoreId();
        if (storeId == null) return AjaxResult.error("请先选择门店");
        if (!m.hasStore(storeId)) return AjaxResult.error("无权为该门店招人");

        String role = body == null ? null : trimToNull(body.get("role"));
        if (role == null) role = "STAFF";
        role = role.toUpperCase();
        if (!ASSIGNABLE_ROLES.contains(role)) return AjaxResult.error("只能邀请店长或店员");
        if (!canManageRole(m, role)) return AjaxResult.error("无权邀请该角色");

        MerchantStaffInvite inv = new MerchantStaffInvite();
        inv.setMerchantId(m.getMerchantId());
        inv.setStoreId(storeId);
        inv.setRole(role);
        inv.setInviteCode(inviteService.generateShortCode());
        // 默认 7 天有效：邀请码会被转发/截图，长期有效等于长期可提权
        inv.setExpireAt(new Date(System.currentTimeMillis() + 7L * 24 * 3600 * 1000));
        inv.setScene("invite:" + m.getMerchantId() + ":" + storeId + ":AUTO");
        inv.setStatus("0");
        inv.setCreateBy(currentStaffTag(m));
        if (inviteService.insert(inv) <= 0) return AjaxResult.error("生成失败");

        AjaxResult r = AjaxResult.success("已生成邀请码：" + inv.getInviteCode());
        r.put("inviteCode", inv.getInviteCode());
        r.put("inviteId", inv.getInviteId());
        r.put("role", role);
        r.put("storeId", storeId);
        r.put("expireAt", inv.getExpireAt());
        // 小程序码生成失败不阻塞：店长仍可口述 6 位短码让新人手输
        try
        {
            String scene = "invite:" + m.getMerchantId() + ":" + storeId + ":" + inv.getInviteCode();
            byte[] png = wxMaService.getWxaCodeUnlimited(scene, "pages/merchant/scan/index", m.getMerchantId());
            if (png != null && png.length > 0)
            {
                String dir = com.ruoyi.common.config.RuoYiConfig.getProfile() + "/staffInvite";
                java.io.File dirFile = new java.io.File(dir);
                if (dirFile.exists() || dirFile.mkdirs())
                {
                    String fileName = "inv_" + inv.getInviteCode() + "_" + System.currentTimeMillis() + ".png";
                    java.io.File target = new java.io.File(dir, fileName);
                    try (java.io.FileOutputStream fos = new java.io.FileOutputStream(target)) { fos.write(png); }
                    String fullUrl = serverConfig.getUrl() + com.ruoyi.common.constant.Constants.RESOURCE_PREFIX
                            + "/staffInvite/" + fileName;
                    inv.setWxacodeUrl(fullUrl);
                    inviteService.update(inv);
                    r.put("wxacodeUrl", fullUrl);
                }
            }
        }
        catch (Exception ex)
        {
            log.warn("[Staff] 商家端邀请码小程序码生成失败 code={}", inv.getInviteCode(), ex);
        }
        return r;
    }

    /**
     * 取某张邀请码的小程序码（供海报页画图用）。
     *
     * <p>已有 wxacodeUrl 直接复用，不重复调微信接口 —— wxacodeUnlimited 有日调用
     * 配额，店长每次进海报页都重新生成会白烧配额（PC 端 /biz/staffInvite/qrcode
     * 就是每次都重新落一个新文件，同一张码在磁盘上会堆出好几份）。</p>
     */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER})
    @GetMapping("/staff/invite/qrcode/{inviteId}")
    public AjaxResult staffInviteQrcode(@PathVariable("inviteId") Long inviteId)
    {
        LoginMember m = requireMerchantLogin(false);
        MerchantStaffInvite inv = inviteService.selectById(inviteId);
        if (inv == null) return AjaxResult.error("邀请码不存在");
        if (inv.getMerchantId() == null || !inv.getMerchantId().equals(m.getMerchantId())
                || inv.getStoreId() == null || !m.hasStore(inv.getStoreId()))
        {
            return AjaxResult.error("无权查看该邀请码");
        }
        String scene = "invite:" + inv.getMerchantId() + ":" + inv.getStoreId() + ":" + inv.getInviteCode();
        AjaxResult r = AjaxResult.success();
        r.put("inviteCode", inv.getInviteCode());
        r.put("scene", scene);
        r.put("role", inv.getRole());
        if (StringUtils.isNotEmpty(inv.getWxacodeUrl()))
        {
            r.put("url", inv.getWxacodeUrl());
            r.put("cached", true);
            return r;
        }
        try
        {
            byte[] png = wxMaService.getWxaCodeUnlimited(scene, "pages/merchant/scan/index", inv.getMerchantId());
            if (png == null || png.length == 0) return AjaxResult.error("生成小程序码失败");
            String dir = com.ruoyi.common.config.RuoYiConfig.getProfile() + "/staffInvite";
            java.io.File dirFile = new java.io.File(dir);
            if (!dirFile.exists() && !dirFile.mkdirs()) return AjaxResult.error("无法创建目录");
            String fileName = "inv_" + inv.getInviteCode() + "_" + System.currentTimeMillis() + ".png";
            try (java.io.FileOutputStream fos = new java.io.FileOutputStream(new java.io.File(dir, fileName)))
            {
                fos.write(png);
            }
            String fullUrl = serverConfig.getUrl() + com.ruoyi.common.constant.Constants.RESOURCE_PREFIX
                    + "/staffInvite/" + fileName;
            inv.setWxacodeUrl(fullUrl);
            inviteService.update(inv);
            r.put("url", fullUrl);
            r.put("cached", false);
            return r;
        }
        catch (Exception ex)
        {
            log.error("[Staff] 邀请码小程序码生成失败 inviteId={}", inviteId, ex);
            return AjaxResult.error("生成小程序码失败");
        }
    }

    /** 本店未使用且未过期的邀请码，供店长回看已发出去的码 */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER})
    @GetMapping("/staff/invite/list")
    public AjaxResult staffInviteList()
    {
        LoginMember m = requireMerchantLogin(false);
        MerchantStaffInvite q = new MerchantStaffInvite();
        q.setMerchantId(m.getMerchantId());
        List<MerchantStaffInvite> list = inviteService.selectList(q);
        List<Map<String, Object>> out = new ArrayList<>();
        if (list != null)
        {
            for (MerchantStaffInvite inv : list)
            {
                if (inv.getStoreId() == null || !m.hasStore(inv.getStoreId())) continue;
                Map<String, Object> o = new HashMap<>();
                o.put("inviteId", inv.getInviteId());
                o.put("inviteCode", inv.getInviteCode());
                o.put("role", inv.getRole());
                o.put("storeId", inv.getStoreId());
                o.put("status", inv.getStatus());
                o.put("expireAt", inv.getExpireAt());
                o.put("wxacodeUrl", inv.getWxacodeUrl());
                o.put("createTime", inv.getCreateTime());
                out.add(o);
            }
        }
        return AjaxResult.success(out);
    }

    /**
     * 重置店员登录密码，新密码明文只在本次响应返回一次。
     *
     * <p>这是店员丢失密码后唯一的补救途径：扫码入职时自动生成的密码
     * 从未告知过任何人，店员一旦换微信（openid 变了）就再也进不来。</p>
     */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER})
    @PostMapping("/staff/resetPwd")
    public AjaxResult staffResetPwd(@RequestBody Map<String, Object> body)
    {
        LoginMember m = requireMerchantLogin(false);
        Long userId = asLong(body == null ? null : body.get("userId"));
        if (userId == null) return AjaxResult.error("缺少 userId");
        MerchantStaff link = staffService.selectByUserId(userId);
        if (link == null) return AjaxResult.error("该账号不是商家员工");
        if (!isStaffVisible(m, link)) return AjaxResult.error("无权重置该员工密码");
        // 给自己换密码要放行：canManageRole 是「严格大于」，自己对自己必然不满足，
        // 于是老板想给自己换个记得住的密码会被自己的系统拒掉，只能去求平台管理员。
        // 已经用当前 token 证明了身份，重置自己的密码没有提权风险。
        boolean self = userId.equals(m.getStaffUserId());
        if (!self && !canManageRole(m, link.getRole())) return AjaxResult.error("无权重置该角色的密码");

        SysUser user = userService.selectUserByUserId(userId);
        if (user == null) return AjaxResult.error("员工账号不存在");
        String rawPwd = randomPassword();
        SysUser upd = new SysUser();
        upd.setUserId(userId);
        upd.setPassword(SecurityUtils.encryptPassword(rawPwd));
        upd.setUpdateBy(currentStaffTag(m));
        if (userService.resetPwd(upd) <= 0) return AjaxResult.error("重置失败");
        AjaxResult r = AjaxResult.success("已重置密码");
        r.put("userName", user.getUserName());
        r.put("newPassword", rawPwd);
        return r;
    }

    /**
     * 店员离职（status=1），不删账号也不删关联。
     *
     * <p>为什么用离职态而不是物理删除：核销记录里存的是 store:{userId}，
     * 删了账号历史核销就查不到经手人了。离职后 wxLogin / 密码登录都会被
     * 「该账号未关联商家」挡住（登录只认 status=0）。</p>
     */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER})
    @PostMapping("/staff/dismiss")
    public AjaxResult staffDismiss(@RequestBody Map<String, Object> body)
    {
        LoginMember m = requireMerchantLogin(false);
        Long id = asLong(body == null ? null : body.get("id"));
        if (id == null) return AjaxResult.error("缺少 id");
        MerchantStaff db = staffService.selectById(id);
        if (db == null) return AjaxResult.error("员工关联不存在");
        if (!isStaffVisible(m, db)) return AjaxResult.error("无权操作该员工");
        // 自我保护必须排在 canManageRole 之前：同级比较是「严格大于」，
        // 自己对自己一定不满足，会先撞上「无权操作该角色的员工」——
        // 拦是拦住了，但老板会以为是权限配错了而去找平台，实际原因是不能办自己。
        if (db.getUserId() != null && db.getUserId().equals(m.getStaffUserId()))
        {
            return AjaxResult.error("不能对自己办理离职");
        }
        if (!canManageRole(m, db.getRole())) return AjaxResult.error("无权操作该角色的员工");
        if ("1".equals(db.getStatus())) return AjaxResult.error("该员工已离职");
        db.setStatus("1");
        db.setUpdateBy(currentStaffTag(m));
        return staffService.update(db) > 0 ? AjaxResult.success("已办理离职") : AjaxResult.error("操作失败");
    }

    /** 离职员工复职（status=1 → 0） */
    @LoginRequired
    @RequireRole(value = {BizRole.OWNER, BizRole.MANAGER})
    @PostMapping("/staff/restore")
    public AjaxResult staffRestore(@RequestBody Map<String, Object> body)
    {
        LoginMember m = requireMerchantLogin(false);
        Long id = asLong(body == null ? null : body.get("id"));
        if (id == null) return AjaxResult.error("缺少 id");
        MerchantStaff db = staffService.selectById(id);
        if (db == null) return AjaxResult.error("员工关联不存在");
        if (!isStaffVisible(m, db)) return AjaxResult.error("无权操作该员工");
        if (!canManageRole(m, db.getRole())) return AjaxResult.error("无权操作该角色的员工");
        if (!"1".equals(db.getStatus())) return AjaxResult.error("该员工不在离职状态");
        db.setStatus("0");
        db.setUpdateBy(currentStaffTag(m));
        return staffService.update(db) > 0 ? AjaxResult.success("已复职") : AjaxResult.error("操作失败");
    }

    // ===== 店员管理内部工具 =====

    /**
     * 该员工是否在当前登录者的可管理范围内。
     *
     * <p>两道：同商户 + 门店在授权集合内。store_id=0 表示「全商户所有门店」，
     * 只有同样管全商户的人（老板）能看到，店长不该看到跨门店的全局员工。</p>
     */
    private boolean isStaffVisible(LoginMember m, MerchantStaff ms)
    {
        if (ms == null || m == null) return false;
        if (ms.getMerchantId() == null || !ms.getMerchantId().equals(m.getMerchantId())) return false;
        Long sid = ms.getStoreId();
        if (sid == null) return false;
        if (sid == 0L)
        {
            // 全商户员工（老板）：只有自己也是全商户视角时可见
            return m.getStoreIds() == null || m.getStoreIds().isEmpty() || isWholeMerchantScope(m);
        }
        return m.hasStore(sid);
    }

    /** 登录者是否「全商户视角」（biz_merchant_staff.store_id=0 的老板） */
    private boolean isWholeMerchantScope(LoginMember m)
    {
        MerchantStaff link = m.getStaffUserId() == null ? null : staffService.selectByUserId(m.getStaffUserId());
        return link != null && link.getStoreId() != null && link.getStoreId() == 0L;
    }

    /**
     * 当前登录者能否管理目标角色。
     *
     * <p>必须严格高于：店长(rank 2)只能管店员(rank 1)，不能审/改/重置另一个店长，
     * 更不能碰老板。否则任一店长可以把自己审成老板、或重置老板密码接管整个商户。</p>
     */
    private boolean canManageRole(LoginMember m, String targetRole)
    {
        BizRole mine = m.getStaffRole();
        if (mine == null) return false;
        return mine.rank() > BizRole.fromStaffRole(targetRole).rank();
    }

    /** 员工列表对外视图：手机号脱敏，不吐 openid 原文 */
    private Map<String, Object> toStaffView(MerchantStaff ms)
    {
        Map<String, Object> o = new HashMap<>();
        o.put("id", ms.getId());
        o.put("userId", ms.getUserId());
        o.put("userName", ms.getUserName());
        o.put("realName", ms.getRealName());
        o.put("nickName", ms.getNickName());
        o.put("role", ms.getRole());
        o.put("storeId", ms.getStoreId());
        o.put("storeName", ms.getStoreName());
        o.put("status", ms.getStatus());
        o.put("hiredAt", ms.getHiredAt());
        o.put("createTime", ms.getCreateTime());
        o.put("phone", ms.getPhone() == null ? null : DesensitizedType.PHONE.desensitizer().apply(ms.getPhone()));
        return o;
    }

    /** 操作留痕标识：mstaff-{userId}，与预约审核的 confirmUser 口径一致 */
    private String currentStaffTag(LoginMember m)
    {
        return m.getStaffUserId() == null ? "merchant-staff" : ("mstaff-" + m.getStaffUserId());
    }

    private static Long asLong(Object v)
    {
        if (v == null) return null;
        String s = String.valueOf(v).trim();
        if (s.isEmpty()) return null;
        try { return Long.valueOf(s); } catch (NumberFormatException e) { return null; }
    }

    private static String trimToNull(Object v)
    {
        if (v == null) return null;
        String s = String.valueOf(v).trim();
        return s.isEmpty() ? null : s;
    }

    /** 重置密码用：8 位大小写+数字，避开易混字符（0/O/1/l/I） */
    private String randomPassword()
    {
        String pool = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789";
        java.security.SecureRandom rnd = new java.security.SecureRandom();
        StringBuilder sb = new StringBuilder(8);
        for (int i = 0; i < 8; i++) sb.append(pool.charAt(rnd.nextInt(pool.length())));
        return sb.toString();
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
