package com.ruoyi.biz.service.impl;

import java.util.Date;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.domain.ProductSubitem;
import com.ruoyi.biz.mapper.ProductSubitemMapper;
import com.ruoyi.biz.service.IProductSubitemService;

@Service
public class ProductSubitemServiceImpl implements IProductSubitemService
{
    @Autowired
    private ProductSubitemMapper subitemMapper;

    @Override
    public ProductSubitem selectById(Long subitemId)
    {
        return subitemMapper.selectById(subitemId);
    }

    @Override
    public List<ProductSubitem> selectByGroupId(Long groupId)
    {
        return subitemMapper.selectByGroupId(groupId);
    }

    @Override
    public List<ProductSubitem> selectByProductId(Long productId)
    {
        return subitemMapper.selectByProductId(productId);
    }

    @Override
    public int insert(ProductSubitem entity)
    {
        if (entity.getCreateTime() == null) entity.setCreateTime(new Date());
        return subitemMapper.insert(entity);
    }

    @Override
    public int update(ProductSubitem entity)
    {
        return subitemMapper.update(entity);
    }

    @Override
    public int deleteById(Long subitemId)
    {
        return subitemMapper.deleteById(subitemId);
    }

    @Override
    public int deleteByGroupId(Long groupId)
    {
        return subitemMapper.deleteByGroupId(groupId);
    }

    @Override
    public int deleteByProductId(Long productId)
    {
        return subitemMapper.deleteByProductId(productId);
    }

    @Override
    public List<ProductSubitem> selectSubitemList(ProductSubitem query)
    {
        return subitemMapper.selectSubitemList(query);
    }

    @Override
    public List<String> selectNameCandidates(String keyword)
    {
        // 商户账号只看自己的历史子品；平台/代理商不限（候选名称非敏感数据）
        com.ruoyi.common.core.domain.model.TenantContext ctx = com.ruoyi.common.utils.TenantContextHolder.get();
        Long merchantId = (ctx != null && ctx.isMerchant()) ? ctx.getMerchantId() : null;
        return subitemMapper.selectNameCandidates(merchantId, keyword);
    }
}
