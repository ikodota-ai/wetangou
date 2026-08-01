package com.ruoyi.common.annotation;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * 忽略租户过滤
 *
 * <p>标注在 Mapper 接口或方法上，被标注的查询不会被自动追加 merchant_id 条件。
 * 适用于平台侧统计、跨商户对账等确实需要全量数据的场景，使用时务必自行校验权限。</p>
 *
 * @author dytuangou
 */
@Target({ ElementType.METHOD, ElementType.TYPE })
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface IgnoreTenant
{
}
