package com.ruoyi.biz.service.impl;

import java.util.List;
import com.ruoyi.common.utils.DateUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.mapper.ProductStoreMapper;
import com.ruoyi.biz.domain.ProductStore;
import com.ruoyi.biz.service.IProductStoreService;

/**
 * 商品门店上架关系Service业务层处理
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@Service
public class ProductStoreServiceImpl implements IProductStoreService 
{
    @Autowired
    private ProductStoreMapper productStoreMapper;

    /**
     * 查询商品门店上架关系
     * 
     * @param id 商品门店上架关系主键
     * @return 商品门店上架关系
     */
    @Override
    public ProductStore selectProductStoreById(Long id)
    {
        return productStoreMapper.selectProductStoreById(id);
    }

    /**
     * 查询商品门店上架关系列表
     * 
     * @param productStore 商品门店上架关系
     * @return 商品门店上架关系
     */
    @Override
    public List<ProductStore> selectProductStoreList(ProductStore productStore)
    {
        return productStoreMapper.selectProductStoreList(productStore);
    }

    /**
     * 新增商品门店上架关系
     * 
     * @param productStore 商品门店上架关系
     * @return 结果
     */
    @Override
    public int insertProductStore(ProductStore productStore)
    {
        productStore.setCreateTime(DateUtils.getNowDate());
        return productStoreMapper.insertProductStore(productStore);
    }

    /**
     * 修改商品门店上架关系
     * 
     * @param productStore 商品门店上架关系
     * @return 结果
     */
    @Override
    public int updateProductStore(ProductStore productStore)
    {
        return productStoreMapper.updateProductStore(productStore);
    }

    /**
     * 批量删除商品门店上架关系
     * 
     * @param ids 需要删除的商品门店上架关系主键
     * @return 结果
     */
    @Override
    public int deleteProductStoreByIds(Long[] ids)
    {
        return productStoreMapper.deleteProductStoreByIds(ids);
    }

    /**
     * 删除商品门店上架关系信息
     * 
     * @param id 商品门店上架关系主键
     * @return 结果
     */
    @Override
    public int deleteProductStoreById(Long id)
    {
        return productStoreMapper.deleteProductStoreById(id);
    }
}
