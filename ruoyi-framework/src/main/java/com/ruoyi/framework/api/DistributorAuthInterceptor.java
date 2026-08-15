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
import com.ruoyi.common.annotation.Anonymous;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * 推客身份校验拦截器（v2.5 V5-11）
 *
 * <p>判别顺序（v2.5 P2 优化版）：</p>
 * <ol>
 *   <li>判 @Anonymous：放行（如 /join 申请加入）</li>
 *   <li>判是否登录（必须有 LoginMember）</li>
 *   <li>判是不是"会员"：必须有 openid（员工占位 openid "staff:{userId}" 视为非会员）</li>
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

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler)
            throws Exception
    {
        if (!(handler instanceof HandlerMethod)) return true;
        HandlerMethod hm = (HandlerMethod) handler;

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

        // 4) 是不是"会员"（按 openid 判定，员工占位 "staff:" 不算会员）
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
        response.getWriter().write("{\"code\":\"" + code + "\",\"msg\":\"" + msg + "\"}");
    }
}
