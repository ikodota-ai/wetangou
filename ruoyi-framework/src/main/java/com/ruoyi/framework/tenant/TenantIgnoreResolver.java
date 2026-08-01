package com.ruoyi.framework.tenant;

import java.lang.reflect.Method;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import com.ruoyi.common.annotation.IgnoreTenant;

/**
 * @IgnoreTenant 判定工具
 *
 * <p>租户读写两个拦截器共用：被标注的 Mapper 接口或方法既不追加 merchant_id 查询条件，
 * 也不参与新增时的 merchantId 覆盖，避免误伤 biz_merchant、biz_agent 等平台级表。</p>
 *
 * @author dytuangou
 */
public class TenantIgnoreResolver
{
    /** mappedStatementId -> 是否忽略，避免每次SQL都做反射 */
    private static final Map<String, Boolean> CACHE = new ConcurrentHashMap<String, Boolean>();

    /**
     * Mapper方法或接口是否标注了 @IgnoreTenant
     *
     * @param mappedStatementId 形如 com.ruoyi.biz.mapper.MerchantMapper.insertMerchant
     * @return true表示跳过租户处理
     */
    public static boolean isIgnored(String mappedStatementId)
    {
        if (mappedStatementId == null)
        {
            return false;
        }
        Boolean cached = CACHE.get(mappedStatementId);
        if (cached != null)
        {
            return cached.booleanValue();
        }
        boolean ignored = resolve(mappedStatementId);
        CACHE.put(mappedStatementId, Boolean.valueOf(ignored));
        return ignored;
    }

    private static boolean resolve(String mappedStatementId)
    {
        try
        {
            int lastDot = mappedStatementId.lastIndexOf('.');
            if (lastDot <= 0)
            {
                return false;
            }
            String className = mappedStatementId.substring(0, lastDot);
            String methodName = mappedStatementId.substring(lastDot + 1);
            Class<?> mapperClass = Class.forName(className);
            if (mapperClass.isAnnotationPresent(IgnoreTenant.class))
            {
                return true;
            }
            for (Method method : mapperClass.getDeclaredMethods())
            {
                if (method.getName().equals(methodName) && method.isAnnotationPresent(IgnoreTenant.class))
                {
                    return true;
                }
            }
        }
        catch (ClassNotFoundException e)
        {
            // 动态SQL或非Mapper接口，按需处理
            return false;
        }
        return false;
    }
}
