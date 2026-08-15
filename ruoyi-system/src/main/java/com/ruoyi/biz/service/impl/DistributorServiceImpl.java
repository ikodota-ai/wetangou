package com.ruoyi.biz.service.impl;

import java.util.List;
import com.ruoyi.common.utils.DateUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.mapper.DistributorMapper;
import com.ruoyi.biz.domain.Distributor;
import com.ruoyi.biz.domain.Member;
import com.ruoyi.biz.service.IDistributorService;
import com.ruoyi.biz.service.IMemberService;

/**
 * 推客Service业务层处理
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@Service
public class DistributorServiceImpl implements IDistributorService 
{
    @Autowired
    private DistributorMapper distributorMapper;

    /**
     * 查询推客
     * 
     * @param distributorId 推客主键
     * @return 推客
     */
    @Override
    public Distributor selectDistributorByDistributorId(Long distributorId)
    {
        return distributorMapper.selectDistributorByDistributorId(distributorId);
    }

    /**
     * 查询推客列表
     * 
     * @param distributor 推客
     * @return 推客
     */
    @Override
    public List<Distributor> selectDistributorList(Distributor distributor)
    {
        return distributorMapper.selectDistributorList(distributor);
    }

    /**
     * 新增推客
     * 
     * @param distributor 推客
     * @return 结果
     */
    @Override
    public int insertDistributor(Distributor distributor)
    {
        distributor.setCreateTime(DateUtils.getNowDate());
        return distributorMapper.insertDistributor(distributor);
    }

    /**
     * 修改推客
     * 
     * @param distributor 推客
     * @return 结果
     */
    @Override
    public int updateDistributor(Distributor distributor)
    {
        distributor.setUpdateTime(DateUtils.getNowDate());
        return distributorMapper.updateDistributor(distributor);
    }

    /**
     * 批量删除推客
     * 
     * @param distributorIds 需要删除的推客主键
     * @return 结果
     */
    @Override
    public int deleteDistributorByDistributorIds(Long[] distributorIds)
    {
        return distributorMapper.deleteDistributorByDistributorIds(distributorIds);
    }

    /**
     * 删除推客信息
     * 
     * @param distributorId 推客主键
     * @return 结果
     */
    @Override
    public int deleteDistributorByDistributorId(Long distributorId)
    {
        return distributorMapper.deleteDistributorByDistributorId(distributorId);
    }

    @Autowired
    private IMemberService memberService;

    @Override
    public Distributor findByMemberId(Long memberId)
    {
        if (memberId == null) return null;
        Distributor q = new Distributor();
        q.setMemberId(memberId);
        List<Distributor> list = distributorMapper.selectDistributorList(q);
        return list.isEmpty() ? null : list.get(0);
    }
}
