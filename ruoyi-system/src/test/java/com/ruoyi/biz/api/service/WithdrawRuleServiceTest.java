package com.ruoyi.biz.api.service;

import java.lang.reflect.Field;
import java.lang.reflect.Proxy;
import java.math.BigDecimal;
import java.util.Calendar;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import com.ruoyi.biz.service.IWithdrawService;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.service.ISysConfigService;

/**
 * 提现规则单测
 *
 * <p>为什么值得护住：微信审核驳回「提现页面需清晰展示提现规则」，我们的做法是
 * 让展示接口和申请校验读同一个 WithdrawRuleService。这个前提一旦破了 ——
 * 比如有人给 getMinAmount 换了个默认值、或把非法值兜底删掉 ——
 * 就会回到「页面写最低 10 元、实际提 1 元也能过」的状态，二审必挂。
 * 所以这里锁住三件事：</p>
 *
 * <ul>
 *   <li>缺配置 / 配非法值时的兜底，必须与升级脚本里的种子值一致</li>
 *   <li>validate 逐条拦得住，且异常文案与页面展示的规则同源</li>
 *   <li>受理时段跨零点、每日次数排除已驳回，这两个易错分支</li>
 * </ul>
 *
 * <p>不起 Spring、不连库：sysConfigService 与 withdrawService 都用动态代理桩。</p>
 */
@DisplayName("提现规则: 取值兜底与申请校验")
class WithdrawRuleServiceTest
{
    /** 造一个按 map 返回 sys_config 的 WithdrawRuleService；提现记录为空 */
    private WithdrawRuleService build(Map<String, String> configs) throws Exception
    {
        return build(configs, java.util.Collections.emptyList());
    }

    private WithdrawRuleService build(Map<String, String> configs, List<?> withdraws) throws Exception
    {
        WithdrawRuleService svc = new WithdrawRuleService();
        ISysConfigService cfgStub = (ISysConfigService) Proxy.newProxyInstance(
                ISysConfigService.class.getClassLoader(),
                new Class<?>[]{ISysConfigService.class},
                (proxy, method, args) -> {
                    if ("selectConfigByKey".equals(method.getName()) && args != null && args.length == 1)
                    {
                        return configs.get(String.valueOf(args[0]));
                    }
                    Class<?> rt = method.getReturnType();
                    if (rt == boolean.class) return false;
                    if (rt == int.class) return 0;
                    return null;
                });
        IWithdrawService wStub = (IWithdrawService) Proxy.newProxyInstance(
                IWithdrawService.class.getClassLoader(),
                new Class<?>[]{IWithdrawService.class},
                (proxy, method, args) -> {
                    if ("selectWithdrawList".equals(method.getName()))
                    {
                        return withdraws;
                    }
                    Class<?> rt = method.getReturnType();
                    if (rt == boolean.class) return false;
                    if (rt == int.class) return 0;
                    return null;
                });
        set(svc, "sysConfigService", cfgStub);
        set(svc, "withdrawService", wStub);
        return svc;
    }

    private static void set(Object target, String field, Object value) throws Exception
    {
        Field f = target.getClass().getDeclaredField(field);
        f.setAccessible(true);
        f.set(target, value);
    }

    private static Map<String, String> cfg(String... kv)
    {
        Map<String, String> m = new HashMap<String, String>();
        for (int i = 0; i + 1 < kv.length; i += 2)
        {
            m.put(kv[i], kv[i + 1]);
        }
        return m;
    }

