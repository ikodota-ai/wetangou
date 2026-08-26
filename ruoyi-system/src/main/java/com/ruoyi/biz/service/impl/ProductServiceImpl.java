package com.ruoyi.biz.service.impl;

import java.util.List;
import com.ruoyi.common.utils.DateUtils;
import com.ruoyi.common.utils.StringUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.mapper.ProductMapper;
import com.ruoyi.biz.domain.Product;
import com.ruoyi.biz.domain.Store;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.biz.service.IProductService;

/**
 * 商品Service业务层处理
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@Service
public class ProductServiceImpl implements IProductService 
{
    @Autowired
    private ProductMapper productMapper;

    @Autowired
    private com.ruoyi.biz.mapper.StoreMapper storeMapper;

    /**
     * 查询商品
     * 
     * @param productId 商品主键
     * @return 商品
     */
    @Override
    public Product selectProductByProductId(Long productId)
    {
        return productMapper.selectProductByProductId(productId);
    }

    /**
     * 查询商品列表
     * 
     * @param product 商品
     * @return 商品
     */
    @Override
    public List<Product> selectProductList(Product product)
    {
        return productMapper.selectProductList(product);
    }

    /**
     * 新增商品
     * 
     * @param product 商品
     * @return 结果
     */
    @Override
    public int insertProduct(Product product)
    {
        assertStoresBelongToMerchant(product);
        syncPrimaryStore(product);
        product.setCreateTime(DateUtils.getNowDate());
        return productMapper.insertProduct(product);
    }

    /**
     * 修改商品
     * 
     * @param product 商品
     * @return 结果
     */
    @Override
    public int updateProduct(Product product)
    {
        assertStoresBelongToMerchant(product);
        syncPrimaryStore(product);
        product.setUpdateTime(DateUtils.getNowDate());
        return productMapper.updateProduct(product);
    }

    /**
     * 校验适用门店必须全部属于该商品所属的商户，防止商品跨商家。
     *
     * <p>问题现场：admin 商品表单的「适用门店」是多选下拉，原先没按商家过滤，
     * 平台/代理商账号能把别家商户的门店勾进来 —— 商品挂在商户 A 名下，
     * 却在商户 B 的门店可用。这种数据的后果不只是"看着乱"：
     * <ul>
     *   <li>商户 B 在自己后台看不到这个商品（列表按 merchant_id 过滤），却要为它履约核销；</li>
     *   <li>下单分账走的是商户 A 的收款配置，等于把 B 的营业额打进 A 的账户；</li>
     *   <li>B 想下架也下不掉，因为它没有这条记录的数据权限。</li>
     * </ul>
     *
     * <p>为什么放在 service 而不是 controller：写入口有两个 ——
     * admin 端 {@code ProductController} 和小程序商家端 {@code ApiProductController}，
     * 两边都会调 insert/update。放在 service 层能一处覆盖，
     * 不会出现"补了后台忘了小程序"的漏网。前端的商家→门店联动只是体验优化，
     * 下拉可以绕过，这里才是真正的防线。</p>
     *
     * <p>storeIds 为空时跳过：分段式创建第 1 步还没到选门店那一步，草稿允许为空。</p>
     */
    private void assertStoresBelongToMerchant(Product product)
    {
        if (product == null || product.getMerchantId() == null
                || StringUtils.isEmpty(product.getStoreIds()))
        {
            return;
        }
        Long merchantId = product.getMerchantId();
        for (String raw : product.getStoreIds().split(","))
        {
            String token = raw.trim();
            if (token.isEmpty())
            {
                continue;
            }
            Long storeId;
            try
            {
                storeId = Long.valueOf(token);
            }
            catch (NumberFormatException e)
            {
                throw new ServiceException("适用门店参数非法：" + token);
            }
            Store store = storeMapper.selectStoreByStoreId(storeId);
            if (store == null)
            {
                throw new ServiceException("适用门店不存在：" + storeId);
            }
            if (!merchantId.equals(store.getMerchantId()))
            {
                throw new ServiceException(
                        "门店「" + store.getStoreName() + "」不属于该商家，不能作为本商品的适用门店");
            }
        }
    }

    /**
     * 主门店取适用门店集合的第一个（用于下单归属/兼容旧逻辑）
     */
    private void syncPrimaryStore(Product product)
    {
        if (StringUtils.isNotEmpty(product.getStoreIds()))
        {
            String first = product.getStoreIds().split(",")[0].trim();
            if (StringUtils.isNotEmpty(first))
            {
                try { product.setStoreId(Long.parseLong(first)); } catch (NumberFormatException ignored) {}
            }
        }
    }

    /**
     * 批量删除商品
     * 
     * @param productIds 需要删除的商品主键
     * @return 结果
     */
    @Override
    public int deleteProductByProductIds(Long[] productIds)
    {
        return productMapper.deleteProductByProductIds(productIds);
    }

    /**
     * 删除商品信息
     * 
     * @param productId 商品主键
     * @return 结果
     */
    @Override
    public int deleteProductByProductId(Long productId)
    {
        return productMapper.deleteProductByProductId(productId);
    }
}
