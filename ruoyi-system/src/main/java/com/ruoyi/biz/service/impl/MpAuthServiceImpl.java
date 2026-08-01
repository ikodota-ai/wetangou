package com.ruoyi.biz.service.impl;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.domain.MpAuth;
import com.ruoyi.biz.mapper.MpAuthMapper;
import com.ruoyi.biz.service.IMpAuthService;
import com.ruoyi.common.utils.DateUtils;

@Service
public class MpAuthServiceImpl implements IMpAuthService
{
    @Autowired
    private MpAuthMapper mpAuthMapper;

    @Override
    public MpAuth selectMpAuthByAuthId(Long authId) { return mpAuthMapper.selectMpAuthByAuthId(authId); }

    @Override
    public MpAuth selectMpAuthByAppid(String appid) { return mpAuthMapper.selectMpAuthByAppid(appid); }

    @Override
    public List<MpAuth> selectMpAuthList(MpAuth mpAuth) { return mpAuthMapper.selectMpAuthList(mpAuth); }

    @Override
    public int insertMpAuth(MpAuth mpAuth)
    {
        mpAuth.setCreateTime(DateUtils.getNowDate());
        return mpAuthMapper.insertMpAuth(mpAuth);
    }

    @Override
    public int updateMpAuth(MpAuth mpAuth)
    {
        mpAuth.setUpdateTime(DateUtils.getNowDate());
        return mpAuthMapper.updateMpAuth(mpAuth);
    }

    @Override
    public int deleteMpAuthByAuthIds(Long[] authIds) { return mpAuthMapper.deleteMpAuthByAuthIds(authIds); }

    @Override
    public int deleteMpAuthByAuthId(Long authId) { return mpAuthMapper.deleteMpAuthByAuthId(authId); }
}
