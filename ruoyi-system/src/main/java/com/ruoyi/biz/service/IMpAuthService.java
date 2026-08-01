package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.MpAuth;

/**
 * 小程序授权Service接口
 */
public interface IMpAuthService
{
    public MpAuth selectMpAuthByAuthId(Long authId);
    public MpAuth selectMpAuthByAppid(String appid);
    public List<MpAuth> selectMpAuthList(MpAuth mpAuth);
    public int insertMpAuth(MpAuth mpAuth);
    public int updateMpAuth(MpAuth mpAuth);
    public int deleteMpAuthByAuthIds(Long[] authIds);
    public int deleteMpAuthByAuthId(Long authId);
}
