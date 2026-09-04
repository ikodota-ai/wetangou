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
import com.ruoyi.biz.api.util.StaffLoginMemberBuilder;
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

    @Autowired
    private com.ruoyi.biz.service.IStoreService storeService;

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
        // 以 body.appid 解析结果为准同步租户上下文。
        // MemberAuthInterceptor 只看 X-App-Id header，调用方若只在 body 里带 appid
        // （header 缺失），上下文会 fallback 到默认商户 1，于是
        // selectMemberByOpenid 查的是商户 1、insert 又被 TenantEntityHelper 写成商户 1，
        // 对已在商户 1 存在的 openid 直接撞 uk_merchant_openid 报 500。
        if (merchantId != null)
        {
            com.ruoyi.common.utils.TenantContextHolder.set(
                    com.ruoyi.common.core.domain.model.TenantContext.ofMerchant(merchantId));
        }

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
                // 必须绕开租户 SQL 过滤：MemberAuthInterceptor 对匿名 /api/** 会按 X-App-Id 设租户上下文，
                // 未带/未匹配 appid 时兜底为默认商户 1，于是 TenantSqlInterceptor 会给这条查询追加
                // "and ms.merchant_id = 1"。按 user_id 查自己的员工关联属于身份解析，商户归属由账号本身决定，
                // 被 appid 上下文限制会导致「商户 201 的老板用密码登录报该账号未关联商家」。
                List<MerchantStaff> allLinks = com.ruoyi.common.utils.TenantContextHolder.ignoreTenant(
                        () -> staffService.selectList(new MerchantStaff() {{ setUserId(u.getUserId()); }}));
                // 只认在职关联（status=0 或历史空值）；待审核(3)/离职(1) 按普通会员处理，
                // 与上面「2) openid 命中但员工 status≠0 → 按普通会员处理」的设计一致。
                List<MerchantStaff> links = new java.util.ArrayList<>();
                if (allLinks != null) {
                    for (MerchantStaff l : allLinks) {
                        if (l.getStatus() == null || "0".equals(l.getStatus())) links.add(l);
                    }
                }
                // 同 /api/merchant/staff/login：员工身份必须收敛到当前小程序所属商户，
                // 否则 A 商户的员工在 B 商户小程序里做会员授权，会被直接识别成员工并签发
                // 商家端 token（连账号密码都不用输）。merchantId 由 resolveMerchantId(appid)
                // 解出，appid 缺失时为默认商户，此处一律按解析结果过滤。
                if (merchantId != null) {
                    List<MerchantStaff> sameTenant = new java.util.ArrayList<>();
                    for (MerchantStaff l : links) {
                        if (merchantId.equals(l.getMerchantId())) sameTenant.add(l);
                    }
                    links = sameTenant;
                }
                if (!links.isEmpty()) {
                    linkedStaff = u;
                    LoginMember staffLm = buildStaffLoginMember(u, links);
                    staffLm.setAppid(appid);
                    String staffToken = memberTokenService.createToken(staffLm);
                    staffLm.setToken(staffToken);
                    AjaxResult ajax = AjaxResult.success("员工登录成功");
                    ajax.put("token", staffToken);
                    ajax.put("userType", staffLm.getUserType());
                    ajax.put("loginType", "staff");
                    ajax.put("isStaff", true);
                    // 前端 pages/login/login.js 读 data.staffUserId 建 staffUser 会话，
                    // 此前后端从未返该字段，一路回退到 data.memberId（会员 ID 语义），
                    // 商家端把它当 sys_user.user_id 用就会张冠李戴。
                    ajax.put("staffUserId", staffLm.getStaffUserId());
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
        // 会员 token 同样锚定 appid：会员数据本就按 merchantId 隔离，
        // 但不锚定的话 token 换个小程序仍可用，租户边界只剩查询层一道
        loginMember.setAppid(appid);
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
     *
     * <p>不能直接 return AjaxResult.success(member)：Member.phone 上有
     * {@code @Sensitive(PHONE)}，而 SensitiveJsonSerializer.desensitization() 在
     * 拿不到 LoginUser 时一律返 true（匿名即脱敏），小程序 /api/** 全是 @Anonymous，
     * 所以实体一路过 Jackson 就变成 138****7777。会员看自己的手机号必须是明文，
     * 否则下单页/买单页把它 Object.assign 进 globalData.user 后，
     * 带星号的号码会覆盖登录接口给的明文并被提交到订单。</p>
     */
    @LoginRequired
    @PostMapping("/info")
    public AjaxResult info()
    {
        LoginMember loginMember = MemberContextHolder.get();
        Member m = memberService.selectMemberByMemberId(loginMember.getMemberId());
        if (m == null)
        {
            return AjaxResult.success();
        }
        return AjaxResult.success(toMemberVo(m));
    }

    /**
     * 会员实体 → 明文 VO（与 /api/member/profile 字段保持一致，前端两处可互换消费）
     */
    private java.util.Map<String, Object> toMemberVo(Member m)
    {
        java.util.Map<String, Object> vo = new java.util.LinkedHashMap<>();
        vo.put("memberId", m.getMemberId());
        vo.put("merchantId", m.getMerchantId());
        vo.put("openid", m.getOpenid());
        vo.put("unionid", m.getUnionid());
        vo.put("nickname", m.getNickname());
        vo.put("nickName", m.getNickname());
        vo.put("avatar", m.getAvatar());
        vo.put("avatarUrl", m.getAvatar());
        vo.put("phone", m.getPhone());
        vo.put("gender", m.getGender());
        vo.put("birthday", m.getBirthday());
        vo.put("status", m.getStatus());
        vo.put("lastLoginTime", m.getLastLoginTime());
        vo.put("inviteBy", m.getInviteBy());
        vo.put("inviteTime", m.getInviteTime());
        vo.put("createTime", m.getCreateTime());
        return vo;
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
     * 构建商家端登录态（与 ApiMerchantStaffController 共用同一实现）。
     *
     * <p>此前这里是一份从 ApiMerchantStaffController 复制来的副本，复制时把
     * staffRoleRank() 换成了 BizRole.ordinal()。枚举声明顺序是
     * PLATFORM(0)/AGENT(1)/OWNER(2)/MANAGER(3)/STAFF(4)，按 ordinal 取"最大"
     * 等于认定 STAFF 权限最高 —— 老板只要兼任任一门店店员，走会员授权登录就会被
     * 降权成 STAFF，商品/财务全部点不动，而账号密码链路却是正常的 OWNER。
     * 同一个人两条链路两种身份，故收口为唯一实现。</p>
     */
    private LoginMember buildStaffLoginMember(SysUser user, List<MerchantStaff> links)
    {
        return StaffLoginMemberBuilder.build(user, links, "merchant", null,
                this::storeIdsOfMerchant, this::merchantIdOfStore);
    }

    /**
     * 查门店当前所属商户（剔除「关联声明商户 A、门店已转给商户 B」的脏关联，
     * 详见 StaffLoginMemberBuilder 里的说明）。
     */
    private Long merchantIdOfStore(Long storeId)
    {
        if (storeId == null) return null;
        com.ruoyi.biz.domain.Store st = com.ruoyi.common.utils.TenantContextHolder.ignoreTenant(
                () -> storeService.selectStoreByStoreId(storeId));
        return st == null ? null : st.getMerchantId();
    }

    /** 查商户下全部门店 ID（把 biz_merchant_staff.store_id=0 展开成真实门店范围） */
    private List<Long> storeIdsOfMerchant(Long merchantId)
    {
        List<Long> out = new java.util.ArrayList<>();
        if (merchantId == null) return out;
        com.ruoyi.biz.domain.Store q = new com.ruoyi.biz.domain.Store();
        q.setMerchantId(merchantId);
        // 同上：展开 store_id=0 时按 merchantId 查门店，不能被 appid 兜底的租户上下文限制，
        // 否则商户 201 的老板会查到商户 1 的门店（或查不到任何门店）。
        List<com.ruoyi.biz.domain.Store> list = com.ruoyi.common.utils.TenantContextHolder.ignoreTenant(
                () -> storeService.selectStoreList(q));
        if (list != null)
        {
            for (com.ruoyi.biz.domain.Store st : list)
            {
                if (st.getStoreId() != null) out.add(st.getStoreId());
            }
        }
        return out;
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
