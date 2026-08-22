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
import com.ruoyi.common.core.page.TableDataInfo;

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

    /**
     * 子品分页列表（admin「子商品管理」独立页），带 productName / groupName，
     * 并按当前登录身份做租户过滤（商户只看自己商品下的子品）。
     */
    @PreAuthorize("@ss.hasAnyPermi('biz:product:list,biz:productSubitem:list')")
    @GetMapping("/list")
    public TableDataInfo list(ProductSubitem query)
    {
        // 子品表本身没有 merchant_id（靠 join biz_product 过滤），
        // 所以不能走 TenantFilterHelper 的 setMerchantId 分支，这里显式写 params.merchantIdsIn。
        applyTenantScope(query);
        startPage();
        return getDataTable(subitemService.selectSubitemList(query));
    }

    /**
     * 把当前登录身份可见的商户范围写入 params.merchantIdsIn（mapper 用它 join biz_product 过滤）。
     * 平台不限；代理商限名下商户（空集合 → -1 即空结果）；商户限自身。
     */
    private void applyTenantScope(ProductSubitem query)
    {
        com.ruoyi.common.core.domain.model.TenantContext ctx = com.ruoyi.common.utils.TenantContextHolder.get();
        if (ctx == null || ctx.isPlatform())
        {
            return;
        }
        if (query.getParams() == null)
        {
            query.setParams(new java.util.HashMap<>());
        }
        if (ctx.isAgent())
        {
            List<Long> ids = ctx.getMerchantIds();
            query.getParams().put("merchantIdsIn",
                                   (ids == null || ids.isEmpty()) ? java.util.Collections.emptyList() : ids);
            return;
        }
        if (ctx.isMerchant())
        {
            query.getParams().put("merchantIdsIn", ctx.getMerchantId());
        }
    }

    // ==================== 商品组 ====================

    @PreAuthorize("@ss.hasAnyPermi('biz:product:list,biz:productSubitem:list')")
    @GetMapping("/groups")
    public AjaxResult groups(@RequestParam("productId") Long productId)
    {
        return success(groupService.selectByProductId(productId));
    }

    @PreAuthorize("@ss.hasAnyPermi('biz:product:query,biz:productSubitem:query')")
    @GetMapping("/group/{groupId}")
    public AjaxResult groupInfo(@PathVariable("groupId") Long groupId)
    {
        return success(groupService.selectById(groupId));
    }

    @Log(title = "商品搭配", businessType = BusinessType.INSERT)
    @PreAuthorize("@ss.hasAnyPermi('biz:product:add,biz:productSubitem:add')")
    @PostMapping("/group")
    public AjaxResult addGroup(@RequestBody ProductSubitemGroup group)
    {
        if (group.getProductId() == null) return error("缺少 productId");
        group.setCreateBy(getUsername());
        return toAjax(groupService.insert(group));
    }

    @Log(title = "商品搭配", businessType = BusinessType.UPDATE)
    @PreAuthorize("@ss.hasAnyPermi('biz:product:edit,biz:productSubitem:edit')")
    @PutMapping("/group")
    public AjaxResult editGroup(@RequestBody ProductSubitemGroup group)
    {
        group.setUpdateBy(getUsername());
        return toAjax(groupService.update(group));
    }

    @Log(title = "商品搭配", businessType = BusinessType.DELETE)
    @PreAuthorize("@ss.hasAnyPermi('biz:product:remove,biz:productSubitem:remove')")
    @DeleteMapping("/group/{groupId}")
    public AjaxResult removeGroup(@PathVariable("groupId") Long groupId)
    {
        groupService.deleteById(groupId);
        return success();
    }

    // ==================== 子品 ====================

    @PreAuthorize("@ss.hasAnyPermi('biz:product:query,biz:productSubitem:query')")
    @GetMapping("/subitem")
    public AjaxResult subitems(@RequestParam("groupId") Long groupId)
    {
        return success(subitemService.selectByGroupId(groupId));
    }

    /**
     * 历史子品名称候选（去重），供「添加子品」输入框下拉筛选复用，避免每次纯手输。
     */
    @PreAuthorize("@ss.hasAnyPermi('biz:product:query,biz:productSubitem:query')")
    @GetMapping("/nameCandidates")
    public AjaxResult nameCandidates(@RequestParam(value = "keyword", required = false) String keyword)
    {
        return success(subitemService.selectNameCandidates(keyword));
    }

    @Log(title = "商品搭配", businessType = BusinessType.INSERT)
    @PreAuthorize("@ss.hasAnyPermi('biz:product:add,biz:productSubitem:add')")
    @PostMapping("/subitem")
    public AjaxResult addSubitem(@RequestBody ProductSubitem subitem)
    {
        if (subitem.getGroupId() == null) return error("缺少 groupId");
        if (subitem.getProductId() == null) return error("缺少 productId");
        subitem.setCreateBy(getUsername());
        return toAjax(subitemService.insert(subitem));
    }

    @Log(title = "商品搭配", businessType = BusinessType.UPDATE)
    @PreAuthorize("@ss.hasAnyPermi('biz:product:edit,biz:productSubitem:edit')")
    @PutMapping("/subitem")
    public AjaxResult editSubitem(@RequestBody ProductSubitem subitem)
    {
        subitem.setUpdateBy(getUsername());
        return toAjax(subitemService.update(subitem));
    }

    @Log(title = "商品搭配", businessType = BusinessType.DELETE)
    @PreAuthorize("@ss.hasAnyPermi('biz:product:remove,biz:productSubitem:remove')")
    @DeleteMapping("/subitem/{subitemId}")
    public AjaxResult removeSubitem(@PathVariable("subitemId") Long subitemId)
    {
        subitemService.deleteById(subitemId);
        return success();
    }
}
