package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.biz.domain.MpRelease;

/**
 * 小程序发布记录Mapper接口
 *
 * <p>biz_mp_release 属商户强隔离表，由租户拦截器自动追加 merchant_id 条件。</p>
 *
 * @author dytuangou
 */
public interface MpReleaseMapper
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
     * 新增发布记录
     *
     * @param mpRelease 发布记录
     * @return 结果
     */
    public int insertMpRelease(MpRelease mpRelease);

    /**
     * 修改发布记录
     *
     * @param mpRelease 发布记录
     * @return 结果
     */
    public int updateMpRelease(MpRelease mpRelease);

    /**
     * 批量删除发布记录
     *
     * @param releaseIds 需要删除的数据主键集合
     * @return 结果
     */
    public int deleteMpReleaseByReleaseIds(Long[] releaseIds);
}
