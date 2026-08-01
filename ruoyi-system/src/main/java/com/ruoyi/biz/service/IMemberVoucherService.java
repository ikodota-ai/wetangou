package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.MemberVoucher;

/**
 * 会员代金券Service接口
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
public interface IMemberVoucherService 
{
    /**
     * 查询会员代金券
     * 
     * @param id 会员代金券主键
     * @return 会员代金券
     */
    public MemberVoucher selectMemberVoucherById(Long id);

    /**
     * 查询会员代金券列表
     * 
     * @param memberVoucher 会员代金券
     * @return 会员代金券集合
     */
    public List<MemberVoucher> selectMemberVoucherList(MemberVoucher memberVoucher);

    /**
     * 新增会员代金券
     * 
     * @param memberVoucher 会员代金券
     * @return 结果
     */
    public int insertMemberVoucher(MemberVoucher memberVoucher);

    /**
     * 修改会员代金券
     * 
     * @param memberVoucher 会员代金券
     * @return 结果
     */
    public int updateMemberVoucher(MemberVoucher memberVoucher);

    /**
     * 批量删除会员代金券
     * 
     * @param ids 需要删除的会员代金券主键集合
     * @return 结果
     */
    public int deleteMemberVoucherByIds(Long[] ids);

    /**
     * 删除会员代金券信息
     * 
     * @param id 会员代金券主键
     * @return 结果
     */
    public int deleteMemberVoucherById(Long id);
}
