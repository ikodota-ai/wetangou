package com.ruoyi.biz.service.impl;

import java.lang.reflect.Method;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;

import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import com.ruoyi.biz.domain.Store;

/**
 * 门店级预约可约范围的边界单测（第 6 项）
 *
 * <p>这里刻意不起 Spring / 不连库：被测的四个方法都是纯计算
 * （天数兜底、粒度兜底、歇业日解析、可约范围判定），用反射直接调，
 * 无库环境也能跑，CI 上不会被 @EnabledIf 跳过 —— 而这几条恰恰是
 * 最需要长期护住的：</p>
 *
 * <ul>
 *   <li>粒度兜底如果失效，{@code minutes += stepMinutes} 步长会取到 0，
 *       整个预约页请求直接死循环把线程占满，比返回错数据严重得多。</li>
 *   <li>歇业日用 ISO 1=周一，而 {@code Calendar.DAY_OF_WEEK} 是 1=周日，
 *       这个换算错一位就会把周日的歇业配置作用到周六。</li>
 *   <li>可约范围要拦住过去的日期，否则顾客改一下 date 参数就能约到昨天。</li>
 * </ul>
 */
@DisplayName("第6项: 门店预约可约范围边界")
class BookingRuleTest
{
    private final BookingServiceImpl service = new BookingServiceImpl();

    private Object call(String name, Class<?>[] types, Object... args) throws Exception
    {
        Method m = BookingServiceImpl.class.getDeclaredMethod(name, types);
        m.setAccessible(true);
        return m.invoke(service, args);
    }

    private int aheadDays(Integer configured) throws Exception
    {
        Store s = new Store();
        s.setBookingAheadDays(configured);
        return ((Integer) call("resolveAheadDays", new Class<?>[] { Store.class }, s)).intValue();
    }

    private int slotMinutes(Integer configured) throws Exception
    {
        Store s = new Store();
        s.setBookingSlotMinutes(configured);
        return ((Integer) call("resolveSlotMinutes", new Class<?>[] { Store.class }, s)).intValue();
    }

    private boolean closedOn(String closedDays, Date date) throws Exception
    {
        Store s = new Store();
        s.setBookingClosedDays(closedDays);
        return ((Boolean) call("isClosedDay", new Class<?>[] { Store.class, Date.class }, s, date)).booleanValue();
    }

    private boolean withinRange(Integer ahead, String date) throws Exception
    {
        Store s = new Store();
        s.setBookingAheadDays(ahead);
        return ((Boolean) call("isWithinAheadRange", new Class<?>[] { Store.class, String.class }, s, date)).booleanValue();
    }

    /** 相对今天偏移 n 天的 yyyy-MM-dd */
    private String dayOffset(int n)
    {
        Calendar c = Calendar.getInstance();
        c.add(Calendar.DAY_OF_MONTH, n);
        return new SimpleDateFormat("yyyy-MM-dd").format(c.getTime());
    }

    /** 找到未来 7 天内 ISO 星期为 iso 的那一天 */
    private Date nextDateWithIsoWeekday(int iso)
    {
        Calendar c = Calendar.getInstance();
        for (int i = 0; i < 8; i++)
        {
            int dow = c.get(Calendar.DAY_OF_WEEK);
            int cur = dow == Calendar.SUNDAY ? 7 : dow - 1;
            if (cur == iso)
            {
                return c.getTime();
            }
            c.add(Calendar.DAY_OF_MONTH, 1);
        }
        throw new IllegalStateException("unreachable");
    }

    @Test
    @DisplayName("可提前天数：null/0/负数回退 7，超过 60 夹到 60")
    void aheadDaysFallback() throws Exception
    {
        // 回退值必须是 7：小程序原先写死 getNextDays(7)，
        // 升级后没配过的门店行为要保持不变
        Assertions.assertEquals(7, aheadDays(null));
        Assertions.assertEquals(7, aheadDays(Integer.valueOf(0)));
        Assertions.assertEquals(7, aheadDays(Integer.valueOf(-3)));
        Assertions.assertEquals(1, aheadDays(Integer.valueOf(1)));
        Assertions.assertEquals(30, aheadDays(Integer.valueOf(30)));
        Assertions.assertEquals(60, aheadDays(Integer.valueOf(60)));
        Assertions.assertEquals(60, aheadDays(Integer.valueOf(999)));
    }