    @Test
    @DisplayName("缺配置时回落到默认值，且与升级脚本种子一致")
    void defaultsMatchSqlSeed() throws Exception
    {
        WithdrawRuleService svc = build(cfg());
        // sql/upgrade/biz_withdraw_rule_20260903.sql 里种的就是这几个值，
        // 「库里没配」与「库里配了默认值」两种情况行为必须完全一致
        Assertions.assertEquals(0, svc.getMinAmount().compareTo(new BigDecimal("10")));
        Assertions.assertEquals(0, svc.getMaxAmount().compareTo(new BigDecimal("5000")));
        Assertions.assertEquals(3, svc.getDailyTimes());
        Assertions.assertEquals(9, svc.getStartHour());
        Assertions.assertEquals(21, svc.getEndHour());
        Assertions.assertEquals(0, svc.getFeeRate().compareTo(BigDecimal.ZERO));
        Assertions.assertEquals("审核通过后 1-3 个工作日到账", svc.getArrivalDesc());
    }

    @Test
    @DisplayName("非法值不透传：起提额 0/负数、小时越界、费率越界都回落默认")
    void illegalValuesFallBack() throws Exception
    {
        // 起提额配 0 等于没有下限，这正是微信驳回想避免的「规则形同虚设」
        Assertions.assertEquals(0, build(cfg(WithdrawRuleService.KEY_MIN_AMOUNT, "0"))
                .getMinAmount().compareTo(new BigDecimal("10")));
        Assertions.assertEquals(0, build(cfg(WithdrawRuleService.KEY_MIN_AMOUNT, "-5"))
                .getMinAmount().compareTo(new BigDecimal("10")));
        // sys_config 可被手工改成中文
        Assertions.assertEquals(0, build(cfg(WithdrawRuleService.KEY_MIN_AMOUNT, "十元"))
                .getMinAmount().compareTo(new BigDecimal("10")));
        Assertions.assertEquals(9, build(cfg(WithdrawRuleService.KEY_START_HOUR, "99")).getStartHour());
        Assertions.assertEquals(21, build(cfg(WithdrawRuleService.KEY_END_HOUR, "0")).getEndHour());
        Assertions.assertEquals(0, build(cfg(WithdrawRuleService.KEY_FEE_RATE, "120"))
                .getFeeRate().compareTo(BigDecimal.ZERO));
        Assertions.assertEquals(3, build(cfg(WithdrawRuleService.KEY_DAILY_TIMES, "-1")).getDailyTimes());
    }

    @Test
    @DisplayName("0=不限：单笔上限与每日次数可关闭")
    void zeroMeansUnlimited() throws Exception
    {
        WithdrawRuleService svc = build(cfg(
                WithdrawRuleService.KEY_MAX_AMOUNT, "0",
                WithdrawRuleService.KEY_DAILY_TIMES, "0",
                WithdrawRuleService.KEY_START_HOUR, "0",
                WithdrawRuleService.KEY_END_HOUR, "24"));
        Assertions.assertEquals(0, svc.getMaxAmount().compareTo(BigDecimal.ZERO));
        Assertions.assertEquals(0, svc.getDailyTimes());
        Assertions.assertEquals(-1, svc.remainingTimes(1L), "不限次时剩余次数返回 -1");
        // 上限=0 时提 1 万也不该被单笔上限挡住
        Assertions.assertDoesNotThrow(() ->
                svc.validate(1L, new BigDecimal("10000"), new BigDecimal("10000")));
    }

    @Test
    @DisplayName("validate 逐条拦截，异常文案与页面展示同源")
    void validateRejects() throws Exception
    {
        WithdrawRuleService svc = build(cfg(
                WithdrawRuleService.KEY_START_HOUR, "0",
                WithdrawRuleService.KEY_END_HOUR, "24"));
        BigDecimal balance = new BigDecimal("10000");

        Assertions.assertThrows(ServiceException.class, () -> svc.validate(1L, null, balance));
        Assertions.assertThrows(ServiceException.class, () -> svc.validate(1L, BigDecimal.ZERO, balance));
        Assertions.assertThrows(ServiceException.class, () -> svc.validate(1L, new BigDecimal("-1"), balance));

        ServiceException tooSmall = Assertions.assertThrows(ServiceException.class,
                () -> svc.validate(1L, new BigDecimal("1"), balance));
        Assertions.assertTrue(tooSmall.getMessage().contains("单笔最低提现 10 元"), tooSmall.getMessage());

        ServiceException tooBig = Assertions.assertThrows(ServiceException.class,
                () -> svc.validate(1L, new BigDecimal("99999"), balance));
        Assertions.assertTrue(tooBig.getMessage().contains("单笔最高提现 5000 元"), tooBig.getMessage());

        ServiceException noMoney = Assertions.assertThrows(ServiceException.class,
                () -> svc.validate(1L, new BigDecimal("100"), new BigDecimal("50")));
        Assertions.assertTrue(noMoney.getMessage().contains("余额不足"), noMoney.getMessage());

        Assertions.assertDoesNotThrow(() -> svc.validate(1L, new BigDecimal("100"), balance));
    }

