package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.common.annotation.IgnoreTenant;
import com.ruoyi.biz.domain.StoredCardTransaction;

/**
 * 储值卡流水 Mapper
 *
 * <p>会员侧查流水按 memberId 寻址，跨商户：@IgnoreTenant 绕过 merchant_id 改写。</p>
 *
 * @author dytuangou
 */
@IgnoreTenant
public interface StoredCardTransactionMapper
{
    StoredCardTransaction selectByBizNo(String bizNo);

    List<StoredCardTransaction> selectList(StoredCardTransaction query);

    int insert(StoredCardTransaction tx);
}
