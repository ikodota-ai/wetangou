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
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.biz.domain.CommissionRule;
import com.ruoyi.biz.service.ICommissionRuleService;
import com.ruoyi.common.utils.poi.ExcelUtil;
import com.ruoyi.common.core.page.TableDataInfo;

/**
 * 佣金规则Controller
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@RestController
@RequestMapping("/biz/rule")
public class CommissionRuleController extends BaseController
{
    @Autowired
    private ICommissionRuleService commissionRuleService;

    /**
     * 查询佣金规则列表
     */
    @PreAuthorize("@ss.hasPermi('biz:rule:list')")
    @GetMapping("/list")
    public TableDataInfo list(CommissionRule commissionRule)
    {
        startPage();
        List<CommissionRule> list = commissionRuleService.selectCommissionRuleList(commissionRule);
        return getDataTable(list);
    }

    /**
     * 导出佣金规则列表
     */
    @PreAuthorize("@ss.hasPermi('biz:rule:export')")
    @Log(title = "佣金规则", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, CommissionRule commissionRule)
    {
        List<CommissionRule> list = commissionRuleService.selectCommissionRuleList(commissionRule);
        ExcelUtil<CommissionRule> util = new ExcelUtil<CommissionRule>(CommissionRule.class);
        util.exportExcel(response, list, "佣金规则数据");
    }

    /**
     * 获取佣金规则详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:rule:query')")
    @GetMapping(value = "/{ruleId}")
    public AjaxResult getInfo(@PathVariable("ruleId") Long ruleId)
    {
        return success(commissionRuleService.selectCommissionRuleByRuleId(ruleId));
    }

    /**
     * 新增佣金规则
     */
    @PreAuthorize("@ss.hasPermi('biz:rule:add')")
    @Log(title = "佣金规则", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody CommissionRule commissionRule)
    {
        return toAjax(commissionRuleService.insertCommissionRule(commissionRule));
    }

    /**
     * 修改佣金规则
     */
    @PreAuthorize("@ss.hasPermi('biz:rule:edit')")
    @Log(title = "佣金规则", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody CommissionRule commissionRule)
    {
        return toAjax(commissionRuleService.updateCommissionRule(commissionRule));
    }

    /**
     * 删除佣金规则
     */
    @PreAuthorize("@ss.hasPermi('biz:rule:remove')")
    @Log(title = "佣金规则", businessType = BusinessType.DELETE)
	@DeleteMapping("/{ruleIds}")
    public AjaxResult remove(@PathVariable Long[] ruleIds)
    {
        return toAjax(commissionRuleService.deleteCommissionRuleByRuleIds(ruleIds));
    }
}
