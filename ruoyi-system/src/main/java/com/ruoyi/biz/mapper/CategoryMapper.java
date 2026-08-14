package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.common.annotation.IgnoreTenant;
import com.ruoyi.biz.domain.Category;

/**
 * 商品分类Mapper接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface CategoryMapper 
{
    /**
     * 查询商品分类
     * 
     * @param categoryId 商品分类主键
     * @return 商品分类
     */
    @IgnoreTenant
    public Category selectCategoryByCategoryId(Long categoryId);

    /**
     * 查询商品分类列表
     * 
     * @param category 商品分类
     * @return 商品分类集合
     */
    public List<Category> selectCategoryList(Category category);

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
     * 删除商品分类
     * 
     * @param categoryId 商品分类主键
     * @return 结果
     */
    public int deleteCategoryByCategoryId(Long categoryId);

    /**
     * 批量删除商品分类
     * 
     * @param categoryIds 需要删除的数据主键集合
     * @return 结果
     */
    public int deleteCategoryByCategoryIds(Long[] categoryIds);
}
