package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.biz.domain.Distributor;

/**
 * 推客Mapper接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface DistributorMapper 
{
    /**
     * 查询推客
     * 
     * @param distributorId 推客主键
     * @return 推客
     */
    public Distributor selectDistributorByDistributorId(Long distributorId);

    /**
     * 查询推客列表
     * 
     * @param distributor 推客
     * @return 推客集合
     */
    public List<Distributor> selectDistributorList(Distributor distributor);

    /**
     * 新增推客
     * 
     * @param distributor 推客
     * @return 结果
     */
    public int insertDistributor(Distributor distributor);

    /**
     * 修改推客
     * 
     * @param distributor 推客
     * @return 结果
     */
    public int updateDistributor(Distributor distributor);

    /**
     * 删除推客
     * 
     * @param distributorId 推客主键
     * @return 结果
     */
    public int deleteDistributorByDistributorId(Long distributorId);

    /**
     * 批量删除推客
     * 
     * @param distributorIds 需要删除的数据主键集合
     * @return 结果
     */
    public int deleteDistributorByDistributorIds(Long[] distributorIds);
}
