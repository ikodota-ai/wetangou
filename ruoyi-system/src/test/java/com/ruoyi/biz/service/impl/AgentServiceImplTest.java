package com.ruoyi.biz.service.impl;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.junit.jupiter.api.condition.EnabledIf;
import org.springframework.test.context.TestPropertySource;
import com.ruoyi.common.core.domain.model.TenantContext;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.TenantContextHolder;

/**
 * E11: Agent 数据权限 guard 单测
 *
 * <p>回归目标：AgentServiceImpl.checkAgentDataScope 行为
 * - 平台 / 未登录 / agentId 为空 → 放行
 * - 代理商账号查自己 → 放行
 * - 代理商账号查别人 → 抛 ServiceException
 */
@SpringBootTest(classes = com.ruoyi.biz.mapper.MinimalTestApp.class)
@TestPropertySource(properties = {
    "spring.datasource.url=${TEST_DB_URL:jdbc:mysql://127.0.0.1:3306/ry-vue?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true}",
    "spring.datasource.username=${TEST_DB_USERNAME:root}",
    "spring.datasource.password=${TEST_DB_PASSWORD:133301}",
    "spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver",
    "mybatis.type-aliases-package=com.ruoyi.**.domain",
    "mybatis.mapper-locations=classpath*:mapper/**/*Mapper.xml"
})
@EnabledIf(value = "com.ruoyi.testsupport.TestDb#available",
           disabledReason = "需要真实 MySQL；无库时跳过（CI runner 无 MySQL，且 service container 是 Linux-only）")
@DisplayName("E11: AgentServiceImpl 数据权限 guard")
class AgentServiceImplTest
{
    @Autowired
    private AgentServiceImpl agentService;

    @AfterEach
    void cleanup()
    {
        TenantContextHolder.set(null);
    }

    @Test
    @DisplayName("null context 放行")
    void nullContext_passes()
    {
        TenantContextHolder.set(null);
        Assertions.assertDoesNotThrow(() -> agentService.checkAgentDataScope(1L));
    }

    @Test
    @DisplayName("null agentId 放行")
    void nullAgentId_passes()
    {
        TenantContextHolder.set(TenantContext.ofPlatform());
        Assertions.assertDoesNotThrow(() -> agentService.checkAgentDataScope(null));
    }

    @Test
    @DisplayName("平台账号查任意 agentId 放行")
    void platformContext_passes()
    {
        TenantContextHolder.set(TenantContext.ofPlatform());
        Assertions.assertDoesNotThrow(() -> agentService.checkAgentDataScope(999L));
    }

    @Test
    @DisplayName("代理商查自己放行")
    void agentQuerySelf_passes()
    {
        TenantContextHolder.set(TenantContext.ofAgent(1L, java.util.Collections.emptyList()));
        Assertions.assertDoesNotThrow(() -> agentService.checkAgentDataScope(1L));
    }

    @Test
    @DisplayName("代理商查别人抛 ServiceException（防 E11 越权读）")
    void agentQueryOther_throws()
    {
        TenantContextHolder.set(TenantContext.ofAgent(1L, java.util.Collections.emptyList()));
        ServiceException ex = Assertions.assertThrows(ServiceException.class,
            () -> agentService.checkAgentDataScope(999L));
        Assertions.assertEquals("没有权限访问该代理商数据", ex.getMessage());
    }

    @Test
    @DisplayName("selectAgentByAgentId 内部调 guard：代理商查自己放行")
    void selectAgentByAgentId_self_passes()
    {
        TenantContextHolder.set(TenantContext.ofAgent(1L, java.util.Collections.emptyList()));
        Assertions.assertDoesNotThrow(() -> agentService.selectAgentByAgentId(1L));
    }

    @Test
    @DisplayName("selectAgentByAgentId 内部调 guard：代理商查别人抛 ServiceException")
    void selectAgentByAgentId_other_throws()
    {
        TenantContextHolder.set(TenantContext.ofAgent(1L, java.util.Collections.emptyList()));
        ServiceException ex = Assertions.assertThrows(ServiceException.class,
            () -> agentService.selectAgentByAgentId(999L));
        Assertions.assertEquals("没有权限访问该代理商数据", ex.getMessage());
    }
}
