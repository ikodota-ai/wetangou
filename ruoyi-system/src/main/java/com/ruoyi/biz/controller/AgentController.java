package com.ruoyi.biz.controller;

import java.util.List;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.common.utils.poi.ExcelUtil;
import com.ruoyi.biz.domain.Agent;
import com.ruoyi.biz.service.IAgentService;

/**
 * 代理商Controller
 *
 * @author dytuangou
 */
@RestController
@RequestMapping("/biz/agent")
public class AgentController extends BaseController
{
    @Autowired
    private IAgentService agentService;

    /**
     * 查询代理商列表
     */
    @PreAuthorize("@ss.hasPermi('biz:agent:list')")
    @GetMapping("/list")
    public TableDataInfo list(Agent agent)
    {
        startPage();
        List<Agent> list = agentService.selectAgentList(agent);
        return getDataTable(list);
    }

    /**
     * 导出代理商列表
     */
    @PreAuthorize("@ss.hasPermi('biz:agent:export')")
    @Log(title = "代理商", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, Agent agent)
    {
        List<Agent> list = agentService.selectAgentList(agent);
        ExcelUtil<Agent> util = new ExcelUtil<Agent>(Agent.class);
        util.exportExcel(response, list, "代理商数据");
    }

    /**
     * 获取代理商详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:agent:query')")
    @GetMapping(value = "/{agentId}")
    public AjaxResult getInfo(@PathVariable("agentId") Long agentId)
    {
        // E11: 防越权读其他代理商信息（对标 MerchantController.getInfo 的 checkMerchantDataScope）
        agentService.checkAgentDataScope(agentId);
        return success(agentService.selectAgentByAgentId(agentId));
    }

    /**
     * 新增代理商
     */
    @PreAuthorize("@ss.hasPermi('biz:agent:add')")
    @Log(title = "代理商", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody Agent agent)
    {
        return toAjax(agentService.insertAgent(agent));
    }

    /**
     * 修改代理商
     */
    @PreAuthorize("@ss.hasPermi('biz:agent:edit')")
    @Log(title = "代理商", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody Agent agent)
    {
        return toAjax(agentService.updateAgent(agent));
    }

    /**
     * 删除代理商
     */
    @PreAuthorize("@ss.hasPermi('biz:agent:remove')")
    @Log(title = "代理商", businessType = BusinessType.DELETE)
    @DeleteMapping("/{agentIds}")
    public AjaxResult remove(@PathVariable Long[] agentIds)
    {
        return toAjax(agentService.deleteAgentByAgentIds(agentIds));
    }
}
