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
            // token 与当前小程序必须同源：多商户下每商户一个小程序，
            // 不校验的话 A 商户小程序里签发的 token，换到 B 商户的小程序里照样通行
            // （X-App-Id 原本只用于匿名请求解析租户，带 token 的请求根本不看它）。
            if (!appidMatches(loginMember, request))
            {
                writeError(response, 401, "登录态与当前小程序不匹配，请重新登录",
                        loginMember.isStaffSession() ? "staff" : "member");
                return false;
            }
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
            if (!isStaffSession(loginMember))
            {
                writeError(response, 403, "此操作仅限门店/商家端员工");
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
                && isStaffSession(loginMember))
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

    /**
     * 是否属于「员工会话」（可访问 {@code @StoreStaffRequired} 端点）。
     *
     * <p>历史实现只认 {@code userType=store}（旧门店端登录链路 /api/store/staff/login）。
     * 商家端登录链路（/api/merchant/staff/login|wxLogin、会员授权自动识别员工）发的是
     * owner / manager / staff，于是核销 {@code POST /api/order/verify}、确认买单
     * {@code /api/bill/confirm} 这些挂了 @StoreStaffRequired 的端点对商家端三种角色
     * 全部返回 403「此操作仅限门店端员工」—— 也就是老板、店长、扫码入职的店员
     * 进了商家版却一张券都核销不了，这是商家端最核心功能的阻塞点。</p>
     *
     * <p>注意：放行后下面的「门店集合校验」也必须对新链路生效（同样用本方法判定），
     * 否则商家端员工带 storeId 参数就能操作别家门店。</p>
     */
    /**
     * 校验 token 与当前请求的小程序是否同源。
     *
     * <p>比对口径故意宽松，只拦「明确不一致」，避免误伤存量：</p>
     * <ul>
     *   <li>token 里没有 appid（本次改造之前签发的老 token）→ 放行，
     *       等它自然过期即可，否则升级瞬间全量用户被踢下线</li>
     *   <li>请求没带 X-App-Id（H5 / 后台代调 / 老版本小程序）→ 放行，
     *       租户边界仍由 token 内的 merchantId 兜底</li>
     *   <li>两者都有且不相等 → 拒绝，这就是跨小程序串用的情形</li>
     * </ul>
     */
    private boolean appidMatches(LoginMember loginMember, HttpServletRequest request)
    {
        String tokenAppid = loginMember.getAppid();
        if (StringUtils.isEmpty(tokenAppid))
        {
            return true;
        }
        String reqAppid = request.getHeader(HEADER_APPID);
        if (StringUtils.isEmpty(reqAppid))
        {
            reqAppid = request.getParameter("appid");
        }
        if (StringUtils.isEmpty(reqAppid))
        {
            return true;
        }
        if (tokenAppid.equals(reqAppid))
        {
            return true;
        }
        log.warn("[appidMatches] token 签发 appid={} 与请求 X-App-Id={} 不一致，拒绝该请求 uri={}",
                tokenAppid, reqAppid, request.getRequestURI());
        return false;
    }

    private boolean isStaffSession(LoginMember loginMember)
    {
        return loginMember != null && loginMember.isStaffSession();
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
