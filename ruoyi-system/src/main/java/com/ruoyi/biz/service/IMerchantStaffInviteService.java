package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.MerchantStaffInvite;

public interface IMerchantStaffInviteService
{
    MerchantStaffInvite selectById(Long id);
    MerchantStaffInvite selectByCode(String code);
    List<MerchantStaffInvite> selectList(MerchantStaffInvite query);
    int insert(MerchantStaffInvite entity);
    int update(MerchantStaffInvite entity);
    int deleteById(Long id);
    int expireOverdue();
    String generateShortCode();
}
