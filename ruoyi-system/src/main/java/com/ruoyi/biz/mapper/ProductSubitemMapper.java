package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.biz.domain.ProductSubitem;

public interface ProductSubitemMapper
{
    ProductSubitem selectById(Long subitemId);
    List<ProductSubitem> selectByGroupId(Long groupId);
    List<ProductSubitem> selectByProductId(Long productId);

    /**
     * 查历史子品名称候选（去重），供 admin 端「添加子品」下拉筛选复用。
     *
     * @param merchantId 限定商户（平台账号传 null 表示不限）
     * @param keyword    名称模糊匹配关键字（可为 null）
     */
    /**
     * 分页列表：子品 join 商品/组，带 productName / groupName / pickRule，
     * 供 admin「子商品管理」独立页使用。
     */
    List<ProductSubitem> selectSubitemList(ProductSubitem query);

    List<String> selectNameCandidates(@org.apache.ibatis.annotations.Param("merchantId") Long merchantId,
                                      @org.apache.ibatis.annotations.Param("keyword") String keyword);
    int insert(ProductSubitem entity);
    int update(ProductSubitem entity);
    int deleteById(Long subitemId);
    int deleteByGroupId(Long groupId);
    int deleteByProductId(Long productId);
}
