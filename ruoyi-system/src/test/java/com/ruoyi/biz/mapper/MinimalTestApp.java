package com.ruoyi.biz.mapper;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.Import;
import com.ruoyi.biz.service.impl.AgentServiceImpl;

/**
 * E5/E11 测试用最小 Spring Boot 入口
 *
 * <p>E11 AgentServiceImpl 引入通过 @Import（精确类，避免扫整个 service 包导致连锁 Redis 依赖）。
 * 不复用 RuoYiApplication（避免拉起 Quartz / Redis / 业务 Service）。</p>
 */
@SpringBootApplication
@MapperScan("com.ruoyi.biz.mapper")
@ComponentScan(basePackages = { "com.ruoyi.biz.mapper" })
@Import(AgentServiceImpl.class)
public class MinimalTestApp
{
    public static void main(String[] args)
    {
        SpringApplication.run(MinimalTestApp.class, args);
    }
}
