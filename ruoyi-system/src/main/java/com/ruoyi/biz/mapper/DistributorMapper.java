package com.ruoyi.biz.mapper;

import java.util.List;
import java.util.Map;
import com.ruoyi.biz.domain.Distributor;

/**
 * 推客Mapper接口
 *
 * @author dytuangou
 * @date 2026-07-24
 */
public interface DistributorMapper
{
    public Distributor selectDistributorByDistributorId(Long distributorId);

    public List<Distributor> selectDistributorList(Distributor distributor);

    public int insertDistributor(Distributor distributor);

    public int updateDistributor(Distributor distributor);

    public int deleteDistributorByDistributorId(Long distributorId);

    public int deleteDistributorByDistributorIds(Long[] distributorIds);

    /**
     * 冻结金额 + delta（delta 可为负数）
     */
    public int incFrozenAmount(Map<String, Object> params);

    /**
     * 可用金额 + delta
     */
    public int incAvailableAmount(Map<String, Object> params);
}
