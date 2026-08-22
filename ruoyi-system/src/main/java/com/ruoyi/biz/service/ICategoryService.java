package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.Category;

/**
 * 商品分类Service接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface ICategoryService 
{
    /**
     * 查询商品分类
     * 
     * @param categoryId 商品分类主键
     * @return 商品分类
     */
    public Category selectCategoryByCategoryId(Long categoryId);

    /**
     * 查询商品分类列表
     * 
     * @param category 商品分类
     * @return 商品分类集合
     */
    public List<Category> selectCategoryList(Category category);

    /**
     * 查询商品品类树（按 parent_id 组装 children），供前端 el-cascader 级联选择使用。
     * 只返回启用状态（status=0）的节点。
     *
     * @param category 过滤条件（如 industryCode）
     * @return 顶级节点列表，children 递归嵌套
     */
    public List<Category> selectCategoryTree(Category category);

    /**
     * 新增商品分类
     * 
     * @param category 商品分类
     * @return 结果
     */
    public int insertCategory(Category category);

    /**
     * 修改商品分类
     * 
     * @param category 商品分类
     * @return 结果
     */
    public int updateCategory(Category category);

    /**
     * 批量删除商品分类
     * 
     * @param categoryIds 需要删除的商品分类主键集合
     * @return 结果
     */
    public int deleteCategoryByCategoryIds(Long[] categoryIds);

    /**
     * 删除商品分类信息
     * 
     * @param categoryId 商品分类主键
     * @return 结果
     */
    public int deleteCategoryByCategoryId(Long categoryId);
}
