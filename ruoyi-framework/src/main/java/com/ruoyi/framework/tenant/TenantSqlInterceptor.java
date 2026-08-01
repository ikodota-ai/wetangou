package com.ruoyi.framework.tenant;

import java.sql.Connection;
import java.util.Properties;
import org.apache.ibatis.executor.statement.StatementHandler;
import org.apache.ibatis.mapping.BoundSql;
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
import com.ruoyi.common.utils.TenantContextHolder;

/**
 * 租户SQL拦截器：查询时自动为业务表追加 merchant_id 条件
 *
 * <p>拦截 StatementHandler#prepare，在SQL交给JDBC前完成改写，
 * 这样对 PageHelper 的 count/page 语句同样生效。</p>
 *
 * @author dytuangou
 */
@Intercepts({ @Signature(type = StatementHandler.class, method = "prepare",
        args = { Connection.class, Integer.class }) })
public class TenantSqlInterceptor implements Interceptor
{
    private static final Logger log = LoggerFactory.getLogger(TenantSqlInterceptor.class);

    @Override
    public Object intercept(Invocation invocation) throws Throwable
    {
        if (!TenantContextHolder.needFilter())
        {
            return invocation.proceed();
        }

        StatementHandler statementHandler = (StatementHandler) invocation.getTarget();
        MetaObject metaObject = SystemMetaObject.forObject(statementHandler);
        MappedStatement mappedStatement = (MappedStatement) metaObject.getValue("delegate.mappedStatement");

        // 处理查询与更新/删除；INSERT 的 merchant_id 由实体赋值（TenantEntityHelper）
        SqlCommandType commandType = mappedStatement.getSqlCommandType();
        if (!SqlCommandType.SELECT.equals(commandType)
                && !SqlCommandType.UPDATE.equals(commandType)
                && !SqlCommandType.DELETE.equals(commandType))
        {
            return invocation.proceed();
        }

        if (TenantIgnoreResolver.isIgnored(mappedStatement.getId()))
        {
            return invocation.proceed();
        }

        TenantContext context = TenantContextHolder.get();
        BoundSql boundSql = statementHandler.getBoundSql();
        String originSql = boundSql.getSql();
        String newSql = TenantSqlRewriter.rewrite(originSql, context);

        if (newSql != null && !newSql.equals(originSql))
        {
            SystemMetaObject.forObject(boundSql).setValue("sql", newSql);
            if (log.isDebugEnabled())
            {
                log.debug("[租户过滤] {} 改写后SQL: {}", mappedStatement.getId(), newSql);
            }
        }
        return invocation.proceed();
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
