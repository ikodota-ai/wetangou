package com.ruoyi.biz.service.impl;

import java.util.List;
import com.ruoyi.common.utils.DateUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.mapper.BannerMapper;
import com.ruoyi.biz.domain.Banner;
import com.ruoyi.biz.service.IBannerService;
import com.ruoyi.common.core.domain.model.TenantContext;
import com.ruoyi.common.utils.TenantContextHolder;

@Service
public class BannerServiceImpl implements IBannerService
{
    @Autowired
    private BannerMapper bannerMapper;

    @Override
    public Banner selectBannerByBannerId(Long bannerId)
    {
        return bannerMapper.selectBannerByBannerId(bannerId);
    }

    @Override
    public List<Banner> selectBannerList(Banner banner)
    {
        return bannerMapper.selectBannerList(banner);
    }

    @Override
    public List<Banner> selectActiveBanners(Banner banner)
    {
        return bannerMapper.selectActiveBanners(banner);
    }

    @Override
    public int insertBanner(Banner banner)
    {
        // 租户身份注入：商户账号自动绑定自己的 merchant_id；代理商/平台账号建 banner 时必须显式传 merchantId
        if (banner.getMerchantId() == null || banner.getMerchantId() == 0)
        {
            TenantContext ctx = TenantContextHolder.get();
            if (ctx != null && ctx.isMerchant() && ctx.getMerchantId() != null)
            {
                banner.setMerchantId(ctx.getMerchantId());
            }
        }
        banner.setCreateTime(DateUtils.getNowDate());
        return bannerMapper.insertBanner(banner);
    }

    @Override
    public int updateBanner(Banner banner)
    {
        banner.setUpdateTime(DateUtils.getNowDate());
        return bannerMapper.updateBanner(banner);
    }

    @Override
    public int deleteBannerByBannerIds(Long[] bannerIds)
    {
        return bannerMapper.deleteBannerByBannerIds(bannerIds);
    }

    @Override
    public int deleteBannerByBannerId(Long bannerId)
    {
        return bannerMapper.deleteBannerByBannerId(bannerId);
    }
}
