package com.ruoyi.biz.service.impl;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.domain.ProductExt;
import com.ruoyi.biz.mapper.ProductExtMapper;
import com.ruoyi.biz.service.IProductExtService;
@Service
public class ProductExtServiceImpl implements IProductExtService {
    @Autowired private ProductExtMapper mapper;
    @Override public ProductExt selectById(Long productId) { return mapper.selectById(productId); }
    @Override public int save(ProductExt ext) {
        return mapper.selectById(ext.getProductId()) == null ? mapper.insert(ext) : mapper.update(ext);
    }
    @Override public int deleteById(Long productId) { return mapper.deleteById(productId); }
}
