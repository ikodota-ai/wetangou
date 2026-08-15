package com.ruoyi.biz.service;

import java.util.List;
import com.ruoyi.biz.domain.StoredCard;
import com.ruoyi.biz.domain.StoredCardTransaction;

/**
 * 会员储值卡 Service
 *
 * @author dytuangou
 */
public interface IStoredCardService
{
    StoredCard selectById(Long cardId);

    StoredCard selectByMemberAndProduct(Long memberId, Long productId);

    List<StoredCard> selectList(StoredCard query);

    /**
     * 充值（幂等）：事务内 锁卡 + 余额+=amount + 写 RECHARGE 流水
     *
     * @param cardId  卡ID
     * @param amount  充值金额（正）
     * @param bizNo   业务编号（幂等键）
     * @param operator 操作者
     * @return 卡实例（更新后）
     */
    StoredCard recharge(Long cardId, java.math.BigDecimal amount, String bizNo, String operatorType, String operatorId);

    /**
     * 退款（事务内 锁卡 + 余额+=amount + 写 REFUND 流水）
     */
    StoredCard refund(Long cardId, java.math.BigDecimal amount, String bizNo, Long orderId, String operatorType, String operatorId);

    /**
     * 核销扣减（事务内 锁卡 + 余额-=amount + 写 CONSUME 流水 + 累计 usedAmount）
     *
     * <p>由 ApiOrderService 在 STORED_CARD 订单 verify 成功后调用；不通过 controller 暴露。</p>
     */
    StoredCard consume(Long cardId, java.math.BigDecimal amount, String bizNo, Long orderId, String operatorType, String operatorId);

    /**
     * 列出流水
     */
    List<StoredCardTransaction> selectTransactions(Long memberId, String txType, int limit);
}
