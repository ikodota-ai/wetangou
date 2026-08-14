package com.ruoyi.biz.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.common.annotation.IgnoreTenant;
import com.ruoyi.biz.domain.Member;
import jakarta.validation.constraints.NotNull;

/**
 * 会员Mapper接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface MemberMapper 
{
    /**
     * 查询会员
     * 
     * @param memberId 会员主键
     * @return 会员
     */
    @IgnoreTenant
    public Member selectMemberByMemberId(Long memberId);

    /**
     * 根据openid查询会员
     *
     * @param openid 微信openid
     * @return 会员
     */
    public Member selectMemberByOpenid(@Param("merchantId") @NotNull Long merchantId, @Param("openid") String openid);

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
     * 删除会员
     * 
     * @param memberId 会员主键
     * @return 结果
     */
    public int deleteMemberByMemberId(Long memberId);

    /**
     * 批量删除会员
     * 
     * @param memberIds 需要删除的数据主键集合
     * @return 结果
     */
    public int deleteMemberByMemberIds(Long[] memberIds);
}
