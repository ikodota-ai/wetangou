package com.ruoyi.biz.tenant;

import com.ruoyi.common.core.domain.model.TenantContext;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.TenantContextHolder;

/**
 * 业务表租户过滤辅助工具（A1 防跨租户泄漏）
 *
 * <p>使用场景：所有 /biz/* Controller 的 list/export 入口在调用 Service 之前
 * 必须调 {@link #apply(Object, java.util.function.BiConsumer, java.util.function.BiConsumer)}，
 * 强制按当前登录用户身份（平台/代理商/商户）设置 merchantId / merchantIdsIn 过滤条件。</p>
 *
 * <p>行为：
 * <ul>
 *   <li>平台账号（userType=0）：不强制，覆盖全平台</li>
 *   <li>代理商账号（userType=1）：强制限定到名下商户集合；空集合 → 强制空集（1=0）</li>
 *   <li>商户账号（userType=2）：强制按 token merchantId；前端若传不同 merchantId → 500 拒</li>
 * </ul></p>
 *
 * <p>配合 mapper XML 的 params.merchantIdsIn 过滤使用：
 * <pre>
 *   &lt;if test="params != null and params.merchantIdsIn != null"&gt;
 *       &lt;choose&gt;
 *           &lt;when test="params.merchantIdsIn instanceof java.util.List"&gt;
 *               &lt;if test="params.merchantIdsIn.size() &gt; 0"&gt; and merchant_id in
 *                   &lt;foreach collection="params.merchantIdsIn" item="mid" open="(" close=")" separator=","&gt;#{mid}&lt;/foreach&gt;
 *               &lt;/if&gt;
 *               &lt;if test="params.merchantIdsIn.size() == 0"&gt; and 1=0 &lt;/if&gt;
 *           &lt;/when&gt;
 *           &lt;otherwise&gt; and merchant_id = #{params.merchantIdsIn}&lt;/otherwise&gt;
 *       &lt;/choose&gt;
 *   &lt;/if&gt;
 * </pre>
 * </p>
 *
 * @author dytuangou
 */
public class TenantFilterHelper
{
    /**
     * 把租户过滤条件写入 query 实体
     *
     * @param query            业务查询实体（必须支持 setMerchantId 和 getParams().put）
     * @param setMerchantId    setMerchantId setter
     * @param getMerchantId    getMerchantId getter（用于越权检查）
     * @param paramsSetter     把值塞到 query.getParams() 的 BiConsumer；接受 (key, value) 两个 String
     * @param <T>              业务实体类型
     */
    public static <T> void apply(T query,
                                  java.util.function.BiConsumer<T, Long> setMerchantId,
                                  java.util.function.Function<T, Long> getMerchantId,
                                  TenantParamsSetter paramsSetter)
    {
        TenantContext ctx = TenantContextHolder.get();
        if (ctx == null || ctx.isPlatform()) {
            return;
        }
        if (ctx.isAgent()) {
            java.util.List<Long> ids = ctx.getMerchantIds();
            if (ids == null || ids.isEmpty()) {
                paramsSetter.set("merchantIdsIn", "-1");
                return;
            }
            paramsSetter.set("merchantIdsIn", ids);
            return;
        }
        if (ctx.isMerchant()) {
            Long mid = ctx.getMerchantId();
            Long currentMid = getMerchantId.apply(query);
            if (currentMid != null && !currentMid.equals(mid)) {
                throw new ServiceException("无权查询其他商户的数据");
            }
            setMerchantId.accept(query, mid);
        }
    }

    /**
     * 把租户过滤条件写入 query 实体（简化版，假定实体有 setMerchantId/getMerchantId/getParams）
     *
     * <p>实体必须继承 {@link com.ruoyi.common.core.domain.BaseEntity} 以提供 getParams()，
     * 且有 setMerchantId(Long)/getMerchantId()。</p>
     */
    public static void apply(com.ruoyi.common.core.domain.BaseEntity query,
                              java.util.function.BiConsumer<com.ruoyi.common.core.domain.BaseEntity, Long> setMerchantId,
                              java.util.function.Function<com.ruoyi.common.core.domain.BaseEntity, Long> getMerchantId)
    {
        apply(query, setMerchantId, getMerchantId,
              (key, value) -> {
                  if (query.getParams() == null) {
                      query.setParams(new java.util.HashMap<>());
                  }
                  query.getParams().put(key, value);
              });
    }

    /** params.put 函数式接口（避免 lambda 套娃） */
    @FunctionalInterface
    public interface TenantParamsSetter
    {
        void set(String key, Object value);
    }

    /**
     * E13: 显式断言当前账号可访问该 merchantId 资源（用于 GET /{id} 端点）
     * 与 apply 区别：apply 用于 list 改写 SQL；assertDataScope 用于单条读 — 直接抛 403 让客户端明确无权限
     *
     * <p>行为：
     * <ul>
     *   <li>平台账号 / 未登录 / merchantId 为空 → 放行</li>
     *   <li>代理商账号：merchantId 在名下 merchantIds 集合内 → 放行；否则抛 ServiceException</li>
     *   <li>商户账号：merchantId == context.merchantId → 放行；否则抛 ServiceException</li>
     * </ul>
     * </p>
     */
    public static void assertDataScope(Long merchantId)
    {
        TenantContext ctx = TenantContextHolder.get();
        if (ctx == null || ctx.isPlatform() || merchantId == null)
        {
            return;
        }
        if (ctx.isAgent())
        {
            java.util.List<Long> ids = ctx.getMerchantIds();
            if (ids == null || !ids.contains(merchantId))
            {
                throw new ServiceException("没有权限访问该资源");
            }
            return;
        }
        if (ctx.isMerchant())
        {
            if (!merchantId.equals(ctx.getMerchantId()))
            {
                throw new ServiceException("没有权限访问该资源");
            }
        }
    }

    /**
     * E15: 显式断言当前账号可访问该 agentId 资源（代理商维度）
     *   - 平台 / 未登录 / agentId 为空 → 放行
     *   - agent: agentId == ctx.agentId → 放行，否则抛
     *   - merchant: 抛（merchant 不应能查代理商数据）
     */
    public static void assertAgentDataScope(Long agentId)
    {
        TenantContext ctx = TenantContextHolder.get();
        if (ctx == null || ctx.isPlatform() || agentId == null)
        {
            return;
        }
        if (ctx.isAgent())
        {
            if (!agentId.equals(ctx.getAgentId()))
            {
                throw new ServiceException("没有权限访问该代理商数据");
            }
            return;
        }
        if (ctx.isMerchant())
        {
            throw new ServiceException("没有权限访问该代理商数据");
        }
    }
}
