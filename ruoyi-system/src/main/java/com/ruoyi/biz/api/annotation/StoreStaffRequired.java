package com.ruoyi.biz.api.annotation;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * 标注仅限门店端员工访问的接口
 *
 * <p>核销、确认买单等动作只允许在「门店端工作台」上由门店员工操作。
 * 要求 token 内带 userType=store 且 sys_user 已在 biz_store_user 中关联到该订单/买单所属门店。</p>
 *
 * <p>与 {@link LoginRequired} 配合使用：先校验会员登录态，再校验门店员工身份。</p>
 *
 * @author dytuangou
 */
@Target({ ElementType.METHOD, ElementType.TYPE })
@Retention(RetentionPolicy.RUNTIME)
public @interface StoreStaffRequired
{
    /**
     * 从请求体/路径中读取 storeId 的字段名，缺省走路由占位 {storeId}
     */
    String storeIdParam() default "storeId";

    /**
     * 用于从路径占位或请求体中取订单/买单/报名 ID 的字段名，
     * 再按订单.merchantId 校验门店员工。
     */
    String targetIdParam() default "";
}
