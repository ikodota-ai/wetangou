package com.ruoyi.biz.mapper;

import java.util.List;
import java.util.Map;
import com.ruoyi.common.annotation.IgnoreTenant;
import com.ruoyi.biz.domain.Distributor;

/**
 * 推客Mapper接口
 *
 * @author dytuangou
 * @date 2026-07-24
 */
public interface DistributorMapper
{
    @IgnoreTenant
    public Distributor selectDistributorByDistributorId(Long distributorId);

    /**
     * 按商户+会员查推客（用于订单自动归属）
     */
    public Distributor selectDistributorByMemberId(@org.apache.ibatis.annotations.Param("merchantId") Long merchantId, @org.apache.ibatis.annotations.Param("memberId") Long memberId);

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
