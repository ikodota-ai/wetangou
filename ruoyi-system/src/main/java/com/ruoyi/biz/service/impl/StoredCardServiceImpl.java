package com.ruoyi.biz.service.impl;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.biz.domain.StoredCard;
import com.ruoyi.biz.domain.StoredCardTransaction;
import com.ruoyi.biz.mapper.StoredCardMapper;
import com.ruoyi.biz.mapper.StoredCardTransactionMapper;
import com.ruoyi.biz.service.IStoredCardService;

/**
 * 储值卡 Service 实现
 *
 * <p>关键约束：</p>
 * <ul>
 *   <li>所有写操作事务内 SELECT FOR UPDATE 悲观锁</li>
 *   <li>余额不允许为负（服务层校验）</li>
 *   <li>幂等键 biz_no 唯一索引防重放</li>
 *   <li>流水 append-only，不允许 UPDATE/DELETE</li>
 * </ul>
 *
 * @author dytuangou
 */
@Service
public class StoredCardServiceImpl implements IStoredCardService
{
    private static final Logger log = LoggerFactory.getLogger(StoredCardServiceImpl.class);

    @Autowired private StoredCardMapper cardMapper;
    @Autowired private StoredCardTransactionMapper txMapper;

    @Override
    public StoredCard selectById(Long cardId) {
        return cardMapper.selectById(cardId);
    }

    @Override
    public StoredCard selectByMemberAndProduct(Long memberId, Long productId) {
        return cardMapper.selectByMemberAndProduct(memberId, productId);
    }

    @Override
    public List<StoredCard> selectList(StoredCard query) {
        return cardMapper.selectList(query);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public StoredCard recharge(Long cardId, BigDecimal amount, String bizNo,
                               String operatorType, String operatorId)
    {
        return move(cardId, amount.abs(), bizNo, "RECHARGE", null, operatorType, operatorId);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public StoredCard refund(Long cardId, BigDecimal amount, String bizNo, Long orderId,
                             String operatorType, String operatorId)
    {
        return move(cardId, amount.abs(), bizNo, "REFUND", orderId, operatorType, operatorId);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public StoredCard consume(Long cardId, BigDecimal amount, String bizNo, Long orderId,
                              String operatorType, String operatorId)
    {
        // 消费是负向
        StoredCard after = move(cardId, amount.abs().negate(), bizNo, "CONSUME", orderId, operatorType, operatorId);
        // 累计 usedAmount
        BigDecimal used = after.getUsedAmount() == null ? BigDecimal.ZERO : after.getUsedAmount();
        after.setUsedAmount(used.add(amount.abs()).setScale(2, RoundingMode.HALF_UP));
        cardMapper.updateBalance(after);
        return after;
    }

    @Override
    public List<StoredCardTransaction> selectTransactions(Long memberId, String txType, int limit) {
        StoredCardTransaction q = new StoredCardTransaction();
        q.setMemberId(memberId);
        q.setTxType(txType);
        List<StoredCardTransaction> list = txMapper.selectList(q);
        if (list == null) return java.util.Collections.emptyList();
        if (limit > 0 && list.size() > limit) return list.subList(0, limit);
        return list;
    }

    /**
     * 余额移动核心方法。
     *
     * <p>事务内流程：幂等检查 → 锁卡 → 校验 → 余额变动 → 更新卡 → 写流水。</p>
     *
     * @param amount 正=入账(RECHARGE/REFUND)  负=出账(CONSUME)
     */
    private StoredCard move(Long cardId, BigDecimal amount, String bizNo, String txType,
                            Long orderId, String operatorType, String operatorId)
    {
        if (cardId == null) throw new ServiceException("卡ID不能为空");
        if (amount == null || amount.signum() == 0) throw new ServiceException("金额不能为 0");
        if (bizNo == null || bizNo.isEmpty()) throw new ServiceException("业务编号不能为空");

        // 1) 幂等：已存在同 biz_no 直接返回原卡
        StoredCardTransaction exist = txMapper.selectByBizNo(bizNo);
        if (exist != null) {
            log.info("[储值卡] 幂等命中 bizNo={} txId={} amount={}", bizNo, exist.getTxId(), exist.getAmount());
            return cardMapper.selectById(cardId);
        }

        // 2) 锁卡
        StoredCard card = cardMapper.selectForUpdate(cardId);
        if (card == null) throw new ServiceException("储值卡不存在");
        if (!"0".equals(card.getStatus())) throw new ServiceException("储值卡状态异常: " + card.getStatus());
        if (card.getExpireAt() != null && card.getExpireAt().before(new java.util.Date())) {
            throw new ServiceException("储值卡已过期");
        }

        // 3) 校验
        BigDecimal before = card.getBalance() == null ? BigDecimal.ZERO : card.getBalance();
        BigDecimal after = before.add(amount).setScale(2, RoundingMode.HALF_UP);
        if (after.signum() < 0) {
            throw new ServiceException("余额不足（当前 " + before + "，需扣 " + amount.abs() + "）");
        }

        // 4) 更新卡余额 + 累计字段
        card.setBalance(after);
        if ("RECHARGE".equals(txType)) {
            BigDecimal r = card.getRechargeAmount() == null ? BigDecimal.ZERO : card.getRechargeAmount();
            card.setRechargeAmount(r.add(amount).setScale(2, RoundingMode.HALF_UP));
        } else if ("REFUND".equals(txType)) {
            BigDecimal r = card.getRefundAmount() == null ? BigDecimal.ZERO : card.getRefundAmount();
            card.setRefundAmount(r.add(amount).setScale(2, RoundingMode.HALF_UP));
        }
        cardMapper.updateBalance(card);

        // 5) 写流水
        StoredCardTransaction tx = new StoredCardTransaction();
        tx.setCardId(cardId);
        tx.setMerchantId(card.getMerchantId());
        tx.setMemberId(card.getMemberId());
        tx.setTxType(txType);
        tx.setAmount(amount);
        tx.setBalanceBefore(before);
        tx.setBalanceAfter(after);
        tx.setOrderId(orderId);
        tx.setBizNo(bizNo);
        tx.setOperatorType(operatorType == null ? "SYSTEM" : operatorType);
        tx.setOperatorId(operatorId);
        txMapper.insert(tx);

        log.info("[储值卡] {} 卡={} 金额={} 前={} 后={} bizNo={}",
            txType, cardId, amount, before, after, bizNo);
        return card;
    }
}
