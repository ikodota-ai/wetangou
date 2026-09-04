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
    private static final org.slf4j.Logger log =
            org.slf4j.LoggerFactory.getLogger(StaffLoginMemberBuilder.class);

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
        return build(user, links, fallbackType, agentIdLookup, storeIdsOfMerchant, null);
    }

    /**
     * 同上，额外校验员工关联指向的门店当前是否仍属于该关联声明的商户。
     *
     * <p>为什么必须校验：{@code biz_merchant_staff} 同时存了 merchant_id 和 store_id 两份归属，
     * 而 {@code biz_store.merchant_id} 可以被后台单独改掉（把门店转给别的商户），两张表之间
     * 没有任何外键或联动。一旦门店被转走，员工关联就变成「声明属于商户 A，但指向的门店已经
     * 属于商户 B」的脏数据，而登录时只按 user_id 取 store_id、从不回查门店真实归属，
     * 于是这份脏数据被原封不动写进 token。</p>
     *
     * <p>后果不是登录报错，而是**延迟到建品才炸**：商家端「适用门店」下拉用的就是 token 里的
     * storeIds，商家勾上它保存，{@code ProductServiceImpl.assertStoresBelongToMerchant} 回查
     * biz_store 一比对就抛「门店 X 不属于该商家，不能作为本商品的适用门店」——
     * 报错指向商品和门店，而真正的病根在员工关联表，排查方向被完全带偏。
     * 老板账号同样中招，看起来就像「老板没有权限建品」。</p>
     *
     * <p>因此在登录这一步就把对不上的门店剔掉并打 error 日志：宁可让商家端显示
     * 「当前账号未绑定门店」（真实状态，且提示明确），也不要把脏数据带到下游。</p>
     *
     * @param storeMerchantOf 按 storeId 查其当前所属 merchantId（门店不存在返 null）；为 null 时不校验
     */
    public static LoginMember build(SysUser user, List<MerchantStaff> links, String fallbackType,
                                    java.util.function.Function<Long, Long> agentIdLookup,
                                    java.util.function.Function<Long, List<Long>> storeIdsOfMerchant,
                                    java.util.function.Function<Long, Long> storeMerchantOf)
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
                else if (l.getStoreId() != null && !storeIds.contains(l.getStoreId())
                        && storeStillBelongs(l, storeMerchantOf))
                {
                    storeIds.add(l.getStoreId());
                }
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

    /**
     * 该员工关联指向的门店是否仍属于关联声明的商户。
     *
     * <p>放行的两种情况都是「无从判断」而非「已验证通过」：没提供查询函数（老调用方），
     * 或关联本身没写 merchant_id。真正要拦的是「两边都有值且不相等」，以及「门店已被删除」。</p>
     */
    private static boolean storeStillBelongs(MerchantStaff link,
                                             java.util.function.Function<Long, Long> storeMerchantOf)
    {
        if (storeMerchantOf == null || link == null || link.getMerchantId() == null)
        {
            return true;
        }
        Long storeId = link.getStoreId();
        Long actual;
        try
        {
            actual = storeMerchantOf.apply(storeId);
        }
        catch (Exception e)
        {
            // 查询本身失败不能顺带把人的门店权限清空（比如 DB 抖动），按放行处理
            log.warn("[StaffLogin] 校验门店归属失败 storeId={}，本次放行", storeId, e);
            return true;
        }
        if (actual == null)
        {
            log.error("[StaffLogin] 员工关联指向的门店不存在，已从登录门店集合剔除："
                    + "userId={} storeId={}。请清理 biz_merchant_staff 中的失效关联",
                    link.getUserId(), storeId);
            return false;
        }
        if (!link.getMerchantId().equals(actual))
        {
            log.error("[StaffLogin] 员工关联与门店归属不一致，已从登录门店集合剔除："
                    + "userId={} storeId={} 关联声明 merchantId={} 但门店实际属于 merchantId={}。"
                    + "该脏数据会让商家端建品报「门店不属于该商家」，请修正 biz_store.merchant_id "
                    + "或 biz_merchant_staff 中的这条关联",
                    link.getUserId(), storeId, link.getMerchantId(), actual);
            return false;
        }
        return true;
    }
}
