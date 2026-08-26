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
        if (group == null || group.getGroupId() == null) return error("缺少 groupId");
        AjaxResult bad = checkPickRule(group);
        if (bad != null) return bad;
        group.setUpdateBy(getUsername());
        return toAjax(groupService.update(group));
    }

    /**
     * 校验「几选几」不得超过本组实际单品数。
     *
     * <p>pickRule 统一为 {@code ALL}（全部可选）或 {@code PICK_N}（可选 N 个）。
     * 原先这里完全不校验，前端又是硬编码的 1选1/2选2/3选2 下拉，
     * 于是只有 2 个单品的组也能存成「3选2」—— 这种组没法履约：
     * 顾客界面会显示可挑 3 样，实际只有 2 样可挑，下单流程直接卡死。</p>
     *
     * <p>N 必须 &lt; 单品数：等于单品数就是全选，应该存 ALL 而不是 PICK_N，
     * 两种表示同一件事会让后续统计（顾客实际可享几个）出现两套口径。</p>
     *
     * @return 校验不通过时返回错误 AjaxResult，通过返回 null
     */
    private AjaxResult checkPickRule(ProductSubitemGroup group)
    {
        String rule = group.getPickRule();
        if (rule == null || rule.trim().isEmpty() || "ALL".equals(rule))
        {
            return null;
        }
        if (!rule.startsWith("PICK_"))
        {
            return error("选择规则格式不正确，应为 ALL 或 PICK_N");
        }
        int n;
        try
        {
            n = Integer.parseInt(rule.substring("PICK_".length()));
        }
        catch (NumberFormatException e)
        {
            return error("选择规则格式不正确：" + rule);
        }
        if (n <= 0)
        {
            return error("可选数量必须大于 0");
        }
        int size = subitemService.selectByGroupId(group.getGroupId()).size();
        if (size == 0)
        {
            return error("请先给该商品组添加单品，再设置几选几");
        }
        if (n > size)
        {
            return error("本组只有 " + size + " 个单品，不能设为选 " + n + " 个");
        }
        if (n == size)
        {
            // 等于全部时归一成 ALL，避免同一语义存两种值
            group.setPickRule("ALL");
        }
        return null;
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
        ProductSubitem exist = null;
        try
        {
            exist = subitemService.selectById(subitemId);
        }
        catch (Exception ignore)
        {
            // 查不到不影响删除本身（DELETE 保持幂等）
        }
        subitemService.deleteById(subitemId);
        if (exist != null && exist.getGroupId() != null)
        {
            shrinkPickRule(exist.getGroupId());
        }
        return success();
    }

    /**
     * 删掉单品后把超出范围的「几选几」收回来。
     *
     * <p>场景：一个组有 3 个单品、规则是 PICK_2（3选2），删掉 1 个后只剩 2 个单品，
     * 规则还写着选 2 个 —— 此时"选2"已经等于全选，却仍显示成"限选"，
     * 顾客侧看到的可选数量和实际不符。删到只剩 1 个时更明显。</p>
     *
     * <p>所以删完自动收敛：N &gt;= 剩余单品数就归成 ALL。
     * 不在这里报错阻止删除 —— 用户的意图是删单品，不该被规则挡住，
     * 而且规则本来就是可以事后再调的。</p>
     */
    private void shrinkPickRule(Long groupId)
    {
        ProductSubitemGroup group = groupService.selectById(groupId);
        if (group == null) return;
        String rule = group.getPickRule();
        if (rule == null || !rule.startsWith("PICK_")) return;
        int n;
        try
        {
            n = Integer.parseInt(rule.substring("PICK_".length()));
        }
        catch (NumberFormatException e)
        {
            return;
        }
        int size = subitemService.selectByGroupId(groupId).size();
        if (n >= size)
        {
            group.setPickRule("ALL");
            groupService.update(group);
        }
    }
}
