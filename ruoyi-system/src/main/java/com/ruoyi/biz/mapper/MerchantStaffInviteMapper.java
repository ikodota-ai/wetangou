package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.biz.domain.MerchantStaffInvite;

public interface MerchantStaffInviteMapper
{
    MerchantStaffInvite selectById(Long inviteId);
    MerchantStaffInvite selectByCode(String inviteCode);
    List<MerchantStaffInvite> selectList(MerchantStaffInvite query);
    int insert(MerchantStaffInvite entity);
    int update(MerchantStaffInvite entity);
    int deleteById(Long inviteId);
    int expireOverdue();
}
