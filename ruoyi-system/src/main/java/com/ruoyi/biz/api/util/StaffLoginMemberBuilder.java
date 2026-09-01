package com.ruoyi.biz.api.util;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import com.ruoyi.biz.api.domain.LoginMember;
import com.ruoyi.biz.api.role.BizRole;
import com.ruoyi.biz.domain.MerchantStaff;
import com.ruoyi.common.core.domain.entity.SysUser;

/**
 * 商家员工登录态构建器（两条登录链路唯一实现）
 *
 * <p>背景：商家版有两条登录入口——
 * <ul>
 *   <li>{@code /api/merchant/staff/login|wxLogin}：账号密码 / 静默 openid</li>
 *   <li>{@code /api/auth/login}：会员授权后按 openid 识别出员工身份</li>
 * </ul>
 * 两者原本各有一份 buildLoginMember，第二份是从第一份**复制**的（注释写着"复制自"），
 * 复制时把 {@code staffRoleRank()} 漏掉、改用了 {@code BizRole.ordinal()}。
 * 而枚举声明顺序是 PLATFORM(0)/AGENT(1)/OWNER(2)/MANAGER(3)/STAFF(4)，
 * 按 ordinal 比大小等于「STAFF 权限最高」，于是老板兼任任一门店店员后，
 * 走会员授权链路登录会被降权成 STAFF —— 同一个人、同一时刻，两条链路给出不同身份。</p>
 *
 * <p>因此这里收口为唯一实现，等级判断统一走 {@link BizRole#rank()}。</p>
 */
public final class StaffLoginMemberBuilder
{
    private StaffLoginMemberBuilder()
    {
    }

    /**
     * 按员工关联构建商家端登录态。
     *
     * @param user          sys_user 账号
     * @param links         该账号的在职员工关联（调用方需先过滤掉待审核/离职）
     * @param fallbackType  没有任何商家职务时的兜底 userType
     * @param agentIdLookup 代理商 ID 查询（user_type=01 时用，可为 null）
     */
    public static LoginMember build(SysUser user, List<MerchantStaff> links, String fallbackType,
                                    java.util.function.Function<Long, Long> agentIdLookup)
    {
        return build(user, links, fallbackType, agentIdLookup, null);
    }

    /**
     * 同 {@link #build(SysUser, List, String, java.util.function.Function)}，额外支持把
     * {@code store_id=0}（全商户）展开成该商户下的真实门店列表。
     *
     * @param storeIdsOfMerchant 按 merchantId 查其所有门店 ID；为 null 时不展开
     */
    public static LoginMember build(SysUser user, List<MerchantStaff> links, String fallbackType,
                                    java.util.function.Function<Long, Long> agentIdLookup,
                                    java.util.function.Function<Long, List<Long>> storeIdsOfMerchant)
    {
        List<Long> storeIds = new ArrayList<>();
        Long merchantId = null;
        Set<BizRole> roles = new HashSet<>();
        BizRole maxStaffRole = null;
        // store_id=0 表示「全商户所有门店」（老板/商户级职务用），需要展开成真实门店列表，
        // 否则商家端所有查询都会按 store_id=0 过滤，一条数据都查不到。
        boolean allStores = false;
        if (links != null)
        {
            for (MerchantStaff l : links)
            {
                if (l.getStoreId() != null && l.getStoreId() == 0L)
                {
                    allStores = true;
                }
                else if (l.getStoreId() != null && !storeIds.contains(l.getStoreId())) storeIds.add(l.getStoreId());
                if (merchantId == null && l.getMerchantId() != null) merchantId = l.getMerchantId();
                BizRole r = BizRole.fromStaffRole(l.getRole());
                roles.add(r);
                // 取权限最高的职务：必须用 rank() 而不是 ordinal()（详见类注释）
                if (maxStaffRole == null || r.rank() > maxStaffRole.rank())
                {
                    maxStaffRole = r;
                }
            }
        }
        String resolvedUserType = fallbackType;
        if (maxStaffRole != null)
        {
            switch (maxStaffRole)
            {
                case OWNER:   resolvedUserType = "owner";   break;
                case MANAGER: resolvedUserType = "manager"; break;
                case STAFF:   resolvedUserType = "staff";   break;
                default: break;
            }
        }
        // 代理商/城市合伙人 叠加身份（user_type=01）
        Long agentId = null;
        if ("01".equals(user.getUserType()))
        {
            roles.add(BizRole.AGENT);
            resolvedUserType = "agent";
            if (agentIdLookup != null)
            {
                try { agentId = agentIdLookup.apply(user.getUserId()); } catch (Exception ignore) { }
            }
        }
        // 平台账号也能登小程序（user_type=00，外出查跨店数据）。
        // 纵深防御：仅当该账号「没有任何商家员工关联」时才认平台身份。
        // 历史上 acceptInvite 曾把扫码入职账号误建成 user_type=00，
        // 若不加 links 判空，这些店员登录后会直接拿到 PLATFORM 角色（可读全平台数据）。
        if ("00".equals(user.getUserType()) && (links == null || links.isEmpty()))
        {
            roles.add(BizRole.PLATFORM);
            resolvedUserType = "platform";
        }
        if (allStores && merchantId != null && storeIdsOfMerchant != null)
        {
            try
            {
                List<Long> all = storeIdsOfMerchant.apply(merchantId);
                if (all != null)
                {
                    for (Long sid : all)
                    {
                        if (sid != null && !storeIds.contains(sid)) storeIds.add(sid);
                    }
                }
            }
            catch (Exception ignore) { }
        }
        LoginMember lm = new LoginMember();
        lm.setAllStores(allStores);
        lm.setUserType(resolvedUserType);
        lm.setRoles(roles);
        lm.setStaffRole(maxStaffRole);
        lm.setStoreId(storeIds.isEmpty() ? null : storeIds.get(0));
        lm.setStoreIds(storeIds);
        lm.setMerchantId(merchantId);
        lm.setAgentId(agentId);
        // 商家员工的 sys_user.user_id 只放 staffUserId，绝不写 memberId
        // （两条自增序列区间重叠，混用会读到同号的别人的会员记录）
        lm.setStaffUserId(user.getUserId());
        lm.setOpenid(user.getOpenid() == null ? "staff:" + user.getUserId() : user.getOpenid());
        return lm;
    }
}
