package com.ruoyi.framework.api;

import java.util.Set;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;
import com.ruoyi.biz.api.annotation.RequireRole;
import com.ruoyi.biz.api.domain.LoginMember;
import com.ruoyi.biz.api.role.BizRole;
import com.ruoyi.biz.api.util.MemberContextHolder;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * 业务角色权限拦截器
 *
 * <p>校验规则（按 @RequireRole 注解）：</p>
 * <ul>
 *   <li>类或方法上有 @RequireRole → 解析 value[] 列表</li>
 *   <li>从 MemberContextHolder 取当前 LoginMember</li>
 *   <li>若 LoginMember.roles 与 value 任一匹配 → 通过</li>
 *   <li>includeHigher=true 时：OWNER 包含 MANAGER 权限（OWNER > MANAGER > STAFF）</li>
 *   <li>不匹配 → 403</li>
 *   <li>未登录 → 放行（由 MemberAuthInterceptor 先挡 401）</li>
 * </ul>
 */
@Component
public class RoleAuthInterceptor implements HandlerInterceptor
{
    /** 角色等级：OWNER=3 > MANAGER=2 > STAFF=1，AGENT/PLATFORM 单独算 */
    private static int roleRank(BizRole r)
    {
        if (r == null) return 0;
        switch (r)
        {
            case OWNER:   return 3;
            case MANAGER: return 2;
            case STAFF:   return 1;
            default:      return 0;
        }
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler)
            throws Exception
    {
        if (!(handler instanceof HandlerMethod))
        {
            return true;
        }
        HandlerMethod hm = (HandlerMethod) handler;
        RequireRole ann = hm.getMethodAnnotation(RequireRole.class);
        if (ann == null) ann = hm.getBeanType().getAnnotation(RequireRole.class);
        if (ann == null) return true;

        LoginMember lm = MemberContextHolder.get();
        if (lm == null) return true; // 放行，让 @LoginRequired 拦截器处理 401

        BizRole[] allowed = ann.value();
        if (allowed == null || allowed.length == 0) return true;

        Set<BizRole> myRoles = lm.getRoles();
        boolean ok = false;
        for (BizRole need : allowed)
        {
            if (need == null) continue;
            // PLATFORM 永远放行
            if (myRoles != null && myRoles.contains(BizRole.PLATFORM)) { ok = true; break; }
            // AGENT 仅匹配 AGENT
            if (need == BizRole.AGENT)
            {
                if (myRoles != null && myRoles.contains(BizRole.AGENT)) { ok = true; break; }
                continue;
            }
            // 商家端角色：includeHigher 时 OWNER 包含 MANAGER 权限
            if (myRoles != null && myRoles.contains(need)) { ok = true; break; }
            if (ann.includeHigher() && roleRank(need) > 0)
            {
                for (BizRole mine : myRoles)
                {
                    if (roleRank(mine) >= roleRank(need)) { ok = true; break; }
                }
                if (ok) break;
            }
        }
        if (!ok)
        {
            response.setStatus(HttpServletResponse.SC_OK);
            response.setContentType("application/json;charset=UTF-8");
            response.getWriter().write("{\"code\":\"403\",\"msg\":\"当前角色无权限访问该接口（需要 " + needRoles(allowed) + "）\"}");
            return false;
        }
        return true;
    }

    private String needRoles(BizRole[] arr)
    {
        if (arr == null) return "登录";
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < arr.length; i++)
        {
            if (i > 0) sb.append("/");
            sb.append(arr[i].name());
        }
        return sb.toString();
    }
}
