package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.biz.domain.MerchantStaff;

public interface MerchantStaffMapper
{
    MerchantStaff selectById(Long id);
    MerchantStaff selectByUserId(Long userId);
    List<MerchantStaff> selectList(MerchantStaff query);
    int insert(MerchantStaff entity);
    int update(MerchantStaff entity);
    int updateByUserId(MerchantStaff entity);
    int deleteById(Long id);
    int countByUserId(Long userId);
}
