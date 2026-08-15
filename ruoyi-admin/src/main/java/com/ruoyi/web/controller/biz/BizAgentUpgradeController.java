package com.ruoyi.web.controller.biz;

import java.util.Date;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.biz.domain.Agent;
import com.ruoyi.biz.domain.Member;
import com.ruoyi.biz.service.IAgentService;
import com.ruoyi.biz.service.IMemberService;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;

/**
 * admin 端代理商升级入口 (C31)
 *
 * <p>把普通 biz_member 升级为代理商 (user_type=1, agent_id=N)。
 * 对应 /api/distributor/agent/summary 解锁链路 (C26): C26 解锁前端访问,
 * C31 提供 admin 端把账号升级为代理商的入口。</p>
 *
 * <p>端点:
 * <ul>
 *   <li>GET  /biz/agent/upgrade/list - 列已升级代理商 (按 agent_id 聚合)</li>
 *   <li>POST /biz/agent/upgrade      - 升级指定 memberId 为 agentId 对应代理商</li>
 *   <li>POST /biz/agent/upgrade/downgrade/{memberId} - 降级 (user_type=0, agent_id=NULL)</li>
 * </ul>
 *
 * @author dytuangou
 */
@RestController
@RequestMapping("/biz/agent/upgrade")
public class BizAgentUpgradeController extends BaseController
{
    @Autowired
    private IMemberService memberService;

    @Autowired
    private IAgentService agentService;

    /**
     * 升级 member 为代理商: user_type=1, agent_id=agentId
     * 校验: agentId 必须存在且 status=0
     */
    @PreAuthorize("@ss.hasPermi('biz:agent:upgrade:add')")
    @PostMapping
    public AjaxResult upgrade(Long memberId, Long agentId)
    {
        if (memberId == null || agentId == null) {
            return error("memberId 与 agentId 必填");
        }
        Member m = memberService.selectMemberByMemberId(memberId);
        if (m == null) {
            return error("会员不存在: memberId=" + memberId);
        }
        Agent a = agentService.selectAgentByAgentId(agentId);
        if (a == null) {
            return error("代理商不存在: agentId=" + agentId);
        }
        if (!"0".equals(a.getStatus())) {
            return error("代理商已停用: status=" + a.getStatus());
        }
        m.setUserType("1");
        m.setAgentId(agentId);
        m.setUpdateTime(new Date());
        int rows = memberService.updateMember(m);
        return rows > 0 ? success("升级成功: memberId=" + memberId + " agentId=" + agentId) : error("升级失败");
    }

    /**
     * 降级 member: user_type=0, agent_id=NULL
     */
    @PreAuthorize("@ss.hasPermi('biz:agent:upgrade:remove')")
    @PostMapping("/downgrade/{memberId}")
    public AjaxResult downgrade(@PathVariable Long memberId)
    {
        if (memberId == null) {
            return error("memberId 必填");
        }
        Member m = memberService.selectMemberByMemberId(memberId);
        if (m == null) {
            return error("会员不存在: memberId=" + memberId);
        }
        m.setUserType("0");
        m.setAgentId(0L);  // 0 触发 SQL: agent_id = IF(#{agentId} = 0, NULL, #{agentId})
        m.setUpdateTime(new Date());
        int rows = memberService.updateMember(m);
        return rows > 0 ? success("降级成功: memberId=" + memberId) : error("降级失败");
    }
}
