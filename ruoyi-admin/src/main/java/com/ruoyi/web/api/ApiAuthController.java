package com.ruoyi.web.api;

import java.util.Date;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.alibaba.fastjson2.JSONObject;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.constant.TenantConstants;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.biz.api.annotation.LoginRequired;
import com.ruoyi.biz.api.domain.LoginMember;
import com.ruoyi.biz.api.service.WxMaService;
import com.ruoyi.biz.api.util.MemberContextHolder;
import com.ruoyi.biz.api.util.MemberTokenService;
import com.ruoyi.biz.domain.Member;
import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.biz.service.IMemberService;
import com.ruoyi.biz.service.IMerchantStaffService;
import com.ruoyi.biz.service.ITenantService;
import com.ruoyi.biz.domain.MerchantStaff;
import com.ruoyi.system.service.ISysUserService;
import com.ruoyi.biz.api.role.BizRole;
import java.util.ArrayList;
import java.util.stream.Collectors;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.exception.ServiceException;

/**
 * 小程序-认证登录
 *
 * @author dytuangou
 */
@Anonymous
@RestController
@RequestMapping("/api/auth")
public class ApiAuthController
{
    /** 存量单商户小程序未传appid时使用的默认商户ID */

    @Autowired
    private WxMaService wxMaService;

    @Autowired
    private IMemberService memberService;

    @Autowired
    private MemberTokenService memberTokenService;

    @Autowired
    private ITenantService tenantService;

    @Autowired
    private IMerchantStaffService staffService;

    @Autowired
    private ISysUserService userService;

    /**
     * 微信登录：code换openid，注册或更新会员，返回会员token
     */
    @PostMapping("/login")
    public AjaxResult login(@RequestBody JSONObject body)
    {
        String code = body.getString("code");
        String nickName = body.getString("nickName");
        String avatarUrl = body.getString("avatarUrl");
        String appid = body.getString("appid");

        // 多商户：按小程序appid确定所属商户，同一openid在不同商户下互相隔离
        Long merchantId = resolveMerchantId(appid);

        JSONObject session = wxMaService.code2Session(code, merchantId);
        String openid = session.getString("openid");
        String sessionKey = session.getString("session_key");
        String unionid = session.getString("unionid");

        Long inviteBy = body.getLong("inviteBy");
        if (inviteBy != null && inviteBy.equals(memberId0(merchantId, openid)))
        {
            inviteBy = null;
        }

        // ===== 设计要点（V2.6.2 合并登录）=====
        // 1) openid 命中 sys_user + biz_merchant_staff → 直接走员工 token，登录到商家端
        // 2) openid 命中但员工 status≠0 → 按普通会员处理
        // 3) openid 未命中员工 → 走普通会员登录
        // 4) 返 hasStaffAccount + needStaffLogin 让前端按需显示「账号密码登录」入口
        SysUser linkedStaff = null;
        try {
            SysUser u = userService.selectUserByOpenId(openid);
            if (u != null && "0".equals(u.getStatus())) {
                List<MerchantStaff> links = staffService.selectList(new MerchantStaff() {{ setUserId(u.getUserId()); }});
                if (links != null && !links.isEmpty()) {
                    linkedStaff = u;
                    LoginMember staffLm = buildStaffLoginMember(u, links);
                    String staffToken = memberTokenService.createToken(staffLm);
                    staffLm.setToken(staffToken);
                    AjaxResult ajax = AjaxResult.success("员工登录成功");
                    ajax.put("token", staffToken);
                    ajax.put("userType", staffLm.getUserType());
                    ajax.put("loginType", "staff");
                    ajax.put("isStaff", true);
                    ajax.put("isOwner", staffLm.isOwner());
                    ajax.put("isManagerOrAbove", staffLm.isManagerOrAbove());
                    ajax.put("isAgent", staffLm.isAgent());
                    ajax.put("staffRole", staffLm.getStaffRole() == null ? null : staffLm.getStaffRole().name());
                    ajax.put("roles", staffLm.getRoles() == null ? java.util.Collections.emptyList() :
                            staffLm.getRoles().stream().map(Enum::name).collect(Collectors.toList()));
                    ajax.put("storeId", staffLm.getStoreId());
                    ajax.put("storeIds", staffLm.getStoreIds());
                    ajax.put("merchantId", staffLm.getMerchantId());
                    MerchantStaff me = links.get(0);
                    ajax.put("realName", me.getRealName());
                    ajax.put("nickName", me.getRealName());
                    ajax.put("avatarUrl", u.getAvatar());
                    ajax.put("phone", "");
                    return ajax;
                }
            }
        } catch (Exception ignore) { }

        // ===== 兜底：普通会员登录 =====
        Member member = memberService.selectMemberByOpenid(merchantId, openid);
        if (member == null)
        {
            member = new Member();
            member.setMerchantId(merchantId);
            member.setOpenid(openid);
            member.setUnionid(unionid);
            member.setNickname(nickName);
            member.setAvatar(avatarUrl);
            member.setStatus("0");
            member.setCreateTime(new Date());
            member.setLastLoginTime(new Date());
            if (inviteBy != null && isValidInviter(merchantId, inviteBy))
            {
                member.setInviteBy(inviteBy);
                member.setInviteTime(new Date());
            }
            memberService.insertMember(member);
        }
        else
        {
            member.setLastLoginTime(new Date());
            if (StringUtils.isNotEmpty(nickName)) member.setNickname(nickName);
            if (StringUtils.isNotEmpty(avatarUrl)) member.setAvatar(avatarUrl);
            if (member.getInviteBy() == null && inviteBy != null
                    && !inviteBy.equals(member.getMemberId())
                    && isValidInviter(merchantId, inviteBy))
            {
                member.setInviteBy(inviteBy);
                member.setInviteTime(new Date());
            }
            memberService.updateMember(member);
        }

        LoginMember loginMember = new LoginMember(member);
        String token = memberTokenService.createToken(loginMember);

        AjaxResult ajax = AjaxResult.success("登录成功");
        ajax.put("token", token);
        ajax.put("memberId", member.getMemberId());
        ajax.put("loginType", "member");
        ajax.put("nickName", member.getNickname());
        ajax.put("avatarUrl", member.getAvatar());
        ajax.put("phone", member.getPhone());
        ajax.put("isStaff", false);
        // 该 openid 是否绑定了商家账号（不论是否启用）→ 决定是否显示「账号密码登录」入口
        ajax.put("hasStaffAccount", linkedStaff != null || hasStaffAccountForOpenid(openid));
        return ajax;

    }

