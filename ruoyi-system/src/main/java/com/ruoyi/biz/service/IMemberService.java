package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.Member;

/**
 * 会员Service接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface IMemberService 
{
    /**
     * 查询会员
     * 
     * @param memberId 会员主键
     * @return 会员
     */
    public Member selectMemberByMemberId(Long memberId);

    /**
     * 根据openid查询会员
     */
    public Member selectMemberByOpenid(Long merchantId, String openid);

    /**
     * 查询会员列表
     * 
     * @param member 会员
     * @return 会员集合
     */
    public List<Member> selectMemberList(Member member);

    /**
     * 新增会员
     * 
     * @param member 会员
     * @return 结果
     */
    public int insertMember(Member member);

    /**
     * 修改会员
     * 
     * @param member 会员
     * @return 结果
     */
    public int updateMember(Member member);

    /**
     * 批量删除会员
     * 
     * @param memberIds 需要删除的会员主键集合
     * @return 结果
     */
    public int deleteMemberByMemberIds(Long[] memberIds);

    /**
     * 删除会员信息
     * 
     * @param memberId 会员主键
     * @return 结果
     */
    public int deleteMemberByMemberId(Long memberId);
}
