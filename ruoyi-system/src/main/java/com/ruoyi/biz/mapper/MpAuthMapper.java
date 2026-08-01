package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.biz.domain.MpAuth;

/**
 * 小程序授权Mapper接口
 * 
 * @author dytuangou
 */
public interface MpAuthMapper
{
    public MpAuth selectMpAuthByAuthId(Long authId);
    public MpAuth selectMpAuthByAppid(String appid);
    public List<MpAuth> selectMpAuthList(MpAuth mpAuth);
    public int insertMpAuth(MpAuth mpAuth);
    public int updateMpAuth(MpAuth mpAuth);
    public int deleteMpAuthByAuthId(Long authId);
    public int deleteMpAuthByAuthIds(Long[] authIds);
}