    /**
     * 校验邀请人合法性：同商户 + 状态正常
     */
    private boolean isValidInviter(Long merchantId, Long inviteBy)
    {
        Member inviter = memberService.selectMemberByMemberId(inviteBy);
        return inviter != null && "0".equals(inviter.getStatus())
                && merchantId.equals(inviter.getMerchantId());
    }

    /**
     * 自邀检查前置查询：按 openid 查当前会员是否已存在。
     * <p>已存在则返回 memberId，登录主流程据此在 insert 前清掉自邀；新会员返回 null，
     * 此时 inviteBy 与未生成 memberId 不可能相等，line 71 防御降级为「仅保留外部传值」。</p>
     * <p>多商户隔离：必须传 merchantId，同一 openid 在不同商户下属于不同会员。</p>
     */
    private Long memberId0(Long merchantId, String openid)
    {
        if (StringUtils.isEmpty(openid))
        {
            return null;
        }
        Member existing = memberService.selectMemberByOpenid(merchantId, openid);
        return existing == null ? null : existing.getMemberId();
    }

    /**
     * 按appid解析商户ID
     *
     * <p>未传appid时兼容单商户存量小程序：回退到默认商户（ID=1）。
     * 传了appid但查不到对应商户则直接拒绝，避免数据落到错误商户。</p>
     */
    private Long resolveMerchantId(String appid)
    {
        if (StringUtils.isEmpty(appid))
        {
            return TenantConstants.DEFAULT_MERCHANT_ID;
        }
        Merchant merchant = tenantService.getMerchantByAppid(appid);
        if (merchant == null)
        {
            throw new ServiceException("小程序未接入或已停用：" + appid);
        }
        if (!"0".equals(merchant.getStatus()))
        {
            throw new ServiceException("商户已停用，请联系服务商");
        }
        return merchant.getMerchantId();
    }

