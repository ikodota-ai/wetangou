package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.biz.domain.Banner;

/**
 * 首页轮播图 Mapper
 *
 * @author dytuangou
 * @date 2026-08-02
 */
public interface BannerMapper
{
    public Banner selectBannerByBannerId(Long bannerId);

    public List<Banner> selectBannerList(Banner banner);

    /**
     * 小程序匿名接口：按 position + merchantId(可空) 查询启用的 banner，按 sort 升序
     */
    public List<Banner> selectActiveBanners(Banner banner);

    public int insertBanner(Banner banner);

    public int updateBanner(Banner banner);

    public int deleteBannerByBannerId(Long bannerId);

    public int deleteBannerByBannerIds(Long[] bannerIds);
}
