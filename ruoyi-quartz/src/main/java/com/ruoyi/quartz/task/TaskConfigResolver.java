package com.ruoyi.quartz.task;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Component;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.service.ISysConfigService;

/**
 * 定时任务的参数读取器
 *
 * <p>为什么不让每个 task 各自硬编码阈值：超时分钟数、日志保留天数这类值
 * 运营会想调（大促时把待付超时放宽到 60 分钟、排障时把日志多留几天），
 * 硬编码就得改代码重新发版。统一走 sys_config，后台「参数设置」页可改。</p>
 *
 * <p>取不到 / 配错（非数字、负数）时一律回落到默认值并告警 —— 参数配错
 * 不该让整个定时任务炸掉，那样超时单会一直积压。</p>
 *
 * @author dytuangou
 */
@Component
public class TaskConfigResolver
{
    private static final Logger log = LoggerFactory.getLogger(TaskConfigResolver.class);

    /**
     * @Lazy：sysConfigService 在 ruoyi-system，而 quartz 的 bean 由
     * ScheduleUtils 在容器启动早期触发，直接注入会拉长启动期的依赖链
     * （BookingServiceImpl 注入同一个 service 时也是这么处理的）
     */
    @Autowired
    @Lazy
    private ISysConfigService sysConfigService;

    /**
     * 读一个正整数参数
     *
     * @param key          sys_config.config_key
     * @param defaultValue 未配置或配置非法时的兜底
     * @return 参数值，恒 &gt; 0
     */
    public int getPositiveInt(String key, int defaultValue)
    {
        try
        {
            String value = sysConfigService.selectConfigByKey(key);
            if (StringUtils.isNotEmpty(value))
            {
                int parsed = Integer.parseInt(value.trim());
                if (parsed > 0)
                {
                    return parsed;
                }
                log.warn("[task] 参数 {} = {} 不是正整数，回落默认值 {}", key, value, defaultValue);
            }
        }
        catch (Exception e)
        {
            log.warn("[task] 读取参数 {} 失败，回落默认值 {}：{}", key, defaultValue, e.getMessage());
        }
        return defaultValue;
    }
}
