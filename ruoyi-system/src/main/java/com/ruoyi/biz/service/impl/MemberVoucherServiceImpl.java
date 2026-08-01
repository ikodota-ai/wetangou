package com.ruoyi.biz.service.impl;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.mapper.MemberVoucherMapper;
import com.ruoyi.biz.domain.MemberVoucher;
import com.ruoyi.biz.service.IMemberVoucherService;

/**
 * 会员代金券Service业务层处理
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@Service
public class MemberVoucherServiceImpl implements IMemberVoucherService 
{
    @Autowired
    private MemberVoucherMapper memberVoucherMapper;

    /**
     * 查询会员代金券
     * 
     * @param id 会员代金券主键
     * @return 会员代金券
     */
    @Override
    public MemberVoucher selectMemberVoucherById(Long id)
    {
        return memberVoucherMapper.selectMemberVoucherById(id);
    }

    /**
     * 查询会员代金券列表
     * 
     * @param memberVoucher 会员代金券
     * @return 会员代金券
     */
    @Override
    public List<MemberVoucher> selectMemberVoucherList(MemberVoucher memberVoucher)
    {
        return memberVoucherMapper.selectMemberVoucherList(memberVoucher);
    }

    /**
     * 新增会员代金券
     * 
     * @param memberVoucher 会员代金券
     * @return 结果
     */
    @Override
    public int insertMemberVoucher(MemberVoucher memberVoucher)
    {
        return memberVoucherMapper.insertMemberVoucher(memberVoucher);
    }

    /**
     * 修改会员代金券
     * 
     * @param memberVoucher 会员代金券
     * @return 结果
     */
    @Override
    public int updateMemberVoucher(MemberVoucher memberVoucher)
    {
        return memberVoucherMapper.updateMemberVoucher(memberVoucher);
    }

    /**
     * 批量删除会员代金券
     * 
     * @param ids 需要删除的会员代金券主键
     * @return 结果
     */
    @Override
    public int deleteMemberVoucherByIds(Long[] ids)
    {
        return memberVoucherMapper.deleteMemberVoucherByIds(ids);
    }

    /**
     * 删除会员代金券信息
     * 
     * @param id 会员代金券主键
     * @return 结果
     */
    @Override
    public int deleteMemberVoucherById(Long id)
    {
        return memberVoucherMapper.deleteMemberVoucherById(id);
    }
}
