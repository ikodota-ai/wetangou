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
     * 模拟支付成功回调：置为待使用，生成核销码、计算有效期，冻结代金券，触发佣金
     */
    Order paySuccess(Long orderId);

    /**
     * 员工核销（验证核销码 + 检查有效期 + 改订单状态）
     */
    Order verify(String verifyCode, Long storeId, String operator);
}
