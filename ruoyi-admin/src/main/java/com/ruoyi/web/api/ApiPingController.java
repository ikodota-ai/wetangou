package com.ruoyi.web.api;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.domain.AjaxResult;

/**
 * 健康检查端点
 *
 * <p>小程序启动时用这个端点替代 /captchaImage 探测后端可达性。
 * /captchaImage 需要图片渲染，0.1s 起步；/api/ping 直接返 200，更轻量。
 * 微信真机通过 LAN 访问电脑时，IP 可能换，这个端点能秒级判断。</p>
 *
 * <p>不需鉴权，不读 DB，不写 Redis。</p>
 */
@RestController
@RequestMapping("/api/ping")
public class ApiPingController
{
    @GetMapping
    public AjaxResult ping()
    {
        return AjaxResult.success("pong");
    }
}
