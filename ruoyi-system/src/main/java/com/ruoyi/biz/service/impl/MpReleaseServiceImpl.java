package com.ruoyi.biz.service.impl;

import java.util.Date;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.alibaba.fastjson2.JSONObject;
import com.alibaba.fastjson2.JSONWriter;
import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.biz.domain.MpRelease;
import com.ruoyi.biz.mapper.MerchantMapper;
import com.ruoyi.biz.mapper.MpReleaseMapper;
import com.ruoyi.biz.service.IMpReleaseService;
import com.ruoyi.common.core.domain.model.TenantContext;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.common.utils.TenantContextHolder;
import com.ruoyi.system.service.ISysConfigService;

/**
 * 小程序发布Service业务层处理
 *
 * <p>维护「待提交 → 审核中 → 审核通过 → 已发布」的状态机与操作留痕。
 * 微信第三方平台接口需完成开放平台认证后接入，此处只做状态流转，
 * 保证前后端流程可用且不会出现非法跃迁。</p>
 *
 * @author dytuangou
 */
@Service
public class MpReleaseServiceImpl implements IMpReleaseService
{
    /** 审核状态：待提交 */
    private static final String AUDIT_PENDING = "0";

    /** 审核状态：审核中 */
    private static final String AUDIT_DOING = "1";

    /** 审核状态：审核通过 */
    private static final String AUDIT_PASSED = "2";

    /** 审核状态：审核失败 */
    private static final String AUDIT_FAILED = "3";

    /** 审核状态：已撤回 */
    private static final String AUDIT_UNDO = "4";

    /** 发布状态：未发布 */
    private static final String RELEASE_NONE = "0";

    /** 发布状态：已发布 */
    private static final String RELEASE_DONE = "1";

    /** 发布状态：已回退 */
    private static final String RELEASE_BACK = "2";

    @Autowired
    private MpReleaseMapper mpReleaseMapper;

    /** 参数key：小程序代码模板ID */
    private static final String KEY_TEMPLATE_ID = "wx.open.templateId";

    /** 参数key：小程序接口域名 */
    private static final String KEY_API_BASE_URL = "wx.open.apiBaseUrl";

    @Autowired
    private MerchantMapper merchantMapper;

    @Autowired
    private ISysConfigService sysConfigService;

    /**
     * 查询发布记录（租户条件由拦截器追加）
     */
    @Override
    public MpRelease selectMpReleaseByReleaseId(Long releaseId)
    {
        return mpReleaseMapper.selectMpReleaseByReleaseId(releaseId);
    }

    /**
     * 查询发布记录列表：代理商限定名下商户，商户由拦截器限定自身
     */
    @Override
    public List<MpRelease> selectMpReleaseList(MpRelease mpRelease)
    {
        TenantContext context = TenantContextHolder.get();
        if (context != null && context.isAgent())
        {
            List<Long> merchantIds = context.getMerchantIds();
            if (merchantIds == null || merchantIds.isEmpty())
            {
                // 名下暂无商户，直接返回空集，避免拼出恒真条件
                mpRelease.getParams().put("merchantIds", "-1");
            }
            else
            {
                StringBuilder ids = new StringBuilder();
                for (Long id : merchantIds)
                {
                    if (ids.length() > 0)
                    {
                        ids.append(',');
                    }
                    ids.append(id);
                }
                mpRelease.getParams().put("merchantIds", ids.toString());
            }
        }
        return mpReleaseMapper.selectMpReleaseList(mpRelease);
    }

