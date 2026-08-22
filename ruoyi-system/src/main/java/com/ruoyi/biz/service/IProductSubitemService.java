package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.ProductSubitem;

public interface IProductSubitemService
{
    ProductSubitem selectById(Long subitemId);
    List<ProductSubitem> selectByGroupId(Long groupId);
    List<ProductSubitem> selectByProductId(Long productId);
    int insert(ProductSubitem entity);
    int update(ProductSubitem entity);
    int deleteById(Long subitemId);
    int deleteByGroupId(Long groupId);
    int deleteByProductId(Long productId);

    /** 分页列表（带 productName / groupName），供 admin「子商品管理」页使用 */
    List<ProductSubitem> selectSubitemList(ProductSubitem query);

    /** 历史子品名称候选（当前租户可见范围内去重），供 admin 端下拉筛选 */
    List<String> selectNameCandidates(String keyword);
}
