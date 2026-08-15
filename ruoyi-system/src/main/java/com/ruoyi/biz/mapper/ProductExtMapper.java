package com.ruoyi.biz.mapper;

import com.ruoyi.biz.domain.ProductExt;
public interface ProductExtMapper {
    ProductExt selectById(Long productId);
    int insert(ProductExt ext);
    int update(ProductExt ext);
    int deleteById(Long productId);
}
