package com.ruoyi.biz.service.impl;

import java.util.Date;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.domain.Agent;
import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.biz.mapper.AgentMapper;
import com.ruoyi.biz.mapper.MerchantMapper;
import com.ruoyi.biz.service.IMerchantService;
import com.ruoyi.biz.service.ITenantService;
import com.ruoyi.common.core.domain.model.TenantContext;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.common.utils.TenantContextHolder;

/**
 * 商户Service业务层处理
 *
 * @author dytuangou
 */
@Service
public class MerchantServiceImpl implements IMerchantService
{
    @Autowired
    private MerchantMapper merchantMapper;

    @Autowired
    private AgentMapper agentMapper;

    @Autowired
    private ITenantService tenantService;

    /**
     * 查询商户
     */
    @Override
    public Merchant selectMerchantByMerchantId(Long merchantId)
    {
        return merchantMapper.selectMerchantByMerchantId(merchantId);
    }

    /**
     * 查询商户列表：代理商仅可见名下商户，商户账号仅可见自己
     */
    @Override
    public List<Merchant> selectMerchantList(Merchant merchant)
    {
        TenantContext context = TenantContextHolder.get();
        if (context != null && context.isAgent())
        {
            merchant.setAgentId(context.getAgentId());
        }
        else if (context != null && context.isMerchant())
        {
            merchant.getParams().put("merchantIds", String.valueOf(context.getMerchantId()));
        }
        return merchantMapper.selectMerchantList(merchant);
    }

    /**
     * 新增商户
     *
     * <p>代理商开通商户时校验剩余额度与代理资格有效期，成功后占用一个额度。</p>
     */
    @Override
    public int insertMerchant(Merchant merchant)
    {
        if (!checkAppidUnique(merchant))
        {
            throw new ServiceException("新增商户失败，小程序AppId已被占用：" + merchant.getAppid());
        }
        TenantContext context = TenantContextHolder.get();
        if (context != null && context.isAgent())
        {
            // 代理商只能把商户开在自己名下
            merchant.setAgentId(context.getAgentId());
            checkAgentQuota(context.getAgentId());
        }
        if (merchant.getAgentId() == null)
        {
            merchant.setAgentId(0L);
        }
        if (StringUtils.isEmpty(merchant.getMerchantNo()))
        {
            merchant.setMerchantNo(generateMerchantNo());
        }
        if (StringUtils.isEmpty(merchant.getStatus()))
        {
            merchant.setStatus("0");
        }
        merchant.setCreateBy(SecurityUtils.getUsername());
        int rows = merchantMapper.insertMerchant(merchant);
        if (rows > 0 && merchant.getAgentId() != null && merchant.getAgentId() > 0L)
        {
            agentMapper.increaseUsedQuota(merchant.getAgentId());
        }
        return rows;
    }

    /**
     * 修改商户
     */
    @Override
    public int updateMerchant(Merchant merchant)
    {
        checkMerchantDataScope(merchant.getMerchantId());
        if (!checkAppidUnique(merchant))
        {
            throw new ServiceException("修改商户失败，小程序AppId已被占用：" + merchant.getAppid());
        }
        TenantContext context = TenantContextHolder.get();
        if (context != null && !context.isPlatform())
        {
            // 非平台账号不允许改变商户归属
            merchant.setAgentId(null);
        }
        merchant.setUpdateBy(SecurityUtils.getUsername());
        int rows = merchantMapper.updateMerchant(merchant);
        tenantService.clearMerchantCache(merchant.getMerchantId());
        return rows;
    }

    /**
     * 批量删除商户（逻辑删除）
     */
    @Override
    public int deleteMerchantByMerchantIds(Long[] merchantIds)
    {
        if (merchantIds == null)
        {
            return 0;
        }
        for (Long merchantId : merchantIds)
        {
            checkMerchantDataScope(merchantId);
        }
        int rows = merchantMapper.deleteMerchantByMerchantIds(merchantIds);
        for (Long merchantId : merchantIds)
        {
            tenantService.clearMerchantCache(merchantId);
        }
        return rows;
    }

    /**
     * 校验appid唯一性
     */
    @Override
    public boolean checkAppidUnique(Merchant merchant)
    {
        if (StringUtils.isEmpty(merchant.getAppid()))
        {
            return true;
        }
        Merchant exists = merchantMapper.selectMerchantByAppid(merchant.getAppid());
        if (exists == null)
        {
            return true;
        }
        return merchant.getMerchantId() != null && merchant.getMerchantId().equals(exists.getMerchantId());
    }

    /**
     * 校验当前账号是否有权操作该商户
     */
    @Override
    public void checkMerchantDataScope(Long merchantId)
    {
        TenantContext context = TenantContextHolder.get();
        if (context == null || context.isPlatform() || merchantId == null)
        {
            return;
        }
        if (context.isAgent())
        {
            if (!context.getMerchantIds().contains(merchantId))
            {
                throw new ServiceException("没有权限访问该商户数据");
            }
            return;
        }
        if (!merchantId.equals(context.getMerchantId()))
        {
            throw new ServiceException("没有权限访问该商户数据");
        }
    }

    /**
     * 校验代理商开户额度与资格有效期
     */
    private void checkAgentQuota(Long agentId)
    {
        Agent agent = agentMapper.selectAgentByAgentId(agentId);
        if (agent == null)
        {
            throw new ServiceException("代理商信息不存在");
        }
        if (!"0".equals(agent.getStatus()))
        {
            throw new ServiceException("代理商已停用，无法开通商户");
        }
        if (agent.getExpireTime() != null && agent.getExpireTime().before(new Date()))
        {
            throw new ServiceException("代理资格已到期，请先向平台续费");
        }
        int quota = agent.getMerchantQuota() == null ? 0 : agent.getMerchantQuota();
        int used = agent.getUsedQuota() == null ? 0 : agent.getUsedQuota();
        if (used >= quota)
        {
            throw new ServiceException("商户开通额度已用尽（" + used + "/" + quota + "），请先向平台购买额度");
        }
    }

    /**
     * 生成商户编号
     */
    private String generateMerchantNo()
    {
        return "MC" + System.currentTimeMillis();
    }
}
