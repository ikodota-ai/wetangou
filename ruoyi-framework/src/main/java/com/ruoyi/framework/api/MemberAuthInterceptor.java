package com.ruoyi.framework.api;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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
 * <p>改进点：
 * <ul>
 *   <li>当 X-App-Id 解析不到对应商户时，记录 WARN 日志，便于排查
 *       "默认商户 fallback 导致跨商户看不到门店" 的问题。</li>
 *   <li>对外暴露的接口全部显式走 resolveTenantByAppid，确保 biz_* 强隔离表
 *       不会因为 TenantContextHolder 为空而返回全平台数据。</li>
 * </ul>
 * </p>
 *
 * @author dytuangou
 */
@Component
public class MemberAuthInterceptor implements HandlerInterceptor
{
    private static final Logger log = LoggerFactory.getLogger(MemberAuthInterceptor.class);

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
            writeError(response, 401, "会员未登录或登录已过期", "member");
            return false;
        }
        if ((staffMethodAnno != null || staffClassAnno != null))
        {
            if (loginMember == null)
            {
                // authScope=staff：调用方拿的是会员 token（或无 token）访问商家端接口，
                // 前端只应清员工会话，不能连带清掉仍然有效的会员 token
                writeError(response, 401, "员工登录态失效，请重新登录", "staff");
                return false;
            }
            if (!"store".equals(loginMember.getUserType()))
            {
                writeError(response, 403, "此操作仅限门店端员工");
                return false;
            }
        }
        // 强校验：员工只能操作自己门店集合内的资源（多门店权限）
        // 1) 注解上指定了 storeIdParam（如 ?storeId=... 或路径占位 {storeId}），
        //    请求中带的 storeId 必须属于 token 内 storeIds 集合
        // 2) 注解上指定了 targetIdParam（订单/买单/报名 ID），
        //    会按该 ID 反查 storeId 再与 token 内 storeIds 比对
        // 防御 null：login 接口走 @Anonymous 不会带 token，loginMember 可能为 null；
        // 此时若端点又标了 @StoreStaffRequired 应返回 401
        if ((staffMethodAnno != null || staffClassAnno != null)
                && loginMember != null
                && "store".equals(loginMember.getUserType()))
        {
            java.util.List<Long> tokenStoreIds = loginMember.getStoreIds();
            Long currentStoreId = loginMember.getStoreId();
            // 兼容旧 token（只有 storeId，没有 storeIds 集合）— 把单值当作单元素集合
            if ((tokenStoreIds == null || tokenStoreIds.isEmpty()) && currentStoreId != null)
            {
                tokenStoreIds = java.util.Collections.singletonList(currentStoreId);
            }
            if (tokenStoreIds == null || tokenStoreIds.isEmpty())
            {
                writeError(response, 403, "员工 token 缺少 storeIds 信息");
                return false;
            }
            String storeIdParam = (staffMethodAnno != null ? staffMethodAnno : staffClassAnno).storeIdParam();
            String storeIdStr = request.getParameter(storeIdParam);
            if (storeIdStr == null)
            {
                Object pathVar = request.getAttribute("org.springframework.web.servlet.HandlerMapping.uriTemplateVariables");
                if (pathVar instanceof java.util.Map)
                {
                    Object v = ((java.util.Map<?, ?>) pathVar).get(storeIdParam);
                    if (v != null) storeIdStr = v.toString();
                }
            }
            if (storeIdStr != null)
            {
                Long reqStoreId;
                try { reqStoreId = Long.parseLong(storeIdStr); }
                catch (NumberFormatException e) { reqStoreId = null; }
                if (reqStoreId == null || !tokenStoreIds.contains(reqStoreId))
                {
                    writeError(response, 403, "员工无权操作其他门店资源");
                    return false;
                }
            }
        }
        return true;
    }

    private void writeError(HttpServletResponse response, int code, String msg) throws java.io.IOException
    {
        writeError(response, code, msg, null);
    }

    /**
     * 输出错误 JSON。
     *
     * @param authScope 认证域标记，供小程序端区分「会员态失效」与「员工态失效」：
     *                  member = 会员 token 无效，前端可清会员 token 并静默重登；
     *                  staff  = 员工登录态缺失（常见于会员 token 访问商家端接口），
     *                           此时**不得**清掉有效的会员 token。
     *                  注意 code 必须是数字（历史版本写成字符串 "401"，前端 d.code === 401 判不中）。
     */
    private void writeError(HttpServletResponse response, int code, String msg, String authScope)
            throws java.io.IOException
    {
        response.setStatus(HttpServletResponse.SC_OK);
        response.setContentType("application/json;charset=UTF-8");
        StringBuilder sb = new StringBuilder();
        sb.append("{\"code\":").append(code).append(",\"msg\":\"").append(msg).append("\"");
        if (authScope != null)
        {
            sb.append(",\"authScope\":\"").append(authScope).append("\"");
        }
        sb.append("}");
        response.getWriter().write(sb.toString());
    }

    /**
     * 匿名请求按 X-App-Id 请求头解析商户并写入租户上下文
     *
     * <p>解析优先级：</p>
     * <ol>
     *   <li>X-App-Id header → sys_param.appid 命中 → 写入该商户</li>
     *   <li>?appid= query → 同上</li>
     *   <li>任何步骤都查不到（appid 缺失 / 不匹配 / 商户停用）→ fallback 到
     *       {@link TenantConstants#DEFAULT_MERCHANT_ID}，并打 WARN 日志，
     *       便于排查 "前端传了 appid 但数据库没匹配" 这类静默问题。</li>
     * </ol>
     *
     * <p>fallback 不能去掉：保留它是为了让「单商户小程序在未配置 appid 的
     * 极端情况下还能看到默认商户数据」。</p>
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
            log.warn("[resolveTenantByAppid] X-App-Id={} 未匹配到有效商户(status=0)，fallback 到默认商户 {}",
                    appid, TenantConstants.DEFAULT_MERCHANT_ID);
        }
        else
        {
            log.warn("[resolveTenantByAppid] 匿名请求未带 X-App-Id header，fallback 到默认商户 {}",
                    TenantConstants.DEFAULT_MERCHANT_ID);
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
