package com.ruoyi.web.api;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.alibaba.fastjson2.JSONObject;
import com.ruoyi.biz.api.annotation.LoginRequired;
import com.ruoyi.biz.api.annotation.RequireRole;
import com.ruoyi.biz.api.domain.LoginMember;
import com.ruoyi.biz.api.role.BizRole;
import com.ruoyi.biz.api.util.MemberContextHolder;
import com.ruoyi.biz.domain.Agent;
import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.biz.domain.Order;
import com.ruoyi.biz.service.IAgentService;
import com.ruoyi.biz.service.IMerchantService;
import com.ruoyi.biz.service.IOrderService;
import com.ruoyi.common.core.domain.AjaxResult;

/**
 * 代理商 dashboard 接口（AGENT 角色专属；PLATFORM 永远放行）
 *
 * <ul>
 *   <li>GET /api/agent/info — 当前代理商档案</li>
 *   <li>GET /api/agent/merchant/list — 名下商家列表</li>
 *   <li>GET /api/agent/order/list — 名下商家订单流水</li>
 *   <li>GET /api/agent/stats — 名下汇总（商家数/今日订单/今日 GMV）</li>
 * </ul>
 *
 * <p>规则：代理商只能查自己（agentId 从 LoginMember 取），平台账号不受限</p>
 */
@RestController
@RequestMapping("/api/agent")
public class ApiAgentController
{
    @Autowired
    private IAgentService agentService;
    @Autowired
    private IMerchantService merchantService;
    @Autowired
    private IOrderService orderService;

    @LoginRequired
    @RequireRole(BizRole.AGENT)
    @GetMapping("/info")
    public AjaxResult info()
    {
        Long agentId = currentAgentId();
        if (agentId == null) return AjaxResult.error("未绑定代理商档案");
        Agent a = agentService.selectAgentByAgentId(agentId);
        if (a == null) return AjaxResult.error("代理商不存在");
        JSONObject data = new JSONObject();
        data.put("agentId", a.getAgentId());
        data.put("agentNo", a.getAgentNo());
        data.put("agentName", a.getAgentName());
        data.put("region", a.getRegion());
        data.put("contact", a.getContact());
        data.put("phone", a.getPhone());
        data.put("paidAmount", a.getPaidAmount());
        data.put("expireTime", a.getExpireTime());
        data.put("merchantQuota", a.getMerchantQuota());
        data.put("storeQuota", a.getStoreQuota());
        data.put("usedQuota", a.getUsedQuota());
        data.put("usedStoreCount", a.getUsedStoreCount());
        data.put("status", a.getStatus());
        return AjaxResult.success(data);
    }

    @LoginRequired
    @RequireRole(BizRole.AGENT)
    @GetMapping("/merchant/list")
    public AjaxResult merchantList(@RequestParam(required = false) String keyword)
    {
        Long agentId = currentAgentId();
        if (agentId == null) return AjaxResult.error("未绑定代理商档案");
        Merchant q = new Merchant();
        q.setAgentId(agentId);
        if (keyword != null && !keyword.isEmpty()) q.setMerchantName(keyword);
        List<Merchant> list = merchantService.selectMerchantList(q);
        List<JSONObject> rows = new ArrayList<>();
        for (Merchant m : list) {
            if (m.getAgentId() == null || !agentId.equals(m.getAgentId())) continue;
            JSONObject o = new JSONObject();
            o.put("merchantId", m.getMerchantId());
            o.put("merchantName", m.getMerchantName());
            o.put("contact", m.getContact());
            o.put("phone", m.getPhone());
            o.put("status", m.getStatus());
            o.put("createTime", m.getCreateTime());
            rows.add(o);
        }
        JSONObject data = new JSONObject();
        data.put("total", rows.size());
        data.put("rows", rows);
        return AjaxResult.success(data);
    }

