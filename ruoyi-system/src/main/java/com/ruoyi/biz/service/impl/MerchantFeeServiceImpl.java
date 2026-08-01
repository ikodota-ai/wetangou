package com.ruoyi.biz.service.impl;

import java.util.Calendar;
import java.util.Date;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.biz.domain.MerchantFee;
import com.ruoyi.biz.mapper.MerchantFeeMapper;
import com.ruoyi.biz.mapper.MerchantMapper;
import com.ruoyi.biz.service.IMerchantFeeService;
import com.ruoyi.biz.service.ITenantService;
import com.ruoyi.common.core.domain.model.TenantContext;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.common.utils.TenantContextHolder;

/**
 * 商户收费Service业务层处理
 *
 * <p>代理商向名下商户收费，平台可见全部。确认收款后按服务月数/结束时间
 * 同步商户 service_expire，商户账号只读自己的记录。</p>
 *
 * @author dytuangou
 */
@Service
public class MerchantFeeServiceImpl implements IMerchantFeeService
{
    /** 未收 */
    private static final String STATUS_UNPAID = "0";

    /** 已收 */
    private static final String STATUS_PAID = "1";

    /** 作废 */
    private static final String STATUS_VOID = "2";

    @Autowired
    private MerchantFeeMapper merchantFeeMapper;

    @Autowired
    private MerchantMapper merchantMapper;

    @Autowired
    private ITenantService tenantService;

    /**
     * 查询商户收费（租户条件由拦截器追加）
     */
    @Override
    public MerchantFee selectMerchantFeeByFeeId(Long feeId)
    {
        return merchantFeeMapper.selectMerchantFeeByFeeId(feeId);
    }

    /**
     * 查询收费列表：代理商限定自己作为收费方，商户由拦截器限定自身
     */
    @Override
    public List<MerchantFee> selectMerchantFeeList(MerchantFee merchantFee)
    {
        TenantContext context = TenantContextHolder.get();
        if (context != null && context.isAgent())
        {
            merchantFee.getParams().put("agentIdEq", context.getAgentId());
        }
        return merchantFeeMapper.selectMerchantFeeList(merchantFee);
    }

    /**
     * 新增收费单：商户账号不可自行开单，代理商只能给名下商户开单
     */
    @Override
    public int insertMerchantFee(MerchantFee merchantFee)
    {
        TenantContext context = TenantContextHolder.get();
        if (context != null && context.isMerchant())
        {
            throw new ServiceException("商户账号无权登记收费单");
        }
        if (merchantFee.getMerchantId() == null)
        {
            throw new ServiceException("请选择商户");
        }
        if (context != null && context.isAgent())
        {
            if (!context.getMerchantIds().contains(merchantFee.getMerchantId()))
            {
                throw new ServiceException("无权向非名下商户开具收费单");
            }
            merchantFee.setAgentId(context.getAgentId());
        }
        if (merchantFee.getAgentId() == null)
        {
            // 平台直收时归属该商户的代理商，便于对账
            Merchant merchant = merchantMapper.selectMerchantByMerchantId(merchantFee.getMerchantId());
            merchantFee.setAgentId(merchant == null || merchant.getAgentId() == null ? 0L : merchant.getAgentId());
        }
        if (StringUtils.isEmpty(merchantFee.getFeeNo()))
        {
            merchantFee.setFeeNo("MF" + System.currentTimeMillis());
        }
        if (StringUtils.isEmpty(merchantFee.getStatus()))
        {
            merchantFee.setStatus(STATUS_UNPAID);
        }
        fillEndTime(merchantFee);
        merchantFee.setCreateBy(SecurityUtils.getUsername());
        int rows = merchantFeeMapper.insertMerchantFee(merchantFee);
        if (rows > 0 && STATUS_PAID.equals(merchantFee.getStatus()))
        {
            syncServiceExpire(merchantFee);
        }
        return rows;
    }

