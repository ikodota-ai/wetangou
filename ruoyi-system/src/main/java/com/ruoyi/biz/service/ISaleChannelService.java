package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.SaleChannel;

/**
 * 投放渠道字典 Service
 */
public interface ISaleChannelService
{
    List<SaleChannel> selectSaleChannelList(SaleChannel query);

    /** 仅启用的渠道，供商品编辑页勾选用 */
    List<SaleChannel> selectEnabled();

    /** 新建商品时默认勾选的渠道代码，逗号分隔 */
    String defaultChannelCodes();

    SaleChannel selectByCode(String channelCode);

    int insertSaleChannel(SaleChannel channel);

    int updateSaleChannel(SaleChannel channel);

    int deleteByCodes(String[] channelCodes);
}
