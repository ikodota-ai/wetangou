package com.ruoyi.biz.controller;

import java.util.Date;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.domain.SysConfig;
import com.ruoyi.system.service.ISysConfigService;

/**
 * 基于 sys_config 的配置页面基类
 *
 * 供「微信配置」「小程序平台配置」等把散落的系统参数收拢到独立页面维护，
 * 避免每个页面重复实现"按key读取、不存在则新增"的逻辑。
 *
 * @author dytuangou
 */
public abstract class BaseSysConfigController extends BaseController
{
    @Autowired
    protected ISysConfigService configService;

    /**
     * 当前页面维护的参数键（key -> 参数名称），保持声明顺序以便前端按序展示
     */
    protected abstract Map<String, String> keyNames();

    /**
     * 新增参数时写入的备注，便于在系统参数列表中辨认来源
     */
    protected abstract String configRemark();

    /**
     * 读取本页面维护的全部参数
     */
    protected Map<String, String> readConfigs()
    {
        Map<String, String> data = new LinkedHashMap<String, String>();
        for (String key : keyNames().keySet())
        {
            data.put(key, configService.selectConfigByKey(key));
        }
        return data;
    }

    /**
     * 保存本页面维护的参数，仅处理请求中出现的键
     */
    protected void writeConfigs(Map<String, String> body)
    {
        String operator = SecurityUtils.getUsername();
        for (Map.Entry<String, String> entry : keyNames().entrySet())
        {
            String key = entry.getKey();
            if (body == null || !body.containsKey(key))
            {
                continue;
            }
            String value = body.get(key);
            saveOne(key, entry.getValue(), value == null ? "" : value.trim(), operator);
        }
    }

    private void saveOne(String key, String name, String value, String operator)
    {
        // 通过key查询是否已存在（selectConfigList为模糊匹配，需再精确过滤）
        SysConfig probe = new SysConfig();
        probe.setConfigKey(key);
        SysConfig current = configService.selectConfigList(probe).stream()
                .filter(c -> key.equals(c.getConfigKey())).findFirst().orElse(null);
        Date now = new Date();
        if (current == null)
        {
            SysConfig config = new SysConfig();
            config.setConfigName(name);
            config.setConfigKey(key);
            config.setConfigValue(value);
            config.setConfigType("N");
            config.setCreateBy(operator);
            config.setCreateTime(now);
            config.setRemark(configRemark());
            configService.insertConfig(config);
        }
        else
        {
            current.setConfigValue(value);
            if (StringUtils.isEmpty(current.getConfigName()))
            {
                current.setConfigName(name);
            }
            current.setUpdateBy(operator);
            current.setUpdateTime(now);
            configService.updateConfig(current);
        }
    }
}
