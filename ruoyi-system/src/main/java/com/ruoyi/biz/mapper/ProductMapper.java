package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.common.annotation.IgnoreTenant;
import com.ruoyi.biz.domain.Product;

/**
 * 商品Mapper接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface ProductMapper 
{
    /**
     * 查询商品
     * 
     * @param productId 商品主键
     * @return 商品
     */
    @IgnoreTenant
    public Product selectProductByProductId(Long productId);

    /**
     * 查询商品列表
     * 
     * @param product 商品
     * @return 商品集合
     */
    public List<Product> selectProductList(Product product);

    /**
     * 新增商品
     * 
     * @param product 商品
     * @return 结果
     */
    public int insertProduct(Product product);

    /**
     * 修改商品
     * 
     * @param product 商品
     * @return 结果
     */
    public int updateProduct(Product product);

    /**
     * 删除商品
     * 
     * @param productId 商品主键
     * @return 结果
     */
    public int deleteProductByProductId(Long productId);

    /**
     * 原子扣库存 + 加销量（下单支付成功时用）。
     *
     * <p>为什么不复用 {@code updateProduct}：</p>
     * <ol>
     *   <li><b>它带业务校验</b> —— {@code ProductServiceImpl.updateProduct} 第一行是
     *       {@code assertStoresBelongToMerchant}，商品的 store_ids 里只要有一个门店的
     *       merchant_id 和商品对不上（线上就有这种存量脏数据），扣库存这一步直接抛
     *       「门店不属于该商家」，把整个支付回调事务回滚掉 —— 用户钱付了，订单状态没了。
     *       扣库存本不该关心门店归属。</li>
     *   <li><b>它是「读出来减一再写回去」</b> —— 两个人同时下单会双双读到 stock=5，
     *       各自写回 4，卖出 2 件却只扣 1 件。这里用 {@code stock = stock - #{num}}
     *       让数据库自己算，并用 {@code stock >= #{num}} 兜住不卖成负数。</li>
     *   <li><b>它会顺带写 biz_product_ext</b> —— {@code saveExt} 拿一个只填了
     *       stock/sales 的实体去覆盖扩展字段，等于每笔支付都在悄悄擦商品详情。</li>
     * </ol>
     *
     * <p>返回 0 表示库存不足（并发抢完了），调用方据此决定是否要放弃扣减。
     * 支付回调场景下钱已经收了，不能因为库存不足就回滚订单，只记 warn。</p>
     *
     * @param productId 商品ID
     * @param num 购买份数
     * @return 影响行数（0 = 库存不足）
     */
    @IgnoreTenant
    public int deductStockAndAddSales(@org.apache.ibatis.annotations.Param("productId") Long productId,
                                      @org.apache.ibatis.annotations.Param("num") Long num);

    /**
     * 批量删除商品
     * 
     * @param productIds 需要删除的数据主键集合
     * @return 结果
     */
    public int deleteProductByProductIds(Long[] productIds);
}
