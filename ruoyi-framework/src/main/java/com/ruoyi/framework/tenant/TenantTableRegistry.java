package com.ruoyi.framework.tenant;

import java.util.Collections;
import java.util.HashSet;
import java.util.Set;
import java.util.Arrays;

/**
 * 租户表注册表：声明哪些表需要 merchant_id 过滤，以及过滤强度
 *
 * <p>强隔离表：条件为 merchant_id = 当前商户；
 * 平台共享表：条件为 merchant_id in (0, 当前商户)，0 表示全平台通用数据。</p>
 *
 * @author dytuangou
 */
public class TenantTableRegistry
{
    /** 商户强隔离表 */
    private static final Set<String> ISOLATED_TABLES = Collections.unmodifiableSet(new HashSet<String>(Arrays.asList(
            "biz_store",
            "biz_store_album",
            "biz_store_user",
            "biz_member",
            "biz_product",
            "biz_product_store",
            "biz_order",
            "biz_booking",
            "biz_booking_member",
            "biz_pay_bill",
            "biz_member_voucher",
            "biz_distributor",
            "biz_commission",
            "biz_withdraw",
            "biz_settle_account",
            "biz_settle_record",
            "biz_mp_auth",
            "biz_mp_release",
            "biz_merchant_fee",
            "biz_merchant",
            "biz_merchant_staff",
            "biz_merchant_staff_invite",
            "biz_agent")));

    /** 平台共享表（merchant_id=0 表示全平台通用） */
    private static final Set<String> SHARED_TABLES = Collections.unmodifiableSet(new HashSet<String>(Arrays.asList(
            "biz_category",
            "biz_product_category",
            "biz_voucher",
            "biz_agreement",
            "biz_commission_rule",
            // biz_banner: 平台 banner (merchant_id=0) + 各商户自有 banner 都要能拉取
            // 小程序 ApiBannerController 是 anonymous 端点，按共享表语义走 merchant_id IN (0, ctx.merchantId)
            "biz_banner")));

    /**
     * 该表是否需要租户过滤
     */
    public static boolean isTenantTable(String tableName)
    {
        String name = normalize(tableName);
        return ISOLATED_TABLES.contains(name) || SHARED_TABLES.contains(name);
    }

    /**
     * 该表是否允许平台级共享数据（merchant_id=0）
     */
    public static boolean isSharedTable(String tableName)
    {
        return SHARED_TABLES.contains(normalize(tableName));
    }

    /**
     * 去掉库名前缀与反引号，统一小写
     */
    private static String normalize(String tableName)
    {
        if (tableName == null)
        {
            return "";
        }
        String name = tableName.replace("`", "").trim();
        int dot = name.lastIndexOf('.');
        if (dot >= 0)
        {
            name = name.substring(dot + 1);
        }
        return name.toLowerCase();
    }

    private TenantTableRegistry()
    {
    }
}
