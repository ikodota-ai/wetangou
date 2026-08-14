package com.ruoyi.web.controller.biz;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.biz.domain.ProductSubitem;
import com.ruoyi.biz.domain.ProductSubitemGroup;
import com.ruoyi.biz.service.IProductSubitemGroupService;
import com.ruoyi.biz.service.IProductSubitemService;

/**
 * 商品搭配管理（团购套餐 / 组合券包 用）
 *
 * <p>一对多嵌套：商品 → 多个商品组 → 每个组多个子品。
 * 一个商品可以是 GROUPON（多组，N 选 N 全部可享）或 COMBO（按 pick_rule N 选 M）。</p>
 */
@RestController
@RequestMapping("/biz/productSubitem")
public class BizProductSubitemController extends BaseController
{
    @Autowired
    private IProductSubitemGroupService groupService;

    @Autowired
    private IProductSubitemService subitemService;

    // ==================== 商品组 ====================

    @PreAuthorize("@ss.hasPermi('biz:product:list')")
    @GetMapping("/groups")
    public AjaxResult groups(@RequestParam("productId") Long productId)
    {
        return success(groupService.selectByProductId(productId));
    }

    @PreAuthorize("@ss.hasPermi('biz:product:query')")
    @GetMapping("/group/{groupId}")
    public AjaxResult groupInfo(@PathVariable("groupId") Long groupId)
    {
        return success(groupService.selectById(groupId));
    }

    @Log(title = "商品搭配", businessType = BusinessType.INSERT)
    @PreAuthorize("@ss.hasPermi('biz:product:add')")
    @PostMapping("/group")
    public AjaxResult addGroup(@RequestBody ProductSubitemGroup group)
    {
        if (group.getProductId() == null) return error("缺少 productId");
        group.setCreateBy(getUsername());
        return toAjax(groupService.insert(group));
    }

    @Log(title = "商品搭配", businessType = BusinessType.UPDATE)
    @PreAuthorize("@ss.hasPermi('biz:product:edit')")
    @PutMapping("/group")
    public AjaxResult editGroup(@RequestBody ProductSubitemGroup group)
    {
        group.setUpdateBy(getUsername());
        return toAjax(groupService.update(group));
    }

    @Log(title = "商品搭配", businessType = BusinessType.DELETE)
    @PreAuthorize("@ss.hasPermi('biz:product:remove')")
    @DeleteMapping("/group/{groupId}")
    public AjaxResult removeGroup(@PathVariable("groupId") Long groupId)
    {
        groupService.deleteById(groupId);
        return success();
    }

    // ==================== 子品 ====================

    @PreAuthorize("@ss.hasPermi('biz:product:query')")
    @GetMapping("/subitem")
    public AjaxResult subitems(@RequestParam("groupId") Long groupId)
    {
        return success(subitemService.selectByGroupId(groupId));
    }

    @Log(title = "商品搭配", businessType = BusinessType.INSERT)
    @PreAuthorize("@ss.hasPermi('biz:product:add')")
    @PostMapping("/subitem")
    public AjaxResult addSubitem(@RequestBody ProductSubitem subitem)
    {
        if (subitem.getGroupId() == null) return error("缺少 groupId");
        if (subitem.getProductId() == null) return error("缺少 productId");
        subitem.setCreateBy(getUsername());
        return toAjax(subitemService.insert(subitem));
    }

    @Log(title = "商品搭配", businessType = BusinessType.UPDATE)
    @PreAuthorize("@ss.hasPermi('biz:product:edit')")
    @PutMapping("/subitem")
    public AjaxResult editSubitem(@RequestBody ProductSubitem subitem)
    {
        subitem.setUpdateBy(getUsername());
        return toAjax(subitemService.update(subitem));
    }

    @Log(title = "商品搭配", businessType = BusinessType.DELETE)
    @PreAuthorize("@ss.hasPermi('biz:product:remove')")
    @DeleteMapping("/subitem/{subitemId}")
    public AjaxResult removeSubitem(@PathVariable("subitemId") Long subitemId)
    {
        subitemService.deleteById(subitemId);
        return success();
    }
}
