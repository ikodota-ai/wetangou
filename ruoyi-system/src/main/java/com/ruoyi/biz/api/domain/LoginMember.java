package com.ruoyi.biz.api.domain;

import java.io.Serializable;
import java.util.List;
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
     * 门店员工身份时可管理的门店 ID 集合（多门店权限）
     */
    private List<Long> storeIds;

    /**
     * 门店员工身份时当前激活的门店 ID（多门店时切换用，默认取集合第一个）
     */
    private Long storeId;

    public LoginMember()
    {
    }

    public LoginMember(Member member)
    {
        this.member = member;
        this.memberId = member.getMemberId();
        this.openid = member.getOpenid();
        this.merchantId = member.getMerchantId();
    }

    public Long getMerchantId()
    {
        return merchantId;
    }

    public void setMerchantId(Long merchantId)
    {
        this.merchantId = merchantId;
    }

    public String getUserType()
    {
        return userType;
    }

    public void setUserType(String userType)
    {
        this.userType = userType;
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

    public String getToken()
    {
        return token;
    }

    public void setToken(String token)
    {
        this.token = token;
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
}
