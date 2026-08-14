package com.ruoyi.web.controller.biz;

import java.util.Calendar;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.biz.service.ICommissionService;
import com.ruoyi.biz.service.ITenantService;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;

/**
 * 代理商佣金概览（admin 端）
 * 对应 doc 下一轮迭代清单 C1：代理商工作台「佣金概览」卡
 * 复用 ICommissionService.sumAgentOverview / sumByMerchantIds
 * 入参：agentId（来自 store.state.user.agentId）
 */
@RestController
@RequestMapping("/biz/agent/commission")
public class BizAgentCommissionController extends BaseController
{
    @Autowired
    private ICommissionService commissionService;

    @Autowired
    private ITenantService tenantService;

    /**
     * 本月佣金概览：总/已结算/待结算 + 名下商户佣金明细
     */
    @PreAuthorize("@ss.hasPermi('biz:agent:commission:summary')")
    @GetMapping("/summary")
    public AjaxResult summary(Long agentId)
    {
        if (agentId == null) {
            return error("代理商ID缺失");
        }
        List<Long> merchantIds = tenantService.getMerchantIdsByAgentId(agentId);
        Calendar cal = Calendar.getInstance();
        cal.set(Calendar.DAY_OF_MONTH, 1);
        cal.set(Calendar.HOUR_OF_DAY, 0);
        cal.set(Calendar.MINUTE, 0);
        cal.set(Calendar.SECOND, 0);
        cal.set(Calendar.MILLISECOND, 0);
        Date begin = cal.getTime();
        Date end = new Date();
        Map<String, Object> overview = commissionService.sumAgentOverview(merchantIds, begin, end);
        List<Map<String, Object>> byMerchant = commissionService.sumByMerchantIds(merchantIds, begin, end);
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("agentId", agentId);
        data.put("merchantCount", merchantIds == null ? 0 : merchantIds.size());
        data.put("beginTime", begin);
        data.put("endTime", end);
        // mapper alias 用 snake_case，service 已把 null 兜成 BigDecimal.ZERO / 0L
        data.put("totalAmount", overview.get("total_amount"));
        data.put("settledAmount", overview.get("settled_amount"));
        data.put("pendingAmount", overview.get("pending_amount"));
        data.put("commissionCount", overview.get("commission_count"));
        data.put("byMerchant", byMerchant);
        return success(data);
    }
}
