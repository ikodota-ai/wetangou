package com.ruoyi.framework.api;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;
import com.ruoyi.biz.api.annotation.DistributorRequired;
import com.ruoyi.biz.api.domain.LoginMember;
import com.ruoyi.biz.api.util.MemberContextHolder;
import com.ruoyi.biz.domain.Distributor;
import com.ruoyi.biz.domain.Member;
import com.ruoyi.biz.service.IDistributorService;
import com.ruoyi.biz.service.IMemberService;
import com.ruoyi.biz.service.ITenantService;
import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.domain.model.TenantContext;
import com.ruoyi.common.utils.TenantContextHolder;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * 推客身份校验拦截器（v2.5 V5-11）
 *
 * <p>判别顺序（v2.5 P2 优化版）：</p>
 * <ol>
 *   <li>判 @Anonymous：放行（如 /join 申请加入）</li>
 *   <li>判是否登录（必须有 LoginMember）</li>
 *   <li>判是不是"会员"：必须有真实的 wx openid（"staff:{userId}" 是未绑微信时的占位字符串，不算真实 openid）</li>
 *   <li>判是不是"推客"：biz_distributor 有该 memberId 记录（C 端）或按 openid 反查命中</li>
 * </ol>
 *
 * <p>此拦截器只挡推客端点（/api/distributor/**）。其他端点不受影响。</p>
 */
@Component
public class DistributorAuthInterceptor implements HandlerInterceptor
{
    @Autowired
    private IDistributorService distributorService;
    @Autowired
    private IMemberService memberService;
    @Autowired
    private ITenantService tenantService;

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler)
            throws Exception
    {
        if (!(handler instanceof HandlerMethod)) return true;
        HandlerMethod hm = (HandlerMethod) handler;

        // 0) 商户级推客总开关。必须排在 @Anonymous 之前 ——
        //    /join 是 @Anonymous 的（未成为推客的人也要能申请），如果放在后面，
        //    商户明明关了推客功能，任何人直接 POST /api/distributor/join 仍会真的
        //    在 biz_distributor 建一条记录（实测：开关=0 时 join 返 200 并建出
        //    distributor_id=999927）。前端隐藏入口只是体验层，服务端必须自己挡。
        //    /agent/summary 也是 @Anonymous，但那是代理商视角、不属于 C 端推客业务，
        //    所以按路径排除，别把代理商的佣金概览一起关掉。
        if (!isPromoterEnabled() && !isAgentScoped(request))
        {
            writeError(response, 403, "该商家暂未开通推客功能");
            return false;
        }

        // 1) @Anonymous 放行
        if (hm.hasMethodAnnotation(Anonymous.class) || hm.getBeanType().isAnnotationPresent(Anonymous.class))
        {
            return true;
        }

        // 2) 找 @DistributorRequired（方法级或类级）
        DistributorRequired ann = hm.getMethodAnnotation(DistributorRequired.class);
        if (ann == null) ann = hm.getBeanType().getAnnotation(DistributorRequired.class);
        if (ann == null) return true;

        // 3) 已登录
        LoginMember lm = MemberContextHolder.get();
        if (lm == null)
        {
            writeError(response, 401, "请先登录");
            return false;
        }

        // 4) 是不是"会员"：必须绑了微信（openid 是 "oXXX..." 真实 openid）
        //    "staff:{userId}" 占位字符串是 buildLoginMember 给未绑微信的 sys_user 填的占位，不是真实 openid
        //    员工绑了微信后 sys_user.openid 就是真实 wx openid（"oXXX..."），照样能进推客端点
        String openid = lm.getOpenid();
        boolean isMember = openid != null && !openid.isEmpty() && !openid.startsWith("staff:");
        if (!isMember)
        {
            writeError(response, 403, "仅会员可访问推客功能");
            return false;
        }

        // 5) 是不是"推客"
        //    策略 1：C 端会员 token（userType=member），LoginMember.memberId = biz_member.member_id，直接查
        //    策略 2：员工 token（userType=owner/manager/staff），openid 是 wx openid，反查 biz_member 再查推客
        Distributor dist = findDistributor(lm, openid);
        if (dist == null)
        {
            writeError(response, 403, "您还不是推客，请先申请加入");
            return false;
        }
        return true;
    }

    /**
     * 当前请求所属商户是否开了推客功能。
     *
     * 商户由 MemberAuthInterceptor 按 X-App-Id 解析进 TenantContext（本拦截器
     * 注册在它后面，所以这里一定拿得到）。取不到商户时一律放行 —— 宁可放过，
     * 也不要因为解析失败把已开通商户的推客全锁在外面。
     *
     * 空值兜底成"已开通"：merchant:appid:* 缓存是 fastjson 序列化对象且没有 TTL，
     * 加 promoter_enabled 列之前写进 Redis 的老快照反序列化回来是 null，
     * 若按"非 1 即关"处理，升级瞬间所有存量商户的推客都会被 403。
     */
    private boolean isPromoterEnabled()
    {
        try
        {
            TenantContext ctx = TenantContextHolder.get();
            Long merchantId = ctx == null ? null : ctx.getMerchantId();
            if (merchantId == null) return true;
            Merchant merchant = tenantService.getMerchantById(merchantId);
            if (merchant == null) return true;
            String flag = merchant.getPromoterEnabled();
            return flag == null || flag.isEmpty() || !"0".equals(flag);
        }
        catch (Exception e)
        {
            // 开关判断本身出错不能变成"全员禁用"
            return true;
        }
    }

    /** /api/distributor/agent/** 是代理商视角，不受 C 端推客开关约束 */
    private static boolean isAgentScoped(HttpServletRequest request)
    {
        String uri = request.getRequestURI();
        return uri != null && uri.contains("/api/distributor/agent/");
    }

    private Distributor findDistributor(LoginMember lm, String openid)
    {
        // 策略 1：直接按 LoginMember.memberId 查（C 端会员）
        if (lm.getMemberId() != null)
        {
            Distributor d = distributorService.findByMemberId(lm.getMemberId());
            if (d != null) return d;
        }
        // 策略 2：按 openid 反查 biz_member（员工 / 跨端登录场景）
        //   - 员工（OWNER/MANAGER/STAFF）：lm.merchantId 是当前所属商家，限定 merchantId
        //   - 代理商/平台：lm.merchantId 为 null，跨商户查（一个 openid 只会绑一个会员）
        //   - 员工绑微信后 sys_user.openid 与 biz_member.openid 一致，自动识别为推客
        Long merchantId = lm.getMerchantId();
        try
        {
            Member m = memberService.selectByOpenidAcrossMerchant(merchantId, openid);
            if (m == null) return null;
            return distributorService.findByMemberId(m.getMemberId());
        }
        catch (Exception ignore)
        {
            return null;
        }
    }

    private void writeError(HttpServletResponse response, int code, String msg) throws java.io.IOException
    {
        response.setStatus(HttpServletResponse.SC_OK);
        response.setContentType("application/json;charset=UTF-8");
        // code 必须是数字：小程序 request.js 判的是业务码，AjaxResult 那条链一直返数字，
        // 这里以前写成字符串 "403"，两边不一致会让前端漏判（实测非推客提交提现，
        // 后端返 {"code":"403"} 但前端走了成功分支，弹「提现申请已提交」）。
        response.getWriter().write("{\"code\":" + code + ",\"msg\":\"" + msg + "\"}");
    }
}
