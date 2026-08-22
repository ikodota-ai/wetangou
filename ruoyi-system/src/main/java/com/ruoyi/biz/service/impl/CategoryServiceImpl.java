package com.ruoyi.biz.service.impl;

import java.util.List;
import com.ruoyi.common.utils.DateUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.mapper.CategoryMapper;
import com.ruoyi.biz.domain.Category;
import com.ruoyi.biz.service.ICategoryService;

/**
 * 商品分类Service业务层处理
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@Service
public class CategoryServiceImpl implements ICategoryService 
{
    @Autowired
    private CategoryMapper categoryMapper;

    /**
     * 查询商品分类
     * 
     * @param categoryId 商品分类主键
     * @return 商品分类
     */
    @Override
    public Category selectCategoryByCategoryId(Long categoryId)
    {
        return categoryMapper.selectCategoryByCategoryId(categoryId);
    }

    /**
     * 查询商品分类列表
     * 
     * @param category 商品分类
     * @return 商品分类
     */
    @Override
    public List<Category> selectCategoryList(Category category)
    {
        return categoryMapper.selectCategoryList(category);
    }

    /**
     * 查询商品品类树：一次查全量再按 parent_id 在内存里组装 children。
     *
     * <p>品类总量小（平台级 ~100 行），一次全量 + 内存组装比递归 SQL 简单可靠。
     * 只取 status=0；parent_id 为 null 一并当顶级处理（历史脏数据兜底，
     * 避免整棵子树因为父节点找不到而在前端级联里彻底消失）。</p>
     */
    @Override
    public List<Category> selectCategoryTree(Category category)
    {
        Category query = (category == null) ? new Category() : category;
        query.setStatus("0");
        query.setMerchantId(null);
        List<Category> all = new java.util.ArrayList<>(categoryMapper.selectCategoryList(query));

        // 租户可见范围：平台公共品类（merchant_id=0）始终可见，
        // 再加上自己的私有品类；别家商户的私有品类必须排除。
        com.ruoyi.common.core.domain.model.TenantContext ctx = com.ruoyi.common.utils.TenantContextHolder.get();
        if (ctx != null && !ctx.isPlatform())
        {
            final java.util.Set<Long> visible = new java.util.HashSet<>();
            visible.add(0L);
            if (ctx.isMerchant() && ctx.getMerchantId() != null)
            {
                visible.add(ctx.getMerchantId());
            }
            if (ctx.isAgent() && ctx.getMerchantIds() != null)
            {
                visible.addAll(ctx.getMerchantIds());
            }
            all.removeIf(c -> c.getMerchantId() != null && !visible.contains(c.getMerchantId()));
        }

        java.util.Map<Long, Category> byId = new java.util.LinkedHashMap<>();
        for (Category c : all)
        {
            c.setChildren(null);
            byId.put(c.getCategoryId(), c);
        }

        List<Category> roots = new java.util.ArrayList<>();
        for (Category c : all)
        {
            Long pid = c.getParentId();
            Category parent = (pid == null || pid == 0L) ? null : byId.get(pid);
            if (parent == null)
            {
                // 顶级，或父节点被停用/删除（挂到顶层而不是丢弃）
                roots.add(c);
                continue;
            }
            if (parent.getChildren() == null)
            {
                parent.setChildren(new java.util.ArrayList<>());
            }
            parent.getChildren().add(c);
        }
        return roots;
    }

    /**
     * 新增商品分类
     * 
     * @param category 商品分类
     * @return 结果
     */
    @Override
    public int insertCategory(Category category)
    {
        category.setCreateTime(DateUtils.getNowDate());
        return categoryMapper.insertCategory(category);
    }

    /**
     * 修改商品分类
     * 
     * @param category 商品分类
     * @return 结果
     */
    @Override
    public int updateCategory(Category category)
    {
        category.setUpdateTime(DateUtils.getNowDate());
        return categoryMapper.updateCategory(category);
    }

    /**
     * 批量删除商品分类
     * 
     * @param categoryIds 需要删除的商品分类主键
     * @return 结果
     */
    @Override
    public int deleteCategoryByCategoryIds(Long[] categoryIds)
    {
        return categoryMapper.deleteCategoryByCategoryIds(categoryIds);
    }

    /**
     * 删除商品分类信息
     * 
     * @param categoryId 商品分类主键
     * @return 结果
     */
    @Override
    public int deleteCategoryByCategoryId(Long categoryId)
    {
        return categoryMapper.deleteCategoryByCategoryId(categoryId);
    }
}
