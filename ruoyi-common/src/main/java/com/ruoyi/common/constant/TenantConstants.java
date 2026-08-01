package com.ruoyi.common.constant;

/**
 * 多商户（租户）相关常量
 *
 * @author dytuangou
 */
public class TenantConstants
{
    /** 租户隔离字段名 */
    public static final String COLUMN_MERCHANT_ID = "merchant_id";

    /** 平台账号：不受商户过滤限制 */
    public static final String USER_TYPE_PLATFORM = "0";

    /** 代理商账号：可见名下所有商户 */
    public static final String USER_TYPE_AGENT = "1";

    /** 商户账号：仅可见本商户 */
    public static final String USER_TYPE_MERCHANT = "2";

    /** 平台级共享数据的商户ID（0 表示全平台通用） */
    public static final Long PLATFORM_MERCHANT_ID = 0L;

    /** 存量单商户默认商户ID（小程序未传appid时兑底，避免退化为全平台可见） */
    public static final Long DEFAULT_MERCHANT_ID = 1L;

    /** 商户信息缓存key前缀（按appid） */
    public static final String MERCHANT_APPID_KEY = "merchant:appid:";

    /** 商户信息缓存key前缀（按商户ID） */
    public static final String MERCHANT_ID_KEY = "merchant:id:";

    /** 后台账号租户归属缓存key前缀 */
    public static final String MERCHANT_USER_KEY = "merchant:user:";

    private TenantConstants()
    {
    }
}
