package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.biz.domain.ProductSubitem;

public interface ProductSubitemMapper
{
    ProductSubitem selectById(Long subitemId);
    List<ProductSubitem> selectByGroupId(Long groupId);
    List<ProductSubitem> selectByProductId(Long productId);
    int insert(ProductSubitem entity);
    int update(ProductSubitem entity);
    int deleteById(Long subitemId);
    int deleteByGroupId(Long groupId);
    int deleteByProductId(Long productId);
}
