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

    /**
     * 标记邀请码为已过期（独立事务，避免被外层回滚）
     *
     * <p>使用 REQUIRES_NEW：acceptInvite 端点检测到 expireAt &lt; now 时调用本方法，
     * 立即提交 status=2，然后再抛 ServiceException 触发外层事务回滚（清掉 openid 绑定 / 员工关联等）。
     * 这样下次再调 acceptInvite 时，会先命中 "已失效" 短路而不是重复 "已过期"。</p>
     */
    void markExpired(Long inviteId);
    int deleteById(Long id);
    int expireOverdue();
    String generateShortCode();
}
