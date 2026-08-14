package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.ProductType;

/**
 * 商品类型字典 biz_product_type
 *
 * <p>类型是平台级字典（GROUPON/VOUCHER/...），与"店内分类 biz_product_category"不同。
 * 商家在 admin 后台选类型，前端按 type_code 渲染不同的字段表单。</p>
 */
public interface IProductTypeService
{
    /** 根据 typeCode 查一条 */
    ProductType selectByCode(String typeCode);

    /** 列表（按 sort 升序） */
    List<ProductType> selectList(ProductType query);

    /** 小程序可选的类型（app_can_create=1） */
    List<ProductType> selectAppCreatable();

    int insert(ProductType entity);

    int update(ProductType entity);

    int deleteByCode(String typeCode);
}
