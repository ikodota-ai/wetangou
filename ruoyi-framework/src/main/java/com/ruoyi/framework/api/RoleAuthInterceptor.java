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
 *   <li>PLATFORM / AGENT 只匹配显式声明了自己的端点，不穿透商家端职务序列</li>
 *   <li>不匹配 → 403</li>
 *   <li>未登录 → 放行（由 MemberAuthInterceptor 先挡 401）</li>
 * </ul>
 */
@Component
public class RoleAuthInterceptor implements HandlerInterceptor
{
    /**
     * 角色等级统一取 {@link BizRole#rank()}。
     *
     * <p>这里原本另抄了一份 switch，和 BizRole.rank() 是两份要各自维护的真值表 ——
     * 将来往枚举里加职务（例如财务、收银）只改一处，另一处就会静默算错等级。</p>
     */
    private static int roleRank(BizRole r)
    {
        return r == null ? 0 : r.rank();
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
            // PLATFORM 只匹配显式声明了 PLATFORM 的端点。
            //
            // 原来这里是「含 PLATFORM 就无条件放行」，等于平台账号可以穿透全部商家端
            // @RequireRole。已定的产品决策是「平台账号和代理商不允许登录商家版」，
            // 平台要跨店看数据走 ApiPlatformController 的 @RequireRole(PLATFORM) 专属端点。
            // 之前挡住平台账号的只是各端点内部「merchantId 为空」的巧合 —— 不是防护：
            // /api/merchant/staff/me 不依赖 merchantId，平台账号实测能拿到 200 和账号资料。
            // 一旦某个平台账号被顺手填上 merchant_id，整片商家端就全部敞开。
            if (need == BizRole.PLATFORM)
            {
                if (myRoles != null && myRoles.contains(BizRole.PLATFORM)) { ok = true; break; }
                continue;
            }
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
            // 同 DistributorAuthInterceptor：code 返数字，字符串 "403" 会被前端漏判
            // （实测店员点「招人」拿到 403，前端却进成功分支渲染出空白邀请码）。
            response.getWriter().write("{\"code\":403,\"msg\":\"当前角色无权限访问该接口（需要 " + needRoles(allowed) + "）\"}");
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
