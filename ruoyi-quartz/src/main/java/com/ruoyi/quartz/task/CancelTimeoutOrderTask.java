package com.ruoyi.quartz.task;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import com.ruoyi.biz.service.IOrderService;
import com.ruoyi.biz.service.IPayBillService;

/**
 * 待支付订单 / 待完成买单超时自动取消
 *
 * <p>为什么必须有这个任务：{@code VoucherUsageService.assertNotHeld} 判定一张
 * 代金券是否被占用，看的是订单 status in ('0','1','2')、买单 status in ('0','1')
 * —— 待支付也算占用。这个口径本身是对的（否则同一张券能在 N 个待付单里各抵
 * 一次），但用户下单不付时那张券就被永久锁死，之后每次选券都弹「该代金券已
 * 用于另一笔待支付订单」。</p>
 *
 * <p>手动取消入口（{@code POST /api/order/&#123;id&#125;/cancel}、
 * {@code POST /api/bill/&#123;id&#125;/cancel}）已经有了，但没人会为了解锁一张券
 * 去翻半年前的废单 —— 实测本地库积压 116 笔待付订单、9 笔待完成买单，
 * 它们扣着的券全都是废的。</p>
 *
 * <p>订单和买单放同一个 task：两者是同一个业务问题（券被废单锁住）的两条
 * 路径，阈值也该一起调，拆成两个 job 只会让运营改配置时漏掉一个。</p>
 *
 * <p>Quartz 调用：{@code cancelTimeoutOrderTask.ryNoParams()}，建议 Cron
 * 每 5 分钟（{@code 0 0/5 * * * ?}）。</p>
 *
 * @author dytuangou
 */
@Component("cancelTimeoutOrderTask")
public class CancelTimeoutOrderTask
{
    private static final Logger log = LoggerFactory.getLogger(CancelTimeoutOrderTask.class);

    /** 参数key：下单后多少分钟未支付自动取消 */
    private static final String KEY_ORDER_TIMEOUT = "biz.order.unpaidTimeoutMinutes";

    /** 参数key：买单发起后多少分钟未完成自动取消 */
    private static final String KEY_BILL_TIMEOUT = "biz.bill.pendingTimeoutMinutes";

    /**
     * 默认 30 分钟。微信支付的 prepay_id 有效期是 2 小时，但团购场景用户
     * 是当场决定买不买，超过半小时基本不会再回来付；放太长券就一直锁着。
     */
    private static final int DEFAULT_ORDER_TIMEOUT = 30;

    /** 买单是在店里当面付，比订单更没有「过会儿再付」的场景，同样给 30 分钟 */
    private static final int DEFAULT_BILL_TIMEOUT = 30;

    @Autowired
    private IOrderService orderService;

    @Autowired
    private IPayBillService payBillService;

    @Autowired
    private TaskConfigResolver configResolver;

    /**
     * 不加 @Transactional：订单和买单是两笔独立的清理，其中一边报错
     * 不该把另一边已取消的回滚掉。各自的事务边界在 Service 方法上。
     */
    public void ryNoParams()
    {
        int orderMinutes = configResolver.getPositiveInt(KEY_ORDER_TIMEOUT, DEFAULT_ORDER_TIMEOUT);
        int billMinutes = configResolver.getPositiveInt(KEY_BILL_TIMEOUT, DEFAULT_BILL_TIMEOUT);
        int orders = orderService.cancelTimeoutUnpaid(orderMinutes);
        int bills = payBillService.cancelTimeoutPending(billMinutes);
        log.info("[CancelTimeoutOrderTask] 超时自动取消 orders={}（>{}分钟） bills={}（>{}分钟）",
                orders, orderMinutes, bills, billMinutes);
    }
}
