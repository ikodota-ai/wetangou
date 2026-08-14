package com.ruoyi.biz.mapper;

import java.util.Collections;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;

/**
 * E5: Commission 跨租户 guard 单测
 *
 * <p>回归目标：C1 端点修复 commit `7a0299d4` —— 当 agentId 名下无商户时，
 * getMerchantIdsByAgentId 返空 List，sumByMerchantIds 收到空 list 时
 * 必须返 0 行（不能走 `IN ()` 语法错误，也不能漏掉 `merchantIdsEmpty=1=0` guard
 * 误返全表数据）。</p>
 *
 * <p>用 {@code @SpringBootTest(classes = MinimalTestApp)} 走最小化上下文（不引 RuoYiApplication）
 * 避免拉起 Quartz / Redis / 业务 Service。xml 自动从 mapper 全局路径加载。</p>
 */
@SpringBootTest(classes = MinimalTestApp.class)
@TestPropertySource(properties = {
    "spring.datasource.url=jdbc:mysql://127.0.0.1:3306/ry-vue?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true",
    "spring.datasource.username=root",
    "spring.datasource.password=133301",
    "spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver",
    "mybatis.type-aliases-package=com.ruoyi.**.domain",
    "mybatis.mapper-locations=classpath*:mapper/**/*Mapper.xml",
})
@DisplayName("E5: CommissionMapper 跨租户 guard")
class CommissionMapperTest
{
    @Autowired
    private CommissionMapper commissionMapper;

    @Test
    @DisplayName("空 merchantIds 必须返 0 行（防 7a0299d4 类跨租户泄漏）")
    void sumByMerchantIds_emptyList_returnsZeroRows()
    {
        Map<String, Object> params = new HashMap<>();
        params.put("merchantIds", Collections.emptyList());
        params.put("merchantIdsEmpty", true);
        params.put("beginTime", new Date(0));
        params.put("endTime", new Date());

        List<Map<String, Object>> rows = commissionMapper.sumByMerchantIds(params);

        Assertions.assertNotNull(rows, "空 list 入参应返非 null");
        Assertions.assertEquals(0, rows.size(),
            "空 merchantIds 必须返 0 行（merchantIdsEmpty guard 触发 1=0）；如返 >0 行则跨租户泄漏");
    }

    @Test
    @DisplayName("null merchantIds 必须返 0 行（防 NPE + 跨租户泄漏）")
    void sumByMerchantIds_nullList_returnsZeroRows()
    {
        Map<String, Object> params = new HashMap<>();
        params.put("merchantIds", null);
        params.put("merchantIdsEmpty", true);
        params.put("beginTime", new Date(0));
        params.put("endTime", new Date());

        List<Map<String, Object>> rows = commissionMapper.sumByMerchantIds(params);

        Assertions.assertNotNull(rows, "null 入参应返非 null");
        Assertions.assertEquals(0, rows.size(),
            "null merchantIds 必须返 0 行（merchantIdsEmpty guard）");
    }

    @Test
    @DisplayName("sumAgentOverview 在空 merchantIds 下也返 0 行（覆盖同源 bug）")
    void sumAgentOverview_emptyList_returnsZeroRows()
    {
        Map<String, Object> params = new HashMap<>();
        params.put("merchantIds", Collections.emptyList());
        params.put("merchantIdsEmpty", true);
        params.put("beginTime", new Date(0));
        params.put("endTime", new Date());

        Map<String, Object> row = commissionMapper.sumAgentOverview(params);

        Assertions.assertNotNull(row, "空 list 入参应返非 null map");
        Object total = row.get("totalAmount");
        if (total != null)
        {
            Assertions.assertEquals(0, new java.math.BigDecimal(total.toString()).compareTo(java.math.BigDecimal.ZERO),
                "空 merchantIds 下 totalAmount 必须为 0");
        }
    }
}
