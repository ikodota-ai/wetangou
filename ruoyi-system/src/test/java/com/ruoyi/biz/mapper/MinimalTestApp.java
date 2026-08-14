package com.ruoyi.biz.mapper;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * E5 测试用最小 Spring Boot 入口
 */
@SpringBootApplication
@MapperScan("com.ruoyi.biz.mapper")
public class MinimalTestApp
{
    public static void main(String[] args)
    {
        SpringApplication.run(MinimalTestApp.class, args);
    }
}