    @Test
    @DisplayName("受理时段：普通时段 / 全天 / 跨零点")
    void serviceHours() throws Exception
    {
        WithdrawRuleService day = build(cfg(
                WithdrawRuleService.KEY_START_HOUR, "9",
                WithdrawRuleService.KEY_END_HOUR, "21"));
        Assertions.assertTrue(day.isWithinServiceHours(at(10)));
        Assertions.assertFalse(day.isWithinServiceHours(at(8)));
        // 21:00 整已过受理窗口，用 < end 而不是 <=，否则 21:30 也会被放进来
        Assertions.assertFalse(day.isWithinServiceHours(at(21)));
        Assertions.assertFalse(day.isAllDay());

        WithdrawRuleService allDay = build(cfg(
                WithdrawRuleService.KEY_START_HOUR, "0",
                WithdrawRuleService.KEY_END_HOUR, "24"));
        Assertions.assertTrue(allDay.isAllDay());
        Assertions.assertTrue(allDay.isWithinServiceHours(at(3)));

        // 起止相同也按全天处理，避免运营填成 9-9 时全天没人能提现
        WithdrawRuleService same = build(cfg(
                WithdrawRuleService.KEY_START_HOUR, "9",
                WithdrawRuleService.KEY_END_HOUR, "9"));
        Assertions.assertTrue(same.isAllDay());
        Assertions.assertTrue(same.isWithinServiceHours(at(3)));

        // 跨零点时段 22:00 - 次日 6:00
        WithdrawRuleService night = build(cfg(
                WithdrawRuleService.KEY_START_HOUR, "22",
                WithdrawRuleService.KEY_END_HOUR, "6"));
        Assertions.assertTrue(night.isWithinServiceHours(at(23)));
        Assertions.assertTrue(night.isWithinServiceHours(at(2)));
        Assertions.assertFalse(night.isWithinServiceHours(at(12)));
    }

    @Test
    @DisplayName("每日次数只算今天，且已驳回的不占用额度")
    void dailyTimesCounting() throws Exception
    {
        List<com.ruoyi.biz.domain.Withdraw> list = new java.util.ArrayList<>();
        list.add(withdraw("0", at(10)));            // 今天 处理中 → 计
        list.add(withdraw("1", at(11)));            // 今天 已成功 → 计
        list.add(withdraw("2", at(12)));            // 今天 已驳回 → 钱已退回，不该占额度
        list.add(withdraw("1", yesterday()));       // 昨天 → 不计

        WithdrawRuleService svc = build(cfg(WithdrawRuleService.KEY_DAILY_TIMES, "3"), list);
        Assertions.assertEquals(2, svc.countTodayApplied(1L));
        Assertions.assertEquals(1, svc.remainingTimes(1L));

        // 必须显式放开受理时段：默认是 9:00-21:00，而 validate 先校验时段再校验次数。
        // 不固定的话，凡是在 21:00 后或 9:00 前跑 CI，抛出来的是「不在受理时间」，
        // 这条本意测「次数上限」的断言就会莫名其妙变红（实测 23:42 复现）。
        WithdrawRuleService full = build(cfg(
                WithdrawRuleService.KEY_DAILY_TIMES, "2",
                WithdrawRuleService.KEY_START_HOUR, "0",
                WithdrawRuleService.KEY_END_HOUR, "24"), list);
        Assertions.assertEquals(0, full.remainingTimes(1L));
        ServiceException e = Assertions.assertThrows(ServiceException.class,
                () -> full.validate(1L, new BigDecimal("100"), new BigDecimal("1000")));
        Assertions.assertTrue(e.getMessage().contains("今日提现次数已达上限"), e.getMessage());
    }

