package com.ruoyi.common.utils;

import com.ruoyi.common.core.domain.model.TenantContext;

/**
 * 租户上下文持有者（线程级）
 *
 * <p>后台请求由 JwtAuthenticationTokenFilter 写入，小程序请求由 MemberAuthInterceptor 写入，
 * MyBatis 租户拦截器据此为业务SQL自动追加 merchant_id 条件。</p>
 *
 * @author dytuangou
 */
public class TenantContextHolder
{
    private static final ThreadLocal<TenantContext> CONTEXT = new ThreadLocal<TenantContext>();

    /** 临时忽略过滤的开关（用于内部跨商户操作，如按appid查商户本身） */
    private static final ThreadLocal<Boolean> IGNORE = new ThreadLocal<Boolean>();

    public static void set(TenantContext context)
    {
        CONTEXT.set(context);
    }

    public static TenantContext get()
    {
        return CONTEXT.get();
    }

    /**
     * 当前商户ID，无上下文时返回null
     */
    public static Long getMerchantId()
    {
        TenantContext context = CONTEXT.get();
        return context == null ? null : context.getMerchantId();
    }

    /**
     * 是否需要对SQL做租户过滤
     */
    public static boolean needFilter()
    {
        if (Boolean.TRUE.equals(IGNORE.get()))
        {
            return false;
        }
        TenantContext context = CONTEXT.get();
        if (context == null || context.isPlatform())
        {
            // 无上下文（定时任务、启动初始化等）不过滤，避免误伤系统级操作
            return false;
        }
        return true;
    }

    /**
     * 在忽略租户过滤的前提下执行，执行完自动恢复
     */
    public static <T> T ignoreTenant(java.util.function.Supplier<T> supplier)
    {
        Boolean origin = IGNORE.get();
        IGNORE.set(Boolean.TRUE);
        try
        {
            return supplier.get();
        }
        finally
        {
            if (origin == null)
            {
                IGNORE.remove();
            }
            else
            {
                IGNORE.set(origin);
            }
        }
    }

    public static void remove()
    {
        CONTEXT.remove();
        IGNORE.remove();
    }
}
