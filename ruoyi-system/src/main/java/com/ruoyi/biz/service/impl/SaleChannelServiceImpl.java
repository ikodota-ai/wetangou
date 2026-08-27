package com.ruoyi.biz.service.impl;

import java.util.ArrayList;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.domain.SaleChannel;
import com.ruoyi.biz.mapper.SaleChannelMapper;
import com.ruoyi.biz.service.ISaleChannelService;

/**
 * 投放渠道字典 Service 实现
 */
@Service
public class SaleChannelServiceImpl implements ISaleChannelService
{
    @Autowired
    private SaleChannelMapper saleChannelMapper;

    @Override
    public List<SaleChannel> selectSaleChannelList(SaleChannel query)
    {
        return saleChannelMapper.selectSaleChannelList(query == null ? new SaleChannel() : query);
    }

    @Override
    public List<SaleChannel> selectEnabled()
    {
        SaleChannel query = new SaleChannel();
        query.setStatus("0");
        return saleChannelMapper.selectSaleChannelList(query);
    }

    /**
     * 新建商品时的默认勾选。
     *
     * <p>放在服务端算而不是前端写死：渠道字典是平台级配置，运营停用某个渠道后，
     * 前端不应该还把它当默认值提交上来（提交了也会在保存时被当成无效代码）。</p>
     */
    @Override
    public String defaultChannelCodes()
    {
        List<String> codes = new ArrayList<>();
        for (SaleChannel c : selectEnabled())
        {
            if (c.getIsDefault() != null && c.getIsDefault() == 1)
            {
                codes.add(c.getChannelCode());
            }
        }
        return String.join(",", codes);
    }

    @Override
    public SaleChannel selectByCode(String channelCode)
    {
        return saleChannelMapper.selectByCode(channelCode);
    }

    @Override
    public int insertSaleChannel(SaleChannel channel)
    {
        return saleChannelMapper.insertSaleChannel(channel);
    }

    @Override
    public int updateSaleChannel(SaleChannel channel)
    {
        return saleChannelMapper.updateSaleChannel(channel);
    }

    @Override
    public int deleteByCodes(String[] channelCodes)
    {
        return saleChannelMapper.deleteByCodes(channelCodes);
    }
}
