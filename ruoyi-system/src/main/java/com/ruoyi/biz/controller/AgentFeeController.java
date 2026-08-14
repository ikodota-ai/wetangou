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
import com.ruoyi.biz.tenant.TenantFilterHelper;
import com.ruoyi.biz.domain.AgentFee;
import com.ruoyi.biz.service.IAgentFeeService;

/**
 * 代理商缴费Controller
 *
 * @author dytuangou
 */
@RestController
@RequestMapping("/biz/agentfee")
public class AgentFeeController extends BaseController
{
    @Autowired
    private IAgentFeeService agentFeeService;

    /**
     * 查询代理商缴费列表
     */
    @PreAuthorize("@ss.hasPermi('biz:agentfee:list')")
    @GetMapping("/list")
    public TableDataInfo list(AgentFee agentFee)
    {
        startPage();
        List<AgentFee> list = agentFeeService.selectAgentFeeList(agentFee);
        return getDataTable(list);
    }

    /**
     * 导出代理商缴费列表
     */
    @PreAuthorize("@ss.hasPermi('biz:agentfee:list')")
    @Log(title = "代理商缴费", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, AgentFee agentFee)
    {
        List<AgentFee> list = agentFeeService.selectAgentFeeList(agentFee);
        ExcelUtil<AgentFee> util = new ExcelUtil<AgentFee>(AgentFee.class);
        util.exportExcel(response, list, "代理商缴费数据");
    }

    /**
     * 获取代理商缴费详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:agentfee:query')")
    @GetMapping(value = "/{feeId}")
    public AjaxResult getInfo(@PathVariable("feeId") Long feeId)
    {
        AgentFee agentFee = agentFeeService.selectAgentFeeByFeeId(feeId);
        if (agentFee != null)
        {
            TenantFilterHelper.assertAgentDataScope(agentFee.getAgentId());
        }
        return success(agentFee);
    }

    /**
     * 新增代理商缴费
     */
    @PreAuthorize("@ss.hasPermi('biz:agentfee:add')")
    @Log(title = "代理商缴费", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody AgentFee agentFee)
    {
        return toAjax(agentFeeService.insertAgentFee(agentFee));
    }

    /**
     * 修改代理商缴费
     */
    @PreAuthorize("@ss.hasPermi('biz:agentfee:edit')")
    @Log(title = "代理商缴费", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody AgentFee agentFee)
    {
        return toAjax(agentFeeService.updateAgentFee(agentFee));
    }

    /**
     * 审核缴费单：确认后发放商户额度与延长有效期
     */
    @PreAuthorize("@ss.hasPermi('biz:agentfee:audit')")
    @Log(title = "代理商缴费", businessType = BusinessType.UPDATE)
    @PutMapping("/audit/{feeId}/{status}")
    public AjaxResult audit(@PathVariable("feeId") Long feeId, @PathVariable("status") String status)
    {
        return toAjax(agentFeeService.auditAgentFee(feeId, status));
    }

    /**
     * 删除代理商缴费
     */
    @PreAuthorize("@ss.hasPermi('biz:agentfee:remove')")
    @Log(title = "代理商缴费", businessType = BusinessType.DELETE)
    @DeleteMapping("/{feeIds}")
    public AjaxResult remove(@PathVariable Long[] feeIds)
    {
        return toAjax(agentFeeService.deleteAgentFeeByFeeIds(feeIds));
    }
}
