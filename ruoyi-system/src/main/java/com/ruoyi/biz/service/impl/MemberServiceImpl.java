package com.ruoyi.biz.service.impl;

import java.util.List;
import com.ruoyi.common.utils.DateUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.mapper.MemberMapper;
import com.ruoyi.biz.domain.Member;
import com.ruoyi.biz.service.IMemberService;
import jakarta.validation.constraints.NotNull;

/**
 * 会员Service业务层处理
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@Service
public class MemberServiceImpl implements IMemberService 
{
    @Autowired
    private MemberMapper memberMapper;

    /**
     * 查询会员
     * 
     * @param memberId 会员主键
     * @return 会员
     */
    @Override
    public Member selectMemberByMemberId(Long memberId)
    {
        return memberMapper.selectMemberByMemberId(memberId);
    }

    /**
     * 根据openid查询会员
     */
    @Override
    public Member selectMemberByOpenid(@NotNull Long merchantId, String openid)
    {
        if (merchantId == null)
        {
            // 防御性：merchantId 为 null 会让 SQL 退化为「openid 全平台唯一匹配」，跨商户串数据
            throw new IllegalArgumentException("selectMemberByOpenid: merchantId 不能为空");
        }
        return memberMapper.selectMemberByOpenid(merchantId, openid);
    }

    /**
     * 查询会员列表
     * 
     * @param member 会员
     * @return 会员
     */
    @Override
    public List<Member> selectMemberList(Member member)
    {
        return memberMapper.selectMemberList(member);
    }

    /**
     * 新增会员
     * 
     * @param member 会员
     * @return 结果
     */
    @Override
    public int insertMember(Member member)
    {
        member.setCreateTime(DateUtils.getNowDate());
        return memberMapper.insertMember(member);
    }

    /**
     * 修改会员
     * 
     * @param member 会员
     * @return 结果
     */
    @Override
    public int updateMember(Member member)
    {
        member.setUpdateTime(DateUtils.getNowDate());
        return memberMapper.updateMember(member);
    }

    /**
     * 批量删除会员
     * 
     * @param memberIds 需要删除的会员主键
     * @return 结果
     */
    @Override
    public int deleteMemberByMemberIds(Long[] memberIds)
    {
        return memberMapper.deleteMemberByMemberIds(memberIds);
    }

    /**
     * 删除会员信息
     * 
     * @param memberId 会员主键
     * @return 结果
     */
    @Override
    public int deleteMemberByMemberId(Long memberId)
    {
        return memberMapper.deleteMemberByMemberId(memberId);
    }

    @Override
    public Member selectByOpenidAcrossMerchant(Long merchantId, String openid)
    {
        return memberMapper.selectByOpenidAcrossMerchant(merchantId, openid);
    }
}
