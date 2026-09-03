package com.ruoyi.biz.api.domain;

import java.io.Serializable;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import com.ruoyi.biz.api.role.BizRole;
import com.ruoyi.biz.domain.Member;

/**
 * 小程序登录会员身份信息
 *
 * @author dytuangou
 */
public class LoginMember implements Serializable
{
    private static final long serialVersionUID = 1L;

    /** 会员唯一标识（token缓存key） */
    private String token;

    /** 会员ID */
    private Long memberId;

    /** 所属商户ID（多商户隔离，按小程序appid确定） */
    private Long merchantId;

    /**
     * 签发这份登录态的小程序 appid。
     *
     * <p>多商户下每个商户一个小程序，token 必须锚定到签发它的 appid，否则
     * A 商户小程序里拿到的 token 换个 B 商户的小程序照样能用（X-App-Id 只影响
     * 匿名请求的租户上下文，带 token 的请求根本不看它）。
     * 由 {@code MemberAuthInterceptor} 在每次请求时与 X-App-Id 比对。</p>
     */
    private String appid;

    /** 微信openid */
    private String openid;

    /** 登录时间戳 */
    private Long loginTime;

    /** 过期时间戳 */
    private Long expireTime;

    /** 会员信息 */
    private Member member;

    /**
     * 用户身份：member=会员（默认）、store=门店员工、agent=代理商员工
     *
     * <p>门店端工作台登录后写 store，并在 {@link #storeId} 写入关联门店。</p>
     */
    private String userType;

/**
     * 业务角色集合（小程序端 4 角色 + PC 端身份可叠加）
     * 一个账号可以同时是 OWNER + MANAGER（老板兼店长）
     * 也会包含 AGENT (代理商/城市合伙人)
     */
    private Set<BizRole> roles = new HashSet<>();

    /**
     * 商家员工最高 role（OWNER > MANAGER > STAFF），用于快捷判断
     */
    private BizRole staffRole;

        /** 代理商ID (userType=1 时) */
    private Long agentId;

    /**
     * 门店员工身份时可管理的门店 ID 集合（多门店权限）
     */
    private List<Long> storeIds;

    /**
     * 门店员工身份时当前激活的门店 ID（多门店时切换用，默认取集合第一个）
     */
    private Long storeId;

    /**
     * 商家员工身份的 sys_user.user_id。
     *
     * <p>必须与 {@link #memberId} 严格分开：sys_user 与 biz_member 是两条独立自增序列，
     * 本地实测 sys_user 已到 999903、biz_member 已到 1001244，区间完全重叠。
     * 历史上商家端登录把 user_id 直接塞进 memberId，导致店员 token 调 /api/auth/info
     * 会按 memberId 命中同号的**别人的会员记录**（实测店员读到了会员 c24 的 openid）。
     * 商家端一律读本字段，会员接口一律读 memberId。</p>
     */
    private Long staffUserId;

    /**
     * 是否拥有「全商户所有门店」范围（biz_merchant_staff.store_id=0，老板/商户级职务）。
     *
     * <p>storeIds 已在登录时展开为该商户的真实门店列表，本标记用于：
     * 1) 商家端展示「全部门店」汇总选项；2) 新增门店后无需补员工关联即自动纳入范围。</p>
     */
    private boolean allStores;

    public LoginMember()
    {
    }

    public LoginMember(Member member)
    {
        this.member = member;
        this.memberId = member.getMemberId();
        this.openid = member.getOpenid();
        this.merchantId = member.getMerchantId();
        this.userType = member.getUserType();
        this.agentId = member.getAgentId();
    }

    public Long getMerchantId()
    {
        return merchantId;
    }

    public void setMerchantId(Long merchantId)
    {
        this.merchantId = merchantId;
    }

    public String getAppid()
    {
        return appid;
    }

    public void setAppid(String appid)
    {
        this.appid = appid;
    }

    public String getUserType()
    {
        return userType;
    }

    public void setUserType(String userType)
    {
        this.userType = userType;
    }
    public Long getAgentId()
    {
        return agentId;
    }

    public void setAgentId(Long agentId)
    {
        this.agentId = agentId;
    }

    public Long getStoreId()
    {
        return storeId;
    }

    public void setStoreId(Long storeId)
    {
        this.storeId = storeId;
    }

    public List<Long> getStoreIds()
    {
        return storeIds;
    }

    public void setStoreIds(List<Long> storeIds)
    {
        this.storeIds = storeIds;
    }

    /**
     * 判断某个门店是否在员工权限范围内
     */
    public boolean hasStore(Long checkStoreId)
    {
        if (checkStoreId == null) return false;
        if (storeIds == null || storeIds.isEmpty()) return false;
        return storeIds.contains(checkStoreId);
    }

    /**
     * 是否「员工会话」（门店端旧链路 + 商家端新链路统称）。
     *
     * <p>历史代码到处写 {@code "store".equals(getUserType())} 判断员工身份，
     * 而商家端登录链路发的是 owner / manager / staff —— 于是核销、确认买单、
     * 审核预约这些端点对商家端三种角色全部 403。这里统一收口，避免再各处漏改。</p>
     */
    public boolean isStaffSession()
    {
        if (userType == null) return false;
        return "store".equals(userType)
                || "owner".equals(userType)
                || "manager".equals(userType)
                || "staff".equals(userType);
    }

    public String getToken()
    {
        return token;
    }

    public void setToken(String token)
    {
        this.token = token;
    }


    public boolean isAllStores()
    {
        return allStores;
    }

    public void setAllStores(boolean allStores)
    {
        this.allStores = allStores;
    }

    public Long getStaffUserId()
    {
        return staffUserId;
    }

    public void setStaffUserId(Long staffUserId)
    {
        this.staffUserId = staffUserId;
    }

    public Long getMemberId()
    {
        return memberId;
    }

    public void setMemberId(Long memberId)
    {
        this.memberId = memberId;
    }

    public String getOpenid()
    {
        return openid;
    }

    public void setOpenid(String openid)
    {
        this.openid = openid;
    }

    public Long getLoginTime()
    {
        return loginTime;
    }

    public void setLoginTime(Long loginTime)
    {
        this.loginTime = loginTime;
    }

    public Long getExpireTime()
    {
        return expireTime;
    }

    public void setExpireTime(Long expireTime)
    {
        this.expireTime = expireTime;
    }

    public Member getMember()
    {
        return member;
    }

    public void setMember(Member member)
    {
        this.member = member;
    }

    public Set<BizRole> getRoles() { return roles; }
    public void setRoles(Set<BizRole> roles) { this.roles = roles == null ? new HashSet<>() : roles; }

    public BizRole getStaffRole() { return staffRole; }
    public void setStaffRole(BizRole staffRole) { this.staffRole = staffRole; }

    /**
     * 是否拥有任一指定角色（多角色账号：OWNER 自动含 MANAGER 权限）
     */
    public boolean hasAnyRole(BizRole... candidates)
    {
        if (roles == null || roles.isEmpty() || candidates == null) return false;
        for (BizRole r : candidates)
        {
            if (r == null) continue;
            if (roles.contains(r)) return true;
        }
        return false;
    }

    /** 是否是老板 */
    public boolean isOwner() { return hasAnyRole(BizRole.OWNER); }
    /** 是否是店长及以上（OWNER 包含 MANAGER 权限） */
    public boolean isManagerOrAbove() { return hasAnyRole(BizRole.OWNER, BizRole.MANAGER); }
    /** 是否是合伙人/代理商 */
    public boolean isAgent() { return hasAnyRole(BizRole.AGENT); }
}
