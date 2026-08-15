package com.ruoyi.framework.api;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;


/**
 * 小程序C端Web配置：注册会员登录拦截器
 *
 * @author dytuangou
 */
@Configuration
public class ApiWebConfig implements WebMvcConfigurer
{
    @Autowired
    private MemberAuthInterceptor memberAuthInterceptor;
    @Autowired
    private RoleAuthInterceptor roleAuthInterceptor;

    @Override
    public void addInterceptors(InterceptorRegistry registry)
    {
        registry.addInterceptor(memberAuthInterceptor).addPathPatterns("/api/**");
        registry.addInterceptor(roleAuthInterceptor).addPathPatterns("/api/**");
    }
}
