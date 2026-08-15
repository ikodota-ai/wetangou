package com.ruoyi.web.api;

import java.math.BigDecimal;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.alibaba.fastjson2.JSONObject;
import com.ruoyi.biz.api.annotation.LoginRequired;
import com.ruoyi.biz.api.annotation.RequireRole;
import com.ruoyi.biz.api.role.BizRole;
import com.ruoyi.biz.domain.Agent;
import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.biz.service.IAgentService;
import com.ruoyi.biz.service.IMerchantService;
import com.ruoyi.biz.service.IMerchantStaffService;
import com.ruoyi.biz.service.IOrderService;
import com.ruoyi.biz.domain.MerchantStaff;
import com.ruoyi.biz.domain.Order;
import com.ruoyi.common.core.domain.AjaxResult;

/**
 * 平台 dashboard 接口（仅 PLATFORM 角色可访问）
 *
 * <p>提供：</p>
 * <ul>
 *   <li>GET /api/platform/merchant/list — 商家列表（支持 agentId 过滤 + scope=SELF_MANAGED）</li>
 *   <li>GET /api/platform/agent/list — 代理商列表</li>
 *   <li>GET /api/platform/stats — 平台汇总（商家数/代理商数/今日订单数）</li>
 * </ul>
 */
@RestController
@RequestMapping("/api/platform")
public class ApiPlatformController
{
    @Autowired
    private IMerchantService merchantService;

    @Autowired
    private IAgentService agentService;

    @Autowired
    private IOrderService orderService;

    @Autowired
    private IMerchantStaffService staffService;

    /**
     * 商家列表（PLATFORM 角色专属）
     * @param agentId 限定该代理商名下商家
     * @param scope SELF_MANAGED 仅自营
     * @param keyword 商家名模糊搜索
     */
    @LoginRequired
    @RequireRole(BizRole.PLATFORM)
    @GetMapping("/merchant/list")
    public AjaxResult merchantList(@RequestParam(required = false) Long agentId,
                                    @RequestParam(required = false) String scope,
                                    @RequestParam(required = false) String keyword)
    {
        Merchant q = new Merchant();
        if (keyword != null && !keyword.isEmpty()) {
            q.setMerchantName(keyword);
        }
        List<Merchant> list = merchantService.selectMerchantList(q);
        // 过滤
        java.util.List<JSONObject> out = new java.util.ArrayList<>();
        for (Merchant m : list) {
            if (agentId != null && agentId > 0) {
                if (m.getAgentId() == null || !agentId.equals(m.getAgentId())) continue;
            } else if ("SELF_MANAGED".equalsIgnoreCase(scope)) {
                if (m.getAgentId() != null && m.getAgentId() > 0) continue;
            }
            JSONObject o = new JSONObject();
            o.put("merchantId", m.getMerchantId());
            o.put("merchantName", m.getMerchantName());
            o.put("agentId", m.getAgentId());
            o.put("status", m.getStatus());
            o.put("createTime", m.getCreateTime());
            out.add(o);
        }
        JSONObject data = new JSONObject();
        data.put("total", out.size());
        data.put("rows", out);
        return AjaxResult.success(data);
    }

    /**
     * 代理商列表
     */
    @LoginRequired
    @RequireRole(BizRole.PLATFORM)
    @GetMapping("/agent/list")
    public AjaxResult agentList(@RequestParam(required = false) String keyword)
    {
        Agent q = new Agent();
        if (keyword != null && !keyword.isEmpty()) {
            q.setAgentName(keyword);
        }
        List<Agent> list = agentService.selectAgentList(q);
        java.util.List<JSONObject> out = new java.util.ArrayList<>();
        for (Agent a : list) {
            JSONObject o = new JSONObject();
            o.put("agentId", a.getAgentId());
            o.put("agentNo", a.getAgentNo());
            o.put("agentName", a.getAgentName());
            o.put("region", a.getRegion());
            o.put("merchantQuota", a.getMerchantQuota());
            o.put("storeQuota", a.getStoreQuota());
            o.put("usedQuota", a.getUsedQuota());
            o.put("status", a.getStatus());
            o.put("createTime", a.getCreateTime());
            out.add(o);
        }
        JSONObject data = new JSONObject();
        data.put("total", out.size());
        data.put("rows", out);
        return AjaxResult.success(data);
    }

    /**
     * 平台汇总统计
     */
    @LoginRequired
    @RequireRole(BizRole.PLATFORM)
    @GetMapping("/stats")
    public AjaxResult platformStats()
    {
        Merchant qm = new Merchant();
        List<Merchant> merchants = merchantService.selectMerchantList(qm);
        int merchantTotal = merchants.size();
        int merchantActive = 0;
        for (Merchant m : merchants) {
            if ("0".equals(m.getStatus())) merchantActive++;
        }
        Agent qa = new Agent();
        List<Agent> agents = agentService.selectAgentList(qa);
        int agentTotal = agents.size();
        int agentActive = 0;
        for (Agent a : agents) {
            if ("0".equals(a.getStatus())) agentActive++;
        }
        JSONObject data = new JSONObject();
        data.put("merchantTotal", merchantTotal);
        data.put("merchantActive", merchantActive);
        data.put("agentTotal", agentTotal);
        data.put("agentActive", agentActive);
        return AjaxResult.success(data);
    }

