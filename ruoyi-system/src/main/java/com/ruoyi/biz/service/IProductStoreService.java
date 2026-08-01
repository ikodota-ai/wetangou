package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.ProductStore;

/**
 * 商品门店上架关系Service接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface IProductStoreService 
{
    /**
     * 查询商品门店上架关系
     * 
     * @param id 商品门店上架关系主键
     * @return 商品门店上架关系
     */
    public ProductStore selectProductStoreById(Long id);

    /**
     * 查询商品门店上架关系列表
     * 
     * @param productStore 商品门店上架关系
     * @return 商品门店上架关系集合
     */
    public List<ProductStore> selectProductStoreList(ProductStore productStore);

    /**
     * 新增商品门店上架关系
     * 
     * @param productStore 商品门店上架关系
     * @return 结果
     */
    public int insertProductStore(ProductStore productStore);

    /**
     * 修改商品门店上架关系
     * 
     * @param productStore 商品门店上架关系
     * @return 结果
     */
    public int updateProductStore(ProductStore productStore);

    /**
     * 批量删除商品门店上架关系
     * 
     * @param ids 需要删除的商品门店上架关系主键集合
     * @return 结果
     */
    public int deleteProductStoreByIds(Long[] ids);

    /**
     * 删除商品门店上架关系信息
     * 
     * @param id 商品门店上架关系主键
     * @return 结果
     */
    public int deleteProductStoreById(Long id);
}
