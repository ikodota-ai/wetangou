package com.ruoyi.biz.mapper;

import java.util.List;
import com.ruoyi.common.annotation.IgnoreTenant;
import com.ruoyi.biz.domain.StoredCard;

/**
 * 会员储值卡 Mapper
 *
 * <p>会员卡属于会员（按 memberId 寻址），跨商户查找：@IgnoreTenant 绕过 merchant_id 改写。</p>
 *
 * @author dytuangou
 */
@IgnoreTenant
public interface StoredCardMapper
{
    StoredCard selectById(Long cardId);

    /** 悲观锁查（用于扣减/退款事务内） */
    StoredCard selectForUpdate(Long cardId);

    StoredCard selectByMemberAndProduct(Long memberId, Long productId);

    List<StoredCard> selectList(StoredCard query);

    int insert(StoredCard card);

    int update(StoredCard card);

    int updateBalance(StoredCard card);
}
