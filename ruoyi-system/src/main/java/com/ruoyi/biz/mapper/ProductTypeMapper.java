package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.biz.domain.ProductType;

public interface ProductTypeMapper
{
    ProductType selectByCode(String typeCode);
    List<ProductType> selectList(ProductType query);
    int insert(ProductType entity);
    int update(ProductType entity);
    int deleteByCode(String typeCode);
}
