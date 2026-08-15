package com.ruoyi.biz.api.annotation;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * 标注需要"会员 + 推客标记"才能访问的接口
 *
 * <p>校验规则：当前 LoginMember 已登录 + 其 memberId 在 biz_distributor 表有记录
 * （即用户是会员且是推客）。</p>
 *
 * <p>与 @RequireRole 互不冲突，可同时标注：
 * <pre>
 *   &#64;LoginRequired
 *   &#64;DistributorRequired
 *   &#64;RequireRole(BizRole.OWNER)  // 限定商家 owner 角色的推客
 * </pre>
 * </p>
 *
 * <p>模型说明：5 角色（PLATFORM/AGENT/OWNER/MANAGER/STAFF）是员工身份，
 * 推客是 C 端会员身份。两者正交。</p>
 */
@Target({ ElementType.METHOD, ElementType.TYPE })
@Retention(RetentionPolicy.RUNTIME)
public @interface DistributorRequired
{
}