    @LoginRequired
    @RequireRole(BizRole.AGENT)
    @GetMapping("/order/list")
    public AjaxResult orderList(@RequestParam(required = false) String status,
                                 @RequestParam(required = false, defaultValue = "50") Integer limit)
    {
        Long agentId = currentAgentId();
        if (agentId == null) return AjaxResult.error("未绑定代理商档案");
        int cap = Math.min(Math.max(limit == null ? 50 : limit, 1), 200);
        // 先取名下商家 id
        Merchant qm = new Merchant();
        qm.setAgentId(agentId);
        List<Merchant> merchants = merchantService.selectMerchantList(qm);
        List<Long> ids = new ArrayList<>();
        for (Merchant m : merchants) {
            if (m.getAgentId() != null && agentId.equals(m.getAgentId())) ids.add(m.getMerchantId());
        }
        if (ids.isEmpty()) {
            JSONObject empty = new JSONObject();
            empty.put("total", 0);
            empty.put("rows", new ArrayList<>());
            return AjaxResult.success(empty);
        }
        Order q = new Order();
        if (status != null && !status.isEmpty()) q.setStatus(status);
        q.getParams().put("merchantIdsIn", ids);
        List<Order> all = orderService.selectOrderList(q);
        List<JSONObject> rows = new ArrayList<>();
        int total = all.size();
        for (int i = 0; i < Math.min(cap, all.size()); i++) {
            Order o = all.get(i);
            JSONObject r = new JSONObject();
            r.put("orderId", o.getOrderId());
            r.put("orderNo", o.getOrderNo());
            r.put("merchantId", o.getMerchantId());
            r.put("storeName", o.getStoreName());
            r.put("productName", o.getProductName());
            r.put("totalAmount", o.getTotalAmount());
            r.put("payAmount", o.getPayAmount());
            r.put("status", o.getStatus());
            r.put("createTime", o.getCreateTime());
            rows.add(r);
        }
        JSONObject data = new JSONObject();
        data.put("total", total);
        data.put("rows", rows);
        return AjaxResult.success(data);
    }

    @LoginRequired
    @RequireRole(BizRole.AGENT)
    @GetMapping("/stats")
    public AjaxResult stats()
    {
        Long agentId = currentAgentId();
        if (agentId == null) return AjaxResult.error("未绑定代理商档案");
        Merchant qm = new Merchant();
        qm.setAgentId(agentId);
        List<Merchant> merchants = merchantService.selectMerchantList(qm);
        int merchantTotal = 0;
        for (Merchant m : merchants) if (m.getAgentId() != null && agentId.equals(m.getAgentId())) merchantTotal++;

        // 今日订单
        List<Long> ids = new ArrayList<>();
        for (Merchant m : merchants) if (m.getAgentId() != null && agentId.equals(m.getAgentId())) ids.add(m.getMerchantId());

        int todayOrders = 0;
        BigDecimal todayGmv = BigDecimal.ZERO;
        if (!ids.isEmpty()) {
            Order q = new Order();
            q.getParams().put("merchantIdsIn", ids);
            List<Order> all = orderService.selectOrderList(q);
            java.util.Calendar cal = java.util.Calendar.getInstance();
            cal.set(java.util.Calendar.HOUR_OF_DAY, 0); cal.set(java.util.Calendar.MINUTE, 0);
            cal.set(java.util.Calendar.SECOND, 0); cal.set(java.util.Calendar.MILLISECOND, 0);
            java.util.Date todayStart = cal.getTime();
            for (Order o : all) {
                java.util.Date ct = o.getCreateTime();
                if (ct == null) continue;
                if (!ct.before(todayStart)) {
                    todayOrders++;
                    BigDecimal pa = o.getPayAmount();
                    if (pa != null) todayGmv = todayGmv.add(pa);
                }
            }
        }

        JSONObject data = new JSONObject();
        data.put("merchantTotal", merchantTotal);
        data.put("todayOrders", todayOrders);
        data.put("todayGmv", todayGmv);
        return AjaxResult.success(data);
    }

    /**
     * 解析当前代理商 ID：代理商从 LoginMember.agentId 取；平台超管（永远放行）从 query ?agentId= 选
     */
    private Long currentAgentId()
    {
        LoginMember me = MemberContextHolder.get();
        if (me == null) return null;
        if (me.getRoles() != null && me.getRoles().contains(BizRole.PLATFORM)) {
            // 平台账号：取第一个名下的代理商（demo 用，实际应支持 query 选）
            Agent q = new Agent();
            List<Agent> list = agentService.selectAgentList(q);
            if (!list.isEmpty()) return list.get(0).getAgentId();
            return null;
        }
        return me.getAgentId();
    }
}
