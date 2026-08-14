package com.ruoyi.biz.service.impl;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.domain.MerchantStaff;
import com.ruoyi.biz.mapper.MerchantStaffMapper;
import com.ruoyi.biz.service.IMerchantStaffService;

@Service
public class MerchantStaffServiceImpl implements IMerchantStaffService
{
    @Autowired
    private MerchantStaffMapper staffMapper;

    @Override
    public MerchantStaff selectById(Long id)
    {
        return staffMapper.selectById(id);
    }

    @Override
    public MerchantStaff selectByUserId(Long userId)
    {
        return staffMapper.selectByUserId(userId);
    }

    @Override
    public List<MerchantStaff> selectList(MerchantStaff query)
    {
        return staffMapper.selectList(query);
    }

    @Override
    public int insert(MerchantStaff entity)
    {
        return staffMapper.insert(entity);
    }

    @Override
    public int update(MerchantStaff entity)
    {
        return staffMapper.update(entity);
    }

    @Override
    public int updateByUserId(MerchantStaff entity)
    {
        return staffMapper.updateByUserId(entity);
    }

    @Override
    public int deleteById(Long id)
    {
        return staffMapper.deleteById(id);
    }

    @Override
    public int countByUserId(Long userId)
    {
        return staffMapper.countByUserId(userId);
    }
}
