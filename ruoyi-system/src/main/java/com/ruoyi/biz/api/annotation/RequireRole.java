package com.ruoyi.biz.api.annotation;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import com.ruoyi.biz.api.role.BizRole;

/**
 * 标注接口所需的业务角色
 *
 * <p>使用示例：</p>
 * <pre>
 *   {@code
 *   // 只允许老板
 *   @RequireRole(BizRole.OWNER)
 *   public AjaxResult finance() { ... }
 *
 *   // 老板或店长都可
 *   @RequireRole({BizRole.OWNER, BizRole.MANAGER})
 *   public AjaxResult orderSummary() { ... }
 *
 *   // 平台 + 老板 + 店长（代理商不可，店员不可）
 *   @RequireRole(value = {BizRole.PLATFORM, BizRole.OWNER, BizRole.MANAGER})
 *   public AjaxResult merchantStats() { ... }
 *   }
 * </pre>
 *
 * <p>校验规则：</p>
 * <ul>
 *   <li>从 {@link com.ruoyi.biz.api.util.MemberContextHolder} 取当前 LoginMember</li>
 *   <li>若 LoginMember.roles 与 value 中任一匹配 → 通过</li>
 *   <li>否则 → 403 Forbidden</li>
 *   <li>未登录 → 由 @LoginRequired 拦截器先挡，@RequireRole 不重复处理</li>
 * </ul>
 */
@Target({ ElementType.METHOD, ElementType.TYPE })
@Retention(RetentionPolicy.RUNTIME)
public @interface RequireRole
{
    /** 允许访问的角色集合（任一命中即通过） */
    BizRole[] value() default {};

    /**
     * 是否包含更高权限角色（默认 false）
     * - true 时：标注 MANAGER 实际允许 OWNER + MANAGER（OWNER 包含 MANAGER 权限）
     * - false 时：严格匹配，OWNER 不包含 MANAGER 的反向
     */
    boolean includeHigher() default true;
}