    /**
     * 新增发布记录（代上传）：校验商户已配置 appid，初始为待提交
     */
    @Override
    public int insertMpRelease(MpRelease mpRelease)
    {
        Long merchantId = resolveMerchantId(mpRelease.getMerchantId());
        Merchant merchant = merchantMapper.selectMerchantByMerchantId(merchantId);
        if (merchant == null)
        {
            throw new ServiceException("商户不存在");
        }
        if (StringUtils.isEmpty(merchant.getAppid()))
        {
            throw new ServiceException("该商户尚未配置小程序AppId，无法上传代码");
        }
        mpRelease.setMerchantId(merchantId);
        mpRelease.setAppid(merchant.getAppid());
        if (StringUtils.isEmpty(mpRelease.getUserVersion()))
        {
            throw new ServiceException("请填写版本号");
        }
        // 未指定模板ID时取平台统一模板，避免每次手填
        if (StringUtils.isEmpty(mpRelease.getTemplateId()))
        {
            mpRelease.setTemplateId(sysConfigService.selectConfigByKey(KEY_TEMPLATE_ID));
        }
        // ext.json 缺省时按商户配置自动生成，保证注入的 appid 与商户一致
        if (StringUtils.isEmpty(mpRelease.getExtJson()))
        {
            mpRelease.setExtJson(buildExtJson(merchant));
        }
        mpRelease.setAuditStatus(AUDIT_PENDING);
        mpRelease.setReleaseStatus(RELEASE_NONE);
        mpRelease.setCreateBy(SecurityUtils.getUsername());
        return mpReleaseMapper.insertMpRelease(mpRelease);
    }

    /**
     * 修改发布记录：仅待提交状态可改，已提审的版本内容不可变更
     */
    @Override
    public int updateMpRelease(MpRelease mpRelease)
    {
        MpRelease origin = getExists(mpRelease.getReleaseId());
        if (!AUDIT_PENDING.equals(origin.getAuditStatus()))
        {
            throw new ServiceException("该版本已提交审核，不可修改");
        }
        // 归属与状态不允许通过修改变更
        mpRelease.setMerchantId(null);
        mpRelease.setAppid(null);
        mpRelease.setAuditStatus(null);
        mpRelease.setReleaseStatus(null);
        mpRelease.setUpdateBy(SecurityUtils.getUsername());
        return mpReleaseMapper.updateMpRelease(mpRelease);
    }

    /**
     * 提交审核：仅待提交/审核失败/已撤回可提交
     */
    @Override
    public int submitAudit(Long releaseId)
    {
        MpRelease origin = getExists(releaseId);
        String status = origin.getAuditStatus();
        if (!AUDIT_PENDING.equals(status) && !AUDIT_FAILED.equals(status) && !AUDIT_UNDO.equals(status))
        {
            throw new ServiceException("当前审核状态不允许提交审核");
        }
        MpRelease update = new MpRelease();
        update.setReleaseId(releaseId);
        update.setAuditStatus(AUDIT_DOING);
        update.setAuditReason("");
        update.setUpdateBy(SecurityUtils.getUsername());
        return mpReleaseMapper.updateMpRelease(update);
    }

    /**
     * 撤回审核：仅审核中可撤回
     */
    @Override
    public int undoAudit(Long releaseId)
    {
        MpRelease origin = getExists(releaseId);
        if (!AUDIT_DOING.equals(origin.getAuditStatus()))
        {
            throw new ServiceException("仅审核中的版本可撤回");
        }
        MpRelease update = new MpRelease();
        update.setReleaseId(releaseId);
        update.setAuditStatus(AUDIT_UNDO);
        update.setUpdateBy(SecurityUtils.getUsername());
        return mpReleaseMapper.updateMpRelease(update);
    }

    /**
     * 发布上线：需审核通过且尚未发布
     */
    @Override
    public int release(Long releaseId)
    {
        MpRelease origin = getExists(releaseId);
        if (!AUDIT_PASSED.equals(origin.getAuditStatus()))
        {
            throw new ServiceException("仅审核通过的版本可发布");
        }
        if (RELEASE_DONE.equals(origin.getReleaseStatus()))
        {
            throw new ServiceException("该版本已发布");
        }
        MpRelease update = new MpRelease();
        update.setReleaseId(releaseId);
        update.setReleaseStatus(RELEASE_DONE);
        update.setReleaseTime(new Date());
        update.setUpdateBy(SecurityUtils.getUsername());
        return mpReleaseMapper.updateMpRelease(update);
    }