    @Test
    @DisplayName("时段粒度：只认 15/30/60/120，其余回退 60（0 会导致死循环）")
    void slotMinutesFallback() throws Exception
    {
        Assertions.assertEquals(15, slotMinutes(Integer.valueOf(15)));
        Assertions.assertEquals(30, slotMinutes(Integer.valueOf(30)));
        Assertions.assertEquals(60, slotMinutes(Integer.valueOf(60)));
        Assertions.assertEquals(120, slotMinutes(Integer.valueOf(120)));
        // 下面这几个是关键：步长取 0 或负数会让 slots 循环永不结束
        Assertions.assertEquals(60, slotMinutes(null));
        Assertions.assertEquals(60, slotMinutes(Integer.valueOf(0)));
        Assertions.assertEquals(60, slotMinutes(Integer.valueOf(-30)));
        // 非枚举值（会切出 07:13 这类时间）也回退
        Assertions.assertEquals(60, slotMinutes(Integer.valueOf(7)));
        Assertions.assertEquals(60, slotMinutes(Integer.valueOf(45)));
    }

    @Test
    @DisplayName("歇业日：空/null 表示每天可约")
    void closedDaysEmpty() throws Exception
    {
        Assertions.assertFalse(closedOn(null, new Date()));
        Assertions.assertFalse(closedOn("", new Date()));
        Assertions.assertFalse(closedOn("   ", new Date()));
    }

    @Test
    @DisplayName("歇业日：ISO 1=周一 … 7=周日，不能和 Calendar 的 1=周日串位")
    void closedDaysIsoWeekday() throws Exception
    {
        for (int iso = 1; iso <= 7; iso++)
        {
            Date d = nextDateWithIsoWeekday(iso);
            Assertions.assertTrue(closedOn(String.valueOf(iso), d),
                    "iso=" + iso + " 配成歇业日却没命中");
            // 只配这一天时，其它 6 天都不能被误判成歇业
            for (int other = 1; other <= 7; other++)
            {
                if (other == iso)
                {
                    continue;
                }
                Assertions.assertFalse(closedOn(String.valueOf(other), d),
                        "iso=" + iso + " 被 other=" + other + " 误判为歇业（星期换算串位）");
            }
        }
    }

    @Test
    @DisplayName("歇业日：多选逗号分隔，脏数据不影响其余项")
    void closedDaysMultiAndDirty() throws Exception
    {
        Date monday = nextDateWithIsoWeekday(1);
        Date wednesday = nextDateWithIsoWeekday(3);
        Date friday = nextDateWithIsoWeekday(5);

        Assertions.assertTrue(closedOn("1,3", monday));
        Assertions.assertTrue(closedOn("1,3", wednesday));
        Assertions.assertFalse(closedOn("1,3", friday));

        // 后台历史上可能存了中文，脏数据要被忽略而不是让整个预约页 500
        Assertions.assertTrue(closedOn("周一,3", wednesday));
        Assertions.assertFalse(closedOn("周一,周三", wednesday));
        // 多余空格 / 空项
        Assertions.assertTrue(closedOn(" 1 , ,3 ", monday));
    }

    @Test
    @DisplayName("可约范围：今天算在内，越界与过去日期都要拦")
    void aheadRange() throws Exception
    {
        // ahead=1 只能约当天
        Assertions.assertTrue(withinRange(Integer.valueOf(1), dayOffset(0)));
        Assertions.assertFalse(withinRange(Integer.valueOf(1), dayOffset(1)));

        // ahead=3 → 今天 / +1 / +2 可约，+3 越界
        Assertions.assertTrue(withinRange(Integer.valueOf(3), dayOffset(0)));
        Assertions.assertTrue(withinRange(Integer.valueOf(3), dayOffset(2)));
        Assertions.assertFalse(withinRange(Integer.valueOf(3), dayOffset(3)));
        Assertions.assertFalse(withinRange(Integer.valueOf(3), dayOffset(30)));

        // 过去的日期一律拦掉：否则改一下 date 参数就能约到昨天
        Assertions.assertFalse(withinRange(Integer.valueOf(7), dayOffset(-1)));
        Assertions.assertFalse(withinRange(Integer.valueOf(7), dayOffset(-30)));

        // 没配时按默认 7 天
        Assertions.assertTrue(withinRange(null, dayOffset(6)));
        Assertions.assertFalse(withinRange(null, dayOffset(7)));
    }
}
