package com.ruoyi.biz.service.impl;

import java.util.List;
import com.ruoyi.common.utils.DateUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.mapper.StoreMapper;
import com.ruoyi.biz.domain.Store;
import com.ruoyi.biz.service.IStoreService;

/**
 * 门店Service业务层处理
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@Service
public class StoreServiceImpl implements IStoreService 
{
    @Autowired
    private StoreMapper storeMapper;

    @Autowired
    private com.ruoyi.biz.mapper.MerchantMapper merchantMapper;

    @Autowired
    private com.ruoyi.biz.mapper.AgentMapper agentMapper;

    @Autowired
    private com.ruoyi.biz.mapper.MerchantStaffMapper merchantStaffMapper;

    @Autowired
    private com.ruoyi.biz.mapper.ProductMapper productMapper;

    /**
     * 查询门店
     * 
     * @param storeId 门店主键
     * @return 门店
     */
    @Override
    public Store selectStoreByStoreId(Long storeId)
    {
        return storeMapper.selectStoreByStoreId(storeId);
    }

    /**
     * 查询门店列表
     * 
     * @param store 门店
     * @return 门店
     */
    @Override
    public List<Store> selectStoreList(Store store)
    {
        return storeMapper.selectStoreList(store);
    }

    /**
     * 新增门店
     * 
     * @param store 门店
     * @return 结果
     */
    @Override
    public int insertStore(Store store)
    {
        // 校验代理商门店配额
        checkAgentStoreQuota(store.getMerchantId());
        store.setCreateTime(DateUtils.getNowDate());
        return storeMapper.insertStore(store);
    }

    /**
     * 校验门店数是否超出代理商 store_quota
     *
     * <p>store_quota=0 表示不限制（平台直营 / 历史数据兼容）。
     * 当 store_quota>0 时，名下所有商户的门店总数（含本条）必须 ≤ store_quota。</p>
     */
    private void checkAgentStoreQuota(Long merchantId)
    {
        if (merchantId == null)
        {
            return;
        }
        com.ruoyi.biz.domain.Merchant merchant = merchantMapper.selectMerchantByMerchantId(merchantId);
        if (merchant == null)
        {
            throw new com.ruoyi.common.exception.ServiceException("商户不存在");
        }
        Long agentId = merchant.getAgentId();
        if (agentId == null || agentId <= 0L)
        {
            // 平台直营（agent_id=0）不限制
            return;
        }
        com.ruoyi.biz.domain.Agent agent = agentMapper.selectAgentByAgentId(agentId);
        if (agent == null)
        {
            throw new com.ruoyi.common.exception.ServiceException("所属代理商不存在");
        }
        Integer quota = agent.getStoreQuota();
        if (quota == null || quota <= 0)
        {
            // 0 或 null 表示不限制
            return;
        }
        int used = agentMapper.countStoresByAgentId(agentId);
        if (used + 1 > quota)
        {
            throw new com.ruoyi.common.exception.ServiceException(
                "代理商门店配额已用尽（" + used + "/" + quota + "），请联系平台购买更多配额");
        }
    }

    /**
     * 修改门店
     * 
     * @param store 门店
     * @return 结果
     */
    @Override
    public int updateStore(Store store)
    {
        assertTransferable(store);
        store.setUpdateTime(DateUtils.getNowDate());
        return storeMapper.updateStore(store);
    }

    /**
     * 门店换商户前，先确认它身上没有会因此变脏的关联数据。
     *
     * <p>问题现场：{@code biz_store.merchant_id} 可以被后台单独改掉，但指向这家门店的
     * {@code biz_merchant_staff}（员工在职关联）和 {@code biz_product.store_ids}（商品适用门店）
     * 都各自存了一份 merchant_id，两边没有外键也没有联动。门店一转走，这些记录立刻变成
     * 「声明属于商户 A，指向的门店却已属于商户 B」的脏数据。</p>
     *
     * <p>真实后果是**报错指错方向**：员工关联脏了以后，老板登录拿到的 storeIds 里还是那家
     * 已经转走的门店，商家端「适用门店」照常把它列出来，商家勾上保存，才在
     * {@link ProductServiceImpl} 的门店归属校验里抛「门店 X 不属于该商家，不能作为本商品的
     * 适用门店」—— 现象是「连老板都建不了商品」，而病根在几天前那次门店换商户的操作上，
     * 中间没有任何提示。商品侧同理：老商户看不到它却仍要履约，新商户想下架也下不掉。</p>
     *
     * <p>所以这里选择「拦住」而不是「静默级联改写」：门店转移涉及履约主体和分账账户变更，
     * 该由人显式决定这些员工和商品怎么处置，代码不该替他猜。提示里带上具体数量，
     * 让操作者知道要先清理什么。</p>
     */
    private void assertTransferable(Store store)
    {
        if (store == null || store.getStoreId() == null || store.getMerchantId() == null)
        {
            return;
        }
        Store origin = storeMapper.selectStoreByStoreId(store.getStoreId());
        if (origin == null || origin.getMerchantId() == null
                || origin.getMerchantId().equals(store.getMerchantId()))
        {
            // 不是转移归属，照常放行
            return;
        }
        // 统计一律 ignoreTenant：这是「转出方还剩什么」的完整性检查，
        // 被当前账号的租户上下文过滤掉就会漏统计，等于形同虚设。
        int staffCount = com.ruoyi.common.utils.TenantContextHolder.ignoreTenant(() -> {
            com.ruoyi.biz.domain.MerchantStaff q = new com.ruoyi.biz.domain.MerchantStaff();
            q.setStoreId(store.getStoreId());
            q.setStatus("0");
            java.util.List<com.ruoyi.biz.domain.MerchantStaff> list = merchantStaffMapper.selectList(q);
            return list == null ? 0 : list.size();
        });
        int productCount = com.ruoyi.common.utils.TenantContextHolder.ignoreTenant(() -> {
            com.ruoyi.biz.domain.Product q = new com.ruoyi.biz.domain.Product();
            q.setStoreId(store.getStoreId());
            q.setDelFlag("0");
            java.util.List<com.ruoyi.biz.domain.Product> list = productMapper.selectProductList(q);
            return list == null ? 0 : list.size();
        });
        if (staffCount > 0 || productCount > 0)
        {
            StringBuilder sb = new StringBuilder();
            sb.append("门店「").append(origin.getStoreName()).append("」不能转到其他商户：");
            if (staffCount > 0)
            {
                sb.append("仍有 ").append(staffCount).append(" 名在职员工关联到该门店");
            }
            if (staffCount > 0 && productCount > 0)
            {
                sb.append("，");
            }
            if (productCount > 0)
            {
                sb.append("仍有 ").append(productCount).append(" 个商品把它作为适用门店");
            }
            sb.append("。请先在原商户下解除这些关联（员工离职/改绑门店，商品移除该适用门店），"
                    + "否则这些数据会变成跨商户脏数据，商家端会出现「门店不属于该商家」而无法建品。");
            throw new com.ruoyi.common.exception.ServiceException(sb.toString());
        }
    }

    /**
     * 批量删除门店
     * 
     * @param storeIds 需要删除的门店主键
     * @return 结果
     */
    @Override
    public int deleteStoreByStoreIds(Long[] storeIds)
    {
        return storeMapper.deleteStoreByStoreIds(storeIds);
    }

    /**
     * 删除门店信息
     * 
     * @param storeId 门店主键
     * @return 结果
     */
    @Override
    public int deleteStoreByStoreId(Long storeId)
    {
        return storeMapper.deleteStoreByStoreId(storeId);
    }
    /**
     * 按经纬度查询最近的 N 个门店（球面距离）
     */
    @Override
    public List<Store> selectNearestStoreList(Double longitude, Double latitude, int limit)
    {
        if (longitude == null || latitude == null)
        {
            // 无坐标时退化为按 store_id 倒序取前 N 个（让小程序至少有默认门店可显示）
            Store fallback = new Store();
            fallback.setStatus("0");
            return storeMapper.selectStoreList(fallback);
        }
        int max = limit <= 0 ? 10 : Math.min(limit, 50);
        List<Store> list = storeMapper.selectNearestStoreList(longitude, latitude, max);
        // 数据隔离保护：即便拦截器漏过滤，再按当前租户 merchant_id 二次过滤
        com.ruoyi.common.core.domain.model.TenantContext ctx = com.ruoyi.common.utils.TenantContextHolder.get();
        if (ctx != null && !ctx.isPlatform() && ctx.getMerchantId() != null)
        {
            Long mid = ctx.getMerchantId();
            java.util.Iterator<Store> it = list.iterator();
            while (it.hasNext())
            {
                if (!mid.equals(it.next().getMerchantId()))
                {
                    it.remove();
                }
            }
        }
        return list;
    }
}
