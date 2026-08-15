package com.ruoyi.biz.api.role;

/**
 * 业务角色（小程序端 3 商家角色 + 平台 + 代理商 = 5 角色）
 *
 * <p>角色与 sys_user.user_type 关系：</p>
 * <ul>
 *   <li>PLATFORM = sys_user.user_type='00'（PC 端 admin，外出在小程序查跨店数据）</li>
 *   <li>AGENT    = sys_user.user_type='01'（PC 端代理商，小程序端管名下商家）</li>
 *   <li>OWNER    = sys_user.user_type='02' + biz_merchant_staff.role='OWNER'（老板）</li>
 *   <li>MANAGER  = sys_user.user_type='02' + biz_merchant_staff.role='MANAGER'（店长）</li>
 *   <li>STAFF    = sys_user.user_type='02' + biz_merchant_staff.role='STAFF'（店员）</li>
 * </ul>
 */
public enum BizRole
{
    /** 平台（PC 后台 admin） */
    PLATFORM,
    /** 代理商（PC 端 + 小程序端共享身份） */
    AGENT,
    /** 老板（小程序商家端最高权限，看全部数据 + 资金/员工管理） */
    OWNER,
    /** 店长（小程序商家端中层，看本店数据 + 核销 + 订单） */
    MANAGER,
    /** 店员（小程序商家端基层，仅核销/扫码） */
    STAFF;

    /**
     * 从 biz_merchant_staff.role 字符串解析
     */
    public static BizRole fromStaffRole(String role)
    {
        if (role == null || role.isEmpty()) return STAFF;
        try
        {
            return BizRole.valueOf(role.toUpperCase());
        }
        catch (IllegalArgumentException e)
        {
            return STAFF;
        }
    }

    /**
     * 从 sys_user.user_type 解析（PC 端身份）
     */
    public static BizRole fromUserType(String userType)
    {
        if (userType == null || userType.isEmpty()) return PLATFORM;
        switch (userType)
        {
            case "01": return AGENT;
            case "02": return STAFF; // 默认 STAFF，由 buildLoginMember 按 role 升级到 OWNER/MANAGER
            case "03": return STAFF;
            case "04": return OWNER;
            default:   return PLATFORM;
        }
    }
}
