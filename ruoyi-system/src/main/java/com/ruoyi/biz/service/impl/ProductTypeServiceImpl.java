package com.ruoyi.biz.service.impl;

import java.util.Date;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.domain.ProductType;
import com.ruoyi.biz.mapper.ProductTypeMapper;
import com.ruoyi.biz.service.IProductTypeService;

@Service
public class ProductTypeServiceImpl implements IProductTypeService
{
    @Autowired
    private ProductTypeMapper typeMapper;

    @Override
    public ProductType selectByCode(String typeCode)
    {
        return typeMapper.selectByCode(typeCode);
    }

    @Override
    public List<ProductType> selectList(ProductType query)
    {
        return typeMapper.selectList(query);
    }

    @Override
    public List<ProductType> selectAppCreatable()
    {
        ProductType q = new ProductType();
        q.setStatus("0");
        q.setAppCanCreate(1);
        return typeMapper.selectList(q);
    }

    @Override
    public int insert(ProductType entity)
    {
        if (entity.getCreateTime() == null) entity.setCreateTime(new Date());
        return typeMapper.insert(entity);
    }

    @Override
    public int update(ProductType entity)
    {
        entity.setUpdateTime(new Date());
        return typeMapper.update(entity);
    }

    @Override
    public int deleteByCode(String typeCode)
    {
        return typeMapper.deleteByCode(typeCode);
    }
}
