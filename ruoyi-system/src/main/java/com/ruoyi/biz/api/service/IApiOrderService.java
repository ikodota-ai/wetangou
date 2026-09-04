package com.ruoyi.biz.api.service;

import com.ruoyi.biz.domain.Order;

/**
 * 小程序-订单业务（下单、核销）
 *
 * <p>由 {@link ApiOrderServiceImpl} 实现。原类名 ApiOrderService 不带 Impl 后缀，
 * 与项目其他 Service 实现类（*ServiceImpl）命名不一致，重构后统一。</p>
 *
 * @author dytuangou
 */
public interface IApiOrderService
{
    /**
     * 下单
     */
    Order placeOrder(Long memberId, Long productId, Long num, Long memberVoucherId, Long distributorId);

    /**
     * 支付成功入账：置为待使用，生成核销码、计算有效期，核销代金券，扣库存，触发佣金
     */
    Order paySuccess(Long orderId);

    /**
     * 支付成功入账并落微信侧真实交易号。
     *
     * @param transactionId 微信支付订单号（回调 {@code transaction_id}），
     *                      为空时按 mock 生成本地流水号
     */
    Order paySuccess(Long orderId, String transactionId);

    /**
     * 员工核销（验证核销码 + 检查有效期 + 改订单状态）
     */
    Order verify(String verifyCode, Long storeId, String operator);
}
