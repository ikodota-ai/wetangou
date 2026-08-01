package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.MpRelease;

/**
 * 小程序发布Service接口
 *
 * @author dytuangou
 */
public interface IMpReleaseService
{
    /**
     * 查询发布记录
     *
     * @param releaseId 发布主键
     * @return 发布记录
     */
    public MpRelease selectMpReleaseByReleaseId(Long releaseId);

    /**
     * 查询发布记录列表
     *
     * @param mpRelease 发布记录
     * @return 发布记录集合
     */
    public List<MpRelease> selectMpReleaseList(MpRelease mpRelease);

    /**
     * 新增发布记录（代上传：生成待提交版本）
     *
     * @param mpRelease 发布记录
     * @return 结果
     */
    public int insertMpRelease(MpRelease mpRelease);

    /**
     * 按商户微信配置生成 ext.json
     *
     * <p>供后台「代上传」表单选择商户后自动填充，避免人工抄写 appid 出错。</p>
     *
     * @param merchantId 商户ID
     * @return 格式化后的 ext.json 文本
     */
    public String buildExtJson(Long merchantId);

    /**
     * 修改发布记录
     *
     * @param mpRelease 发布记录
     * @return 结果
     */
    public int updateMpRelease(MpRelease mpRelease);

    /**
     * 提交审核：待提交/审核失败/已撤回 → 审核中
     *
     * @param releaseId 发布ID
     * @return 结果
     */
    public int submitAudit(Long releaseId);

    /**
     * 撤回审核：审核中 → 已撤回
     *
     * @param releaseId 发布ID
     * @return 结果
     */
    public int undoAudit(Long releaseId);

    /**
     * 发布上线：审核通过且未发布 → 已发布
     *
     * @param releaseId 发布ID
     * @return 结果
     */
    public int release(Long releaseId);

    /**
     * 版本回退：已发布 → 已回退
     *
     * @param releaseId 发布ID
     * @return 结果
     */
    public int rollback(Long releaseId);

    /**
     * 批量删除发布记录
     *
     * @param releaseIds 需要删除的数据主键集合
     * @return 结果
     */
    public int deleteMpReleaseByReleaseIds(Long[] releaseIds);
}
