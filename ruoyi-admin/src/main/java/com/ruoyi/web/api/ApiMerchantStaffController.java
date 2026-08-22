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

    @Autowired private ISysUserService userService;
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
        List<MerchantStaff> allLinks = staffService.selectList(new MerchantStaff() {{ setUserId(user.getUserId()); }});
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

        List<MerchantStaff> allLinks = staffService.selectList(new MerchantStaff() {{ setUserId(user.getUserId()); }});
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
        List<MerchantStaff> links = staffService.selectList(new MerchantStaff() {{ setUserId(boundUser.getUserId()); }});
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
            links = staffService.selectList(new MerchantStaff() {{ setUserId(boundUser.getUserId()); }});
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
        if (exist != null && !exist.getUserId().equals(lm.getMemberId())) {
            throw new ServiceException("该微信已绑定其他账号");
        }

        SysUser user = userService.selectUserByUserId(lm.getMemberId());
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
        upd.setUserId(lm.getMemberId());
        upd.setRealName(realName);
        upd.setPhone(phone);
        upd.setUpdateBy(String.valueOf(lm.getMemberId()));
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

    private LoginMember buildLoginMember(SysUser user, List<MerchantStaff> links, String userType)
    {
        List<Long> storeIds = new ArrayList<>();
        Long merchantId = null;
        java.util.Set<BizRole> roles = new java.util.HashSet<>();
        BizRole maxStaffRole = null;
        for (MerchantStaff l : links) {
            if (l.getStoreId() != null && !storeIds.contains(l.getStoreId())) storeIds.add(l.getStoreId());
            if (merchantId == null && l.getMerchantId() != null) merchantId = l.getMerchantId();
            BizRole r = BizRole.fromStaffRole(l.getRole());
            roles.add(r);
            if (maxStaffRole == null || staffRoleRank(r) > staffRoleRank(maxStaffRole)) {
                maxStaffRole = r;
            }
        }
        // 兼容 userType 参数（旧 staff 链路），确保非空
        String resolvedUserType = userType;
        if (maxStaffRole != null) {
            switch (maxStaffRole) {
                case OWNER:   resolvedUserType = "owner";   break;
                case MANAGER: resolvedUserType = "manager"; break;
                case STAFF:   resolvedUserType = "staff";   break;
                default: break;
            }
        }
        // 代理商/城市合伙人 叠加身份（user_type=01）
        Long agentId = null;
        if ("01".equals(user.getUserType())) {
            roles.add(BizRole.AGENT);
            resolvedUserType = "agent";
            try {
                Agent agent = agentService.selectAgentByUserId(user.getUserId());
                if (agent != null) agentId = agent.getAgentId();
            } catch (Exception ignore) { }
        }
        // 平台账号 也能登录小程序（user_type=00，外出查跨店数据）。
        // 纵深防御：仅当该账号「没有任何商家员工关联」时才认平台身份。
        // 历史上 acceptInvite 曾把扫码入职账号误建成 user_type=00，
        // 若此处不加 links 判空，这些店员登录后会直接拿到 PLATFORM 角色（可读全平台数据）。
        if ("00".equals(user.getUserType()) && (links == null || links.isEmpty())) {
            roles.add(BizRole.PLATFORM);
            resolvedUserType = "platform";
        }
        Long currentStoreId = storeIds.isEmpty() ? null : storeIds.get(0);
        LoginMember lm = new LoginMember();
        lm.setUserType(resolvedUserType);
        lm.setRoles(roles);
        lm.setStaffRole(maxStaffRole);
        lm.setStoreId(currentStoreId);
        lm.setStoreIds(storeIds);
        lm.setMerchantId(merchantId);
        lm.setAgentId(agentId);
        lm.setMemberId(user.getUserId());
        lm.setOpenid(user.getOpenid() == null ? "staff:" + user.getUserId() : user.getOpenid());
        return lm;
    }

    /** OWNER=3, MANAGER=2, STAFF=1, 其他=0 */
    private static int staffRoleRank(BizRole r) {
        if (r == null) return 0;
        switch (r) {
            case OWNER:   return 3;
            case MANAGER: return 2;
            case STAFF:   return 1;
            default:      return 0;
        }
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
        String ut = m.getUserType();
        if (!("merchant".equals(ut) || "owner".equals(ut) || "manager".equals(ut) || "staff".equals(ut))) throw new ServiceException("非商家员工身份");
        if (m.getStoreId() == null) throw new ServiceException("未绑定门店");
        return m;
    }

    @LoginRequired
    @RequireRole(value = BizRole.STAFF, includeHigher = false)
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
    @RequireRole(value = BizRole.STAFF, includeHigher = false)
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
    @RequireRole(value = BizRole.STAFF, includeHigher = false)
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
    @RequireRole(value = BizRole.STAFF, includeHigher = false)
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
