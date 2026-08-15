package com.ruoyi.biz.service.impl;

import java.security.SecureRandom;
import java.util.Date;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.domain.MerchantStaffInvite;
import com.ruoyi.biz.mapper.MerchantStaffInviteMapper;
import com.ruoyi.biz.service.IMerchantStaffInviteService;

@Service
public class MerchantStaffInviteServiceImpl implements IMerchantStaffInviteService
{
    private static final String CODE_CHARS = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
    private static final SecureRandom RAND = new SecureRandom();

    @Autowired
    private MerchantStaffInviteMapper inviteMapper;

    @Override
    public MerchantStaffInvite selectById(Long id)
    {
        return inviteMapper.selectById(id);
    }

    @Override
    public MerchantStaffInvite selectByCode(String code)
    {
        return inviteMapper.selectByCode(code);
    }

    @Override
    public List<MerchantStaffInvite> selectList(MerchantStaffInvite query)
    {
        return inviteMapper.selectList(query);
    }

    @Override
    public int insert(MerchantStaffInvite entity)
    {
        if (entity.getInviteCode() == null || entity.getInviteCode().isEmpty())
        {
            entity.setInviteCode(generateShortCode());
        }
        if (entity.getStatus() == null) entity.setStatus("0");
        if (entity.getCreateTime() == null) entity.setCreateTime(new Date());
        return inviteMapper.insert(entity);
    }

    @Override
    public int update(MerchantStaffInvite entity)
    {
        return inviteMapper.update(entity);
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW, rollbackFor = Exception.class)
    public void markExpired(Long inviteId)
    {
        MerchantStaffInvite inv = inviteMapper.selectById(inviteId);
        if (inv == null || !"0".equals(inv.getStatus())) return;
        inv.setStatus("2");
        inviteMapper.update(inv);
    }

    @Override
    public int deleteById(Long id)
    {
        return inviteMapper.deleteById(id);
    }

    @Override
    public int expireOverdue()
    {
        return inviteMapper.expireOverdue();
    }

    /**
     * 生成 6 位短码（去除易混淆字符 0/O/1/I）
     */
    @Override
    public String generateShortCode()
    {
        for (int i = 0; i < 10; i++)
        {
            StringBuilder sb = new StringBuilder(6);
            for (int j = 0; j < 6; j++)
            {
                sb.append(CODE_CHARS.charAt(RAND.nextInt(CODE_CHARS.length())));
            }
            String code = sb.toString();
            if (inviteMapper.selectByCode(code) == null) return code;
        }
        throw new RuntimeException("生成短码失败，请重试");
    }
}
