package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.Banner;

/**
 * 首页轮播图 Service
 *
 * @author dytuangou
 * @date 2026-08-02
 */
public interface IBannerService
{
    public Banner selectBannerByBannerId(Long bannerId);

    public List<Banner> selectBannerList(Banner banner);

    public List<Banner> selectActiveBanners(Banner banner);

    public int insertBanner(Banner banner);

    public int updateBanner(Banner banner);

    public int deleteBannerByBannerIds(Long[] bannerIds);

    public int deleteBannerByBannerId(Long bannerId);
}