    /**
     * 获取当前登录会员信息
     */
    @LoginRequired
    @PostMapping("/info")
    public AjaxResult info()
    {
        LoginMember loginMember = MemberContextHolder.get();
        Member member = memberService.selectMemberByMemberId(loginMember.getMemberId());
        return AjaxResult.success(member);
    }

    /**
     * 退出登录
     */
    @LoginRequired
    @PostMapping("/logout")
    public AjaxResult logout()
    {
        LoginMember loginMember = MemberContextHolder.get();
        if (loginMember != null && StringUtils.isNotEmpty(loginMember.getToken()))
        {
            memberTokenService.delLoginMember(loginMember.getToken());
        }
        return AjaxResult.success("退出成功");
    }

    /**
     * 已登录用户回填邀请人（用于扫码进入后未在登录时携带 inviteBy 场景）
     *
     * <p>仅在当前会员 invite_by 为空时回写一次，防止覆盖既有邀请关系。
     * 同一商户内的会员可以互相邀请，跨商户邀请自动拒绝。</p>
     */
    @LoginRequired
    @PostMapping("/bind-invite")
    public AjaxResult bindInvite(@RequestBody JSONObject body)
    {
        Long inviteBy = body.getLong("inviteBy");
        if (inviteBy == null)
        {
            return AjaxResult.error("缺少 inviteBy");
        }
        if (inviteBy.equals(MemberContextHolder.getMemberId()))
        {
            return AjaxResult.error("不能邀请自己");
        }
        Member me = memberService.selectMemberByMemberId(MemberContextHolder.getMemberId());
        if (me == null)
        {
            return AjaxResult.error("会员不存在");
        }
        if (me.getInviteBy() != null)
        {
            return AjaxResult.success("已有邀请人，无需重复绑定");
        }
        if (!isValidInviter(me.getMerchantId(), inviteBy))
        {
            return AjaxResult.error("邀请人不存在或跨商户");
        }
        Member update = new Member();
        update.setMemberId(me.getMemberId());
        update.setInviteBy(inviteBy);
        update.setInviteTime(new Date());
        memberService.updateMember(update);
        return AjaxResult.success("绑定成功");
    }

    /**
     * 复制自 ApiMerchantStaffController.buildLoginMember 的核心逻辑
     * 构造 staff 身份的 LoginMember（带 roles/userType/staffRole/storeId 等）
     */
    private LoginMember buildStaffLoginMember(SysUser user, List<MerchantStaff> links)
    {
        java.util.List<Long> storeIds = new ArrayList<>();
        Long merchantId2 = null;
        java.util.Set<BizRole> roles = new java.util.HashSet<>();
        BizRole maxStaffRole = null;
        for (MerchantStaff l : links) {
            if (l.getStoreId() != null && !storeIds.contains(l.getStoreId())) storeIds.add(l.getStoreId());
            if (merchantId2 == null && l.getMerchantId() != null) merchantId2 = l.getMerchantId();
            BizRole r = BizRole.fromStaffRole(l.getRole());
            roles.add(r);
            if (maxStaffRole == null || (r != null && r.ordinal() > (maxStaffRole == null ? -1 : maxStaffRole.ordinal()))) {
                maxStaffRole = r;
            }
        }
        String resolvedUserType = "merchant";
        if (maxStaffRole != null) {
            switch (maxStaffRole) {
                case OWNER:   resolvedUserType = "owner";   break;
                case MANAGER: resolvedUserType = "manager"; break;
                case STAFF:   resolvedUserType = "staff";   break;
                default: break;
            }
        }
        if ("01".equals(user.getUserType())) {
            roles.add(BizRole.AGENT);
            resolvedUserType = "agent";
        }
        if ("00".equals(user.getUserType())) {
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
        lm.setMerchantId(merchantId2);
        lm.setMemberId(user.getUserId());
        lm.setOpenid(user.getOpenid() == null ? "staff:" + user.getUserId() : user.getOpenid());
        return lm;
    }

    /**
     * 检测该 openid 是否绑定了任何商家账号（含 status=1 停用）
     *  - 用于前端决定是否展示「账号密码登录」入口
     */
    private boolean hasStaffAccountForOpenid(String openid)
    {
        if (StringUtils.isEmpty(openid)) return false;
        try {
            SysUser u = userService.selectUserByOpenId(openid);
            return u != null;
        } catch (Exception e) {
            return false;
        }
    }
}