    @Test
    @DisplayName("describe 覆盖微信点名的 4 类规则，且展示值与校验值同源")
    void describeCoversAuditRequirements() throws Exception
    {
        WithdrawRuleService svc = build(cfg(
                WithdrawRuleService.KEY_MIN_AMOUNT, "20",
                WithdrawRuleService.KEY_DAILY_TIMES, "5",
                WithdrawRuleService.KEY_START_HOUR, "0",
                WithdrawRuleService.KEY_END_HOUR, "24"));
        Map<String, Object> data = svc.describe(1L, new BigDecimal("300"));

        @SuppressWarnings("unchecked")
        List<String> rules = (List<String>) data.get("rules");
        String joined = String.join("", rules);
        // 微信驳回原文点名的四项，缺一不可
        Assertions.assertTrue(joined.contains("可提现额度"), joined);
        Assertions.assertTrue(joined.contains("每日次数"), joined);
        Assertions.assertTrue(joined.contains("提现时间"), joined);
        Assertions.assertTrue(joined.contains("到账时间"), joined);

        // 展示的数字必须就是 validate 用的数字，否则又回到「页面写一套、实际另一套」
        Assertions.assertEquals(0, ((BigDecimal) data.get("minAmount")).compareTo(new BigDecimal("20")));
        Assertions.assertTrue(joined.contains("单笔最低 20 元"), joined);
        Assertions.assertEquals(5, data.get("dailyTimes"));
        ServiceException e = Assertions.assertThrows(ServiceException.class,
                () -> svc.validate(1L, new BigDecimal("19"), new BigDecimal("300")));
        Assertions.assertTrue(e.getMessage().contains("20"), e.getMessage());
    }

    @Test
    @DisplayName("手续费向下取整到分，费率 0 时不收费")
    void feeCalculation() throws Exception
    {
        Assertions.assertEquals(0, build(cfg()).calcFee(new BigDecimal("100")).compareTo(BigDecimal.ZERO));
        WithdrawRuleService svc = build(cfg(WithdrawRuleService.KEY_FEE_RATE, "1.5"));
        Assertions.assertEquals(0, svc.calcFee(new BigDecimal("100")).compareTo(new BigDecimal("1.50")));
        // 33.33 * 1.5% = 0.49995，向下取整到 0.49，宁可少收也不多扣用户的钱
        Assertions.assertEquals(0, svc.calcFee(new BigDecimal("33.33")).compareTo(new BigDecimal("0.49")));
    }

    // ---------------------------------------------------------------- helper

    private static Date at(int hour)
    {
        Calendar c = Calendar.getInstance();
        c.set(Calendar.HOUR_OF_DAY, hour);
        c.set(Calendar.MINUTE, 0);
        c.set(Calendar.SECOND, 0);
        c.set(Calendar.MILLISECOND, 0);
        return c.getTime();
    }

    private static Date yesterday()
    {
        Calendar c = Calendar.getInstance();
        c.add(Calendar.DAY_OF_MONTH, -1);
        return c.getTime();
    }

    private static com.ruoyi.biz.domain.Withdraw withdraw(String status, Date applyTime)
    {
        com.ruoyi.biz.domain.Withdraw w = new com.ruoyi.biz.domain.Withdraw();
        w.setStatus(status);
        w.setApplyTime(applyTime);
        return w;
    }
}