    /**
     * 版本回退：仅已发布可回退
     */
    @Override
    public int rollback(Long releaseId)
    {
        MpRelease origin = getExists(releaseId);
        if (!RELEASE_DONE.equals(origin.getReleaseStatus()))
        {
            throw new ServiceException("仅已发布的版本可回退");
        }
        MpRelease update = new MpRelease();
        update.setReleaseId(releaseId);
        update.setReleaseStatus(RELEASE_BACK);
        update.setUpdateBy(SecurityUtils.getUsername());
        return mpReleaseMapper.updateMpRelease(update);
    }

    /**
     * 批量删除：已发布的记录保留留痕不可删除
     */
    @Override
    public int deleteMpReleaseByReleaseIds(Long[] releaseIds)
    {
        if (releaseIds != null)
        {
            for (Long releaseId : releaseIds)
            {
                MpRelease origin = mpReleaseMapper.selectMpReleaseByReleaseId(releaseId);
                if (origin != null && RELEASE_DONE.equals(origin.getReleaseStatus()))
                {
                    throw new ServiceException("版本 " + origin.getUserVersion() + " 已发布，不可删除");
                }
            }
        }
        return mpReleaseMapper.deleteMpReleaseByReleaseIds(releaseIds);
    }

    /**
     * 按商户ID生成 ext.json（供后台表单预填）
     */
    @Override
    public String buildExtJson(Long merchantId)
    {
        Long targetId = resolveMerchantId(merchantId);
        Merchant merchant = merchantMapper.selectMerchantByMerchantId(targetId);
        if (merchant == null)
        {
            throw new ServiceException("商户不存在");
        }
        if (StringUtils.isEmpty(merchant.getAppid()))
        {
            throw new ServiceException("该商户尚未配置小程序AppId，请先在商户管理中维护微信配置");
        }
        return buildExtJson(merchant);
    }

    /**
     * 组装 ext.json：extAppid 决定代码归属的小程序，ext 内为业务侧读取的差异化参数
     *
     * <p>小程序代码里不写死 appid（运行时用 getAccountInfoSync 获取），
     * 这里注入商户ID与接口域名，保证同一套模板可服务多个商户。</p>
     */
    private String buildExtJson(Merchant merchant)
    {
        JSONObject ext = new JSONObject();
        ext.put("merchantId", merchant.getMerchantId());
        ext.put("merchantName", merchant.getMerchantName());
        String apiBaseUrl = sysConfigService.selectConfigByKey(KEY_API_BASE_URL);
        if (StringUtils.isNotEmpty(apiBaseUrl))
        {
            ext.put("baseUrl", apiBaseUrl);
        }

        JSONObject root = new JSONObject();
        root.put("extAppid", merchant.getAppid());
        root.put("extEnable", Boolean.TRUE);
        root.put("ext", ext);
        // 带缩进输出，便于后台文本框中人工核对与微调
        return JSONObject.toJSONString(root, JSONWriter.Feature.PrettyFormat);
    }

    /**
     * 商户账号忽略传入的商户ID，一律取自身；其他账号必须显式指定
     */
    private Long resolveMerchantId(Long merchantId)
    {
        TenantContext context = TenantContextHolder.get();
        if (context != null && context.isMerchant())
        {
            return context.getMerchantId();
        }
        if (merchantId == null)
        {
            throw new ServiceException("请选择商户");
        }
        if (context != null && context.isAgent() && !context.getMerchantIds().contains(merchantId))
        {
            throw new ServiceException("无权操作非名下商户的小程序");
        }
        return merchantId;
    }

    /**
     * 取存在的记录，租户条件由拦截器保证越权不可见
     */
    private MpRelease getExists(Long releaseId)
    {
        MpRelease origin = mpReleaseMapper.selectMpReleaseByReleaseId(releaseId);
        if (origin == null)
        {
            throw new ServiceException("发布记录不存在");
        }
        return origin;
    }
}
