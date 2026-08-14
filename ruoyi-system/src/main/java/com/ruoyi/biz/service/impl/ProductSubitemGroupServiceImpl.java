package com.ruoyi.biz.service.impl;

import java.util.Date;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.domain.ProductSubitem;
import com.ruoyi.biz.domain.ProductSubitemGroup;
import com.ruoyi.biz.mapper.ProductSubitemGroupMapper;
import com.ruoyi.biz.mapper.ProductSubitemMapper;
import com.ruoyi.biz.service.IProductSubitemGroupService;

@Service
public class ProductSubitemGroupServiceImpl implements IProductSubitemGroupService
{
    @Autowired
    private ProductSubitemGroupMapper groupMapper;

    @Autowired
    private ProductSubitemMapper subitemMapper;

    @Override
    public ProductSubitemGroup selectById(Long groupId)
    {
        ProductSubitemGroup g = groupMapper.selectById(groupId);
        if (g != null) g.setSubitems(subitemMapper.selectByGroupId(groupId));
        return g;
    }

    @Override
    public List<ProductSubitemGroup> selectByProductId(Long productId)
    {
        List<ProductSubitemGroup> groups = groupMapper.selectByProductId(productId);
        for (ProductSubitemGroup g : groups)
        {
            g.setSubitems(subitemMapper.selectByGroupId(g.getGroupId()));
        }
        return groups;
    }

    @Override
    public int insert(ProductSubitemGroup entity)
    {
        if (entity.getCreateTime() == null) entity.setCreateTime(new Date());
        if (entity.getPickRule() == null) entity.setPickRule("ALL");
        return groupMapper.insert(entity);
    }

    @Override
    public int update(ProductSubitemGroup entity)
    {
        return groupMapper.update(entity);
    }

    @Override
    public int deleteById(Long groupId)
    {
        // 先删子品再删组（避免外键悬空）
        subitemMapper.deleteByGroupId(groupId);
        return groupMapper.deleteById(groupId);
    }

    @Override
    public int deleteByProductId(Long productId)
    {
        subitemMapper.deleteByProductId(productId);
        return groupMapper.deleteByProductId(productId);
    }
}