    /**
     * 平台订单流水（按 agentId 或 scope=SELF_MANAGED 限定商家范围）
     * @param agentId 限定该代理商名下商家
     * @param scope SELF_MANAGED 仅自营
     * @param status 订单状态过滤
     * @param limit 默认 50，最大 200
     */
    @LoginRequired
    @RequireRole(BizRole.PLATFORM)
    @GetMapping("/order/list")
    public AjaxResult orderList(@RequestParam(required = false) Long agentId,
                                @RequestParam(required = false) String scope,
                                @RequestParam(required = false) String status,
                                @RequestParam(required = false, defaultValue = "50") Integer limit)
    {
        int cap = Math.min(Math.max(limit == null ? 50 : limit, 1), 200);
        Order q = new Order();
        if (status != null && !status.isEmpty()) {
            q.setStatus(status);
        }
        // 收集限定商家 id
        Merchant qm = new Merchant();
        if (agentId != null && agentId > 0) {
            qm.setAgentId(agentId);
        }
        List<Merchant> merchants = merchantService.selectMerchantList(qm);
        java.util.List<Long> ids = new java.util.ArrayList<>();
        for (Merchant m : merchants) {
            if ("SELF_MANAGED".equalsIgnoreCase(scope)) {
                if (m.getAgentId() != null && m.getAgentId() > 0) continue;
            }
            ids.add(m.getMerchantId());
        }
        if (ids.isEmpty()) {
            JSONObject empty = new JSONObject();
            empty.put("total", 0);
            empty.put("rows", new java.util.ArrayList<>());
            return AjaxResult.success(empty);
        }
        q.getParams().put("merchantIdsIn", ids);
        q.getParams().put("beginTime", null);
        java.util.List<Order> all = orderService.selectOrderList(q);
        java.util.List<JSONObject> rows = new java.util.ArrayList<>();
        int total = all.size();
        for (int i = 0; i < Math.min(cap, all.size()); i++) {
            Order o = all.get(i);
            JSONObject r = new JSONObject();
            r.put("orderId", o.getOrderId());
            r.put("orderNo", o.getOrderNo());
            r.put("merchantId", o.getMerchantId());
            r.put("storeId", o.getStoreId());
            r.put("storeName", o.getStoreName());
            r.put("memberId", o.getMemberId());
            r.put("memberName", o.getMemberName());
            r.put("productId", o.getProductId());
            r.put("productName", o.getProductName());
            r.put("totalAmount", o.getTotalAmount());
            r.put("payAmount", o.getPayAmount());
            r.put("status", o.getStatus());
            r.put("payTime", o.getPayTime());
            r.put("createTime", o.getCreateTime());
            rows.add(r);
        }
        JSONObject data = new JSONObject();
        data.put("total", total);
        data.put("rows", rows);
        return AjaxResult.success(data);
    }

    /**
     * 平台员工总览（按 agentId / merchantId 过滤）
     * 限制返回条数，避免全表直出
     */
    @LoginRequired
    @RequireRole(BizRole.PLATFORM)
    @GetMapping("/staff/list")
    public AjaxResult staffList(@RequestParam(required = false) Long agentId,
                                @RequestParam(required = false) Long merchantId,
                                @RequestParam(required = false) String role,
                                @RequestParam(required = false, defaultValue = "100") Integer limit)
    {
        int cap = Math.min(Math.max(limit == null ? 100 : limit, 1), 500);
        java.util.List<Merchant> merchants;
        if (agentId != null && agentId > 0) {
            Merchant qm = new Merchant();
            qm.setAgentId(agentId);
            merchants = merchantService.selectMerchantList(qm);
        } else {
            merchants = merchantService.selectMerchantList(new Merchant());
        }
        java.util.Map<Long, Merchant> mMap = new java.util.HashMap<>();
        for (Merchant m : merchants) mMap.put(m.getMerchantId(), m);

        java.util.List<JSONObject> rows = new java.util.ArrayList<>();
        int total = 0;
        for (Merchant m : merchants) {
            if (merchantId != null && merchantId > 0 && !merchantId.equals(m.getMerchantId())) continue;
            MerchantStaff qs = new MerchantStaff();
            qs.setMerchantId(m.getMerchantId());
            if (role != null && !role.isEmpty()) qs.setRole(role);
            List<MerchantStaff> staffList = staffService.selectList(qs);
            for (MerchantStaff s : staffList) {
                if (rows.size() >= cap) break;
                JSONObject r = new JSONObject();
                r.put("id", s.getId());
                r.put("merchantId", s.getMerchantId());
                r.put("merchantName", m.getMerchantName());
                r.put("userId", s.getUserId());
                r.put("nickName", s.getNickName());
                r.put("phone", s.getPhone());
                r.put("role", s.getRole());
                r.put("status", s.getStatus());
                r.put("createTime", s.getCreateTime());
                rows.add(r);
                total++;
            }
            if (rows.size() >= cap) break;
        }
        JSONObject data = new JSONObject();
        data.put("total", total);
        data.put("rows", rows);
        return AjaxResult.success(data);
    }
}

