package com.ruoyi.framework.api;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;
import com.ruoyi.biz.api.annotation.LoginRequired;
import com.ruoyi.biz.api.domain.LoginMember;
import com.ruoyi.biz.api.util.MemberContextHolder;
import com.ruoyi.biz.api.util.MemberTokenService;
import com.ruoyi.common.constant.TenantConstants;
import com.ruoyi.common.core.domain.model.TenantContext;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.common.utils.TenantContextHolder;
import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.biz.service.ITenantService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * 小程序会员登录拦截器：对标注 @LoginRequired 的接口校验会员token
 *
 * @author dytuangou
 */
@Component
public class MemberAuthInterceptor implements HandlerInterceptor
{
    /** 小程序传递appid的请求头 */
    private static final String HEADER_APPID = "X-App-Id";

    @Autowired
    private MemberTokenService memberTokenService;

    @Autowired
    private ITenantService tenantService;

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler)
            throws Exception
    {
        if (!(handler instanceof HandlerMethod))
        {
            return true;
        }
        HandlerMethod handlerMethod = (HandlerMethod) handler;
        LoginRequired methodAnno = handlerMethod.getMethodAnnotation(LoginRequired.class);
        LoginRequired classAnno = handlerMethod.getBeanType().getAnnotation(LoginRequired.class);
        com.ruoyi.biz.api.annotation.StoreStaffRequired staffMethodAnno = handlerMethod.getMethodAnnotation(
                com.ruoyi.biz.api.annotation.StoreStaffRequired.class);
        com.ruoyi.biz.api.annotation.StoreStaffRequired staffClassAnno = handlerMethod.getBeanType().getAnnotation(
                com.ruoyi.biz.api.annotation.StoreStaffRequired.class);

        LoginMember loginMember = memberTokenService.getLoginMember(request);
        if (loginMember != null)
        {
            memberTokenService.verifyToken(loginMember);
            MemberContextHolder.set(loginMember);
            // 写入租户上下文，使小程序端查询自动限定在会员所属商户
            if (loginMember.getMerchantId() != null)
            {
                TenantContextHolder.set(TenantContext.ofMerchant(loginMember.getMerchantId()));
            }
        }
        else
        {
            // 未登录的匿名接口（门店/商品列表等）按请求头中的appid限定商户
            resolveTenantByAppid(request);
        }

        boolean required = methodAnno != null || classAnno != null;
        if (required && loginMember == null)
        {
            response.setStatus(HttpServletResponse.SC_OK);
            response.setContentType("application/json;charset=UTF-8");
            writeError(response, 401, "会员未登录或登录已过期");
            return false;
        }
        if ((staffMethodAnno != null || staffClassAnno != null) && !"store".equals(loginMember.getUserType()))
        {
            writeError(response, 403, "此操作仅限门店端员工");
            return false;
        }
        return true;
    }

    private void writeError(HttpServletResponse response, int code, String msg) throws java.io.IOException
    {
        response.setStatus(HttpServletResponse.SC_OK);
        response.setContentType("application/json;charset=UTF-8");
        response.getWriter().write("{\"code\":\"" + code + "\",\"msg\":\"" + msg + "\"}");
    }

    /**
     * 匿名请求按 X-App-Id 请求头解析商户并写入租户上下文
     *
     * <p>未传或查不到 appid 时兑底为默认商户，兼容存量单商户小程序；
     * 不能置空上下文，否则匿名接口将返回全平台数据造成跨商户泄露。</p>
     */
    private void resolveTenantByAppid(HttpServletRequest request)
    {
        String appid = request.getHeader(HEADER_APPID);
        if (StringUtils.isEmpty(appid))
        {
            appid = request.getParameter("appid");
        }
        if (StringUtils.isNotEmpty(appid))
        {
            Merchant merchant = tenantService.getMerchantByAppid(appid);
            if (merchant != null && "0".equals(merchant.getStatus()))
            {
                TenantContextHolder.set(TenantContext.ofMerchant(merchant.getMerchantId()));
                return;
            }
        }
        TenantContextHolder.set(TenantContext.ofMerchant(TenantConstants.DEFAULT_MERCHANT_ID));
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response, Object handler, Exception ex)
    {
        MemberContextHolder.remove();
        TenantContextHolder.remove();
    }
}
