package com.ruoyi.framework.tenant;

import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import com.ruoyi.common.constant.TenantConstants;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.common.core.domain.model.TenantContext;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.biz.domain.MerchantUser;
import com.ruoyi.biz.mapper.MerchantMapper;
import com.ruoyi.biz.mapper.MerchantUserMapper;

/**
 * 后台账号身份回填：从 biz_merchant_user 反查 userType / agentId / merchantId，
 * 构造 TenantContext 写入 LoginUser，供 JwtAuthenticationTokenFilter 在
 * 每个请求把上下文同步到 TenantContextHolder。
 *
 * <p>userId 在 biz_merchant_user 无记录时回退为「平台」账号（userType=0），
 * 与 TenantConstants.USER_TYPE_PLATFORM 一致，便于存量 sys_user 直接用。</p>
 */
@Component
public class TenantIdentityResolver
{
    private static final Logger log = LoggerFactory.getLogger(TenantIdentityResolver.class);

    @Autowired
    private MerchantUserMapper merchantUserMapper;

    @Autowired
    private MerchantMapper merchantMapper;

    /**
     * 解析并写入 LoginUser.tenantContext
     */
    public void resolveAndApply(LoginUser loginUser)
    {
        if (loginUser == null || loginUser.getUserId() == null)
        {
            return;
        }
        TenantContext ctx = resolve(loginUser.getUserId());
        loginUser.setTenantContext(ctx);
        log.debug("[TenantIdentityResolver] userId={} -> userType={}, agentId={}, merchantId={}",
                loginUser.getUserId(), ctx.getUserType(), ctx.getAgentId(), ctx.getMerchantId());
    }

    public TenantContext resolve(Long userId)
    {
        MerchantUser u = merchantUserMapper.selectMerchantUserByUserId(userId);
        if (u == null)
        {
            // 存量 sys_user 默认归类为平台账号
            return TenantContext.ofPlatform();
        }
        String userType = StringUtils.defaultIfEmpty(u.getUserType(), TenantConstants.USER_TYPE_PLATFORM);
        if (TenantConstants.USER_TYPE_AGENT.equals(userType))
        {
            // 代理商账号：名下商户 ID 集合
            List<Long> merchantIds = merchantMapper.selectMerchantIdsByAgentId(u.getAgentId());
            return TenantContext.ofAgent(u.getAgentId(), merchantIds);
        }
        if (TenantConstants.USER_TYPE_MERCHANT.equals(userType))
        {
            Long merchantId = u.getMerchantId();
            if (merchantId == null || merchantId <= 0L)
            {
                // 配置不全（user_type=2 但 merchant_id 空）→ 降级为无权限。
                // 原先兜底成 DEFAULT_MERCHANT_ID=1，等于漏填配置就能读写商户1的全部数据，
                // 且静默无告警；置 null 更糟——租户过滤会退化成不加 where、看到全平台。
                log.error("[TenantIdentityResolver] userId={} 标记为商户账号但 merchant_id 为空，"
                        + "已降级为无权限。请在 biz_merchant_user 补齐 merchant_id", userId);
                return TenantContext.ofMerchant(TenantConstants.INVALID_MERCHANT_ID);
            }
            return TenantContext.ofMerchant(merchantId);
        }
        return TenantContext.ofPlatform();
    }
}
