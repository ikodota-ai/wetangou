package com.ruoyi.biz.api.util;

import com.ruoyi.biz.api.domain.LoginMember;

/**
 * 小程序会员上下文（线程级）
 *
 * @author dytuangou
 */
public class MemberContextHolder
{
    private static final ThreadLocal<LoginMember> CONTEXT = new ThreadLocal<>();

    public static void set(LoginMember member)
    {
        CONTEXT.set(member);
    }

    public static LoginMember get()
    {
        return CONTEXT.get();
    }

    public static Long getMemberId()
    {
        LoginMember member = CONTEXT.get();
        return member == null ? null : member.getMemberId();
    }

    /**
     * 当前会员所属商户ID
     */
    public static Long getMerchantId()
    {
        LoginMember member = CONTEXT.get();
        return member == null ? null : member.getMerchantId();
    }

    public static void remove()
    {
        CONTEXT.remove();
    }
}
