package com.ruoyi.quartz.task;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import com.ruoyi.biz.service.IBookingService;

/**
 * 过期预约场次自动关闭
 *
 * <p>为什么必须有：门店排出场次后不会回头手工关闭，于是</p>
 * <ul>
 *   <li>后台预约列表按状态筛「开放中」会混进一堆历史日期的场次（实测本地
 *       30 个场次全部是过期的却都停在 status='0'）；</li>
 *   <li>会员端「我的预约」的状态文案由场次 status 和报名 status 组合算出，
 *       场次没关、报名还是「已报名」，去年那条预约就永远显示「待确认」，
 *       用户以为门店还没理他。</li>
 * </ul>
 *
 * <p>只关 booking_date &lt; 今天 的场次：当天的不能关，晚上的时段白天还能约。</p>
 *
 * <p>Quartz 调用：{@code closeOverdueBookingTask.ryNoParams()}，建议 Cron
 * 每天 00:10（{@code 0 10 0 * * ?}）—— 跨过零点再跑，避免恰好卡在
 * 日期切换的瞬间把今天的场次算成过期。</p>
 *
 * @author dytuangou
 */
@Component("closeOverdueBookingTask")
public class CloseOverdueBookingTask
{
    private static final Logger log = LoggerFactory.getLogger(CloseOverdueBookingTask.class);

    @Autowired
    private IBookingService bookingService;

    public void ryNoParams()
    {
        int[] result = bookingService.closeOverdueBookings();
        log.info("[CloseOverdueBookingTask] 过期场次关闭 bookings={} 报名取消 members={}",
                result[0], result[1]);
    }
}
