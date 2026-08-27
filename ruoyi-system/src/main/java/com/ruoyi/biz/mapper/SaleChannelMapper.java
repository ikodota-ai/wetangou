package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.biz.domain.SaleChannel;

/**
 * 投放渠道字典 Mapper
 */
public interface SaleChannelMapper
{
    List<SaleChannel> selectSaleChannelList(SaleChannel query);

    SaleChannel selectByCode(String channelCode);

    int insertSaleChannel(SaleChannel channel);

    int updateSaleChannel(SaleChannel channel);

    int deleteByCodes(String[] channelCodes);
}
