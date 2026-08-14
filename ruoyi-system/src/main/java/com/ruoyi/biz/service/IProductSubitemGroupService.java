package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.ProductSubitemGroup;

public interface IProductSubitemGroupService
{
    ProductSubitemGroup selectById(Long groupId);
    List<ProductSubitemGroup> selectByProductId(Long productId);
    int insert(ProductSubitemGroup entity);
    int update(ProductSubitemGroup entity);
    int deleteById(Long groupId);
    int deleteByProductId(Long productId);
}
