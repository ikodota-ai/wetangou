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
        store.setUpdateTime(DateUtils.getNowDate());
        return storeMapper.updateStore(store);
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
