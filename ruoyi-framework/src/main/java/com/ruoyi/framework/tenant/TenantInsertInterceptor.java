package com.ruoyi.framework.tenant;

import java.lang.reflect.Method;
import java.util.Properties;
import org.apache.ibatis.executor.Executor;
import org.apache.ibatis.mapping.MappedStatement;
import org.apache.ibatis.mapping.SqlCommandType;
import org.apache.ibatis.plugin.Interceptor;
import org.apache.ibatis.plugin.Intercepts;
import org.apache.ibatis.plugin.Invocation;
import org.apache.ibatis.plugin.Plugin;
import org.apache.ibatis.plugin.Signature;
import org.apache.ibatis.reflection.MetaObject;
import org.apache.ibatis.reflection.SystemMetaObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import com.ruoyi.common.core.domain.model.TenantContext;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.TenantContextHolder;

/**
 * 租户写入拦截器：新增数据时自动补齐 merchant_id
 *
 * <p>业务实体普遍带有 merchantId 属性，新增时用当前租户上下文填充，
 * 避免漏填导致 merchant_id=0 被当成全平台共享数据。</p>
 *
 * <p>商户账号不信任客户端传入的 merchantId，一律强制覆盖为自身商户，
 * 否则伪造参数可向其他租户写入数据；代理商账号则校验目标商户是否在其名下。</p>
 *
 * @author dytuangou
 */
@Intercepts({ @Signature(type = Executor.class, method = "update",
        args = { MappedStatement.class, Object.class }) })
public class TenantInsertInterceptor implements Interceptor
{
    private static final Logger log = LoggerFactory.getLogger(TenantInsertInterceptor.class);

    private static final String PROPERTY_MERCHANT_ID = "merchantId";

    @Override
    public Object intercept(Invocation invocation) throws Throwable
    {
        Object[] args = invocation.getArgs();
        MappedStatement mappedStatement = (MappedStatement) args[0];
        Object parameter = args[1];

        if (!SqlCommandType.INSERT.equals(mappedStatement.getSqlCommandType()) || parameter == null)
        {
            return invocation.proceed();
        }
        // biz_merchant/biz_agent 等平台级表自身带 merchantId 属性，不能当作业务数据处理
        if (TenantIgnoreResolver.isIgnored(mappedStatement.getId()))
        {
            return invocation.proceed();
        }
        if (!TenantContextHolder.needFilter())
        {
            return invocation.proceed();
        }
        fillMerchantId(parameter, TenantContextHolder.get());
        return invocation.proceed();
    }

    /**
     * 为参数对象写入 merchantId
     *
     * <p>商户账号强制覆盖为自身商户；代理商账号未传时无法推定归属，
     * 传了则必须是名下商户。</p>
     */
    private void fillMerchantId(Object parameter, TenantContext context)
    {
        MetaObject metaObject;
        Object current;
        try
        {
            metaObject = SystemMetaObject.forObject(parameter);
            if (!metaObject.hasGetter(PROPERTY_MERCHANT_ID) || !metaObject.hasSetter(PROPERTY_MERCHANT_ID))
            {
                return;
            }
            current = metaObject.getValue(PROPERTY_MERCHANT_ID);
        }
        catch (Exception e)
        {
            log.warn("[租户写入] 读取merchantId失败：{}", e.getMessage());
            return;
        }

        if (context.isMerchant())
        {
            // 不信任客户端传值，一律覆盖为当前商户
            setMerchantId(metaObject, context.getMerchantId());
            return;
        }
        if (context.isAgent())
        {
            if (isEmptyId(current))
            {
                throw new ServiceException("代理商账号新增业务数据需指定所属商户");
            }
            Long target = Long.valueOf(((Number) current).longValue());
            if (!context.getMerchantIds().contains(target))
            {
                throw new ServiceException("无权向非名下商户写入数据");
            }
        }
    }

    /**
     * merchantId 是否为空值（null 或 0）
     */
    private boolean isEmptyId(Object value)
    {
        return !(value instanceof Number) || ((Number) value).longValue() == 0L;
    }

    private void setMerchantId(MetaObject metaObject, Long merchantId)
    {
        try
        {
            metaObject.setValue(PROPERTY_MERCHANT_ID, merchantId);
        }
        catch (Exception e)
        {
            log.warn("[租户写入] 写入merchantId失败：{}", e.getMessage());
        }
    }

    @Override
    public Object plugin(Object target)
    {
        return Plugin.wrap(target, this);
    }

    @Override
    public void setProperties(Properties properties)
    {
    }
}