    /**
     * 修改收费单：已收款的不可修改，状态变更走确认接口
     */
    @Override
    public int updateMerchantFee(MerchantFee merchantFee)
    {
        checkWritable();
        MerchantFee origin = merchantFeeMapper.selectMerchantFeeByFeeId(merchantFee.getFeeId());
        if (origin == null)
        {
            throw new ServiceException("收费记录不存在");
        }
        if (STATUS_PAID.equals(origin.getStatus()))
        {
            throw new ServiceException("该收费单已收款，不可修改");
        }
        // 归属不允许通过修改变更，避免跨商户搬移数据
        merchantFee.setMerchantId(null);
        merchantFee.setAgentId(null);
        merchantFee.setStatus(null);
        fillEndTime(merchantFee);
        merchantFee.setUpdateBy(SecurityUtils.getUsername());
        return merchantFeeMapper.updateMerchantFee(merchantFee);
    }

    /**
     * 确认收款：仅未收状态可确认，确认后同步商户服务到期时间
     */
    @Override
    @Transactional
    public int confirmMerchantFee(Long feeId)
    {
        checkWritable();
        MerchantFee origin = merchantFeeMapper.selectMerchantFeeByFeeId(feeId);
        if (origin == null)
        {
            throw new ServiceException("收费记录不存在");
        }
        if (!STATUS_UNPAID.equals(origin.getStatus()))
        {
            throw new ServiceException("该收费单已处理，不可重复确认");
        }

        MerchantFee update = new MerchantFee();
        update.setFeeId(feeId);
        update.setStatus(STATUS_PAID);
        update.setUpdateBy(SecurityUtils.getUsername());
        int rows = merchantFeeMapper.updateMerchantFee(update);
        if (rows > 0)
        {
            syncServiceExpire(origin);
        }
        return rows;
    }

    /**
     * 批量删除收费单：已收款的保留留痕不可删除
     */
    @Override
    public int deleteMerchantFeeByFeeIds(Long[] feeIds)
    {
        checkWritable();
        if (feeIds != null)
        {
            for (Long feeId : feeIds)
            {
                MerchantFee origin = merchantFeeMapper.selectMerchantFeeByFeeId(feeId);
                if (origin != null && STATUS_PAID.equals(origin.getStatus()))
                {
                    throw new ServiceException("收费单 " + origin.getFeeNo() + " 已收款，不可删除");
                }
            }
        }
        return merchantFeeMapper.deleteMerchantFeeByFeeIds(feeIds);
    }

    /**
     * 未显式给服务结束时间时，按开始时间与月数推算
     */
    private void fillEndTime(MerchantFee merchantFee)
    {
        if (merchantFee.getEndTime() != null)
        {
            return;
        }
        Integer months = merchantFee.getMonths();
        if (months == null || months <= 0)
        {
            return;
        }
        Date begin = merchantFee.getBeginTime() == null ? new Date() : merchantFee.getBeginTime();
        Calendar calendar = Calendar.getInstance();
        calendar.setTime(begin);
        calendar.add(Calendar.MONTH, months);
        merchantFee.setEndTime(calendar.getTime());
    }

    /**
     * 收款确认后把服务到期时间写回商户
     *
     * <p>仅在新到期时间晚于原到期时间时更新，避免补录历史单据把有效期改短。</p>
     */
    private void syncServiceExpire(MerchantFee merchantFee)
    {
        if (merchantFee.getEndTime() == null || merchantFee.getMerchantId() == null)
        {
            return;
        }
        Merchant merchant = merchantMapper.selectMerchantByMerchantId(merchantFee.getMerchantId());
        if (merchant == null)
        {
            return;
        }
        if (merchant.getServiceExpire() != null && !merchantFee.getEndTime().after(merchant.getServiceExpire()))
        {
            return;
        }
        Merchant update = new Merchant();
        update.setMerchantId(merchantFee.getMerchantId());
        update.setServiceExpire(merchantFee.getEndTime());
        update.setUpdateBy(SecurityUtils.getUsername());
        merchantMapper.updateMerchant(update);
        tenantService.clearMerchantCache(merchantFee.getMerchantId());
    }

    /**
     * 商户账号只读，不能登记/确认/删除收费单
     */
    private void checkWritable()
    {
        TenantContext context = TenantContextHolder.get();
        if (context != null && context.isMerchant())
        {
            throw new ServiceException("商户账号无权操作收费单");
        }
    }
}
