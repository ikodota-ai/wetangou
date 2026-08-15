package com.ruoyi.biz.service;
import com.ruoyi.biz.domain.ProductExt;
public interface IProductExtService {
    ProductExt selectById(Long productId);
    int save(ProductExt ext);
    int deleteById(Long productId);
}
