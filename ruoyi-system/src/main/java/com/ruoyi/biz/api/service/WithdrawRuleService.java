package com.ruoyi.biz.api.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Service;

import com.ruoyi.biz.domain.Withdraw;
import com.ruoyi.biz.service.IWithdrawService;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.service.ISysConfigService;

/**
 * 提现规则（起提金额 / 每日次数 / 受理时段 / 手续费 / 到账时效）
 *
 * <p>做这一层的直接原因是微信小程序审核驳回：
 * 「小程序服务涉及提现服务，需在提现页面清晰展示相关提现规则，包括但不限于
 * 可提现额度、每日提现次数、提现时间、到账时间等」。</p>
 *
 * <p>但光在页面上贴一段文案是过不了的 —— 原本后端 /api/distributor/withdraw
 * 只校验「金额&gt;0 且不超可提现余额」，起提金额、每日次数、受理时段这些规则
 * 压根不存在。页面写「单笔最低 10 元」而实际提 0.01 元照样成功，属于
 * 展示与实际不符，二审一样会被打回，也会被用户当成 bug。所以规则先在服务端
 * 真实生效，展示接口再从同一处读，两边不可能对不上。</p>
 *
 * <p>全部走 sys_config，后台「提现规则」页可改，改完即时生效。取值非法或缺失
 * 时一律回落到默认值，不能因为少配一个 key 就把提现整条链卡死。</p>
 *
 * @author dytuangou
 */
@Service
public class WithdrawRuleService
{
    /** 单笔最低提现金额（元） */
    public static final String KEY_MIN_AMOUNT = "withdraw.minAmount";

    /** 单笔最高提现金额（元），0=不限 */
    public static final String KEY_MAX_AMOUNT = "withdraw.maxAmount";

    /** 每日提现次数上限，0=不限 */
    public static final String KEY_DAILY_TIMES = "withdraw.dailyTimes";

    /** 受理开始小时（0-23） */
    public static final String KEY_START_HOUR = "withdraw.startHour";

    /** 受理结束小时（1-24），与开始小时相等表示全天受理 */
    public static final String KEY_END_HOUR = "withdraw.endHour";

    /** 手续费率（百分比，0=免手续费） */
    public static final String KEY_FEE_RATE = "withdraw.feeRate";

    /** 到账时效说明（纯文案） */
    public static final String KEY_ARRIVAL_DESC = "withdraw.arrivalDesc";

    private static final BigDecimal DEFAULT_MIN_AMOUNT = new BigDecimal("10.00");
    private static final BigDecimal DEFAULT_MAX_AMOUNT = new BigDecimal("5000.00");
    private static final int DEFAULT_DAILY_TIMES = 3;
    private static final int DEFAULT_START_HOUR = 9;
    private static final int DEFAULT_END_HOUR = 21;
    private static final BigDecimal DEFAULT_FEE_RATE = BigDecimal.ZERO;
    private static final String DEFAULT_ARRIVAL_DESC = "审核通过后 1-3 个工作日到账";

    @Autowired
    @Lazy
    private ISysConfigService sysConfigService;

    @Autowired
    @Lazy
    private IWithdrawService withdrawService;

    // ------------------------------------------------------------------ 取值

    /** 单笔最低提现金额，非法值回落 10 元 */
    public BigDecimal getMinAmount()
    {
        BigDecimal v = readDecimal(KEY_MIN_AMOUNT, DEFAULT_MIN_AMOUNT);
        // 起提金额必须为正，配 0 或负数等于没有下限，直接回落默认值
        return v.compareTo(BigDecimal.ZERO) > 0 ? v : DEFAULT_MIN_AMOUNT;
    }

    /** 单笔最高提现金额，返回 0 表示不限 */
    public BigDecimal getMaxAmount()
    {
        BigDecimal v = readDecimal(KEY_MAX_AMOUNT, DEFAULT_MAX_AMOUNT);
        return v.compareTo(BigDecimal.ZERO) < 0 ? DEFAULT_MAX_AMOUNT : v;
    }

    /** 每日提现次数上限，返回 0 表示不限 */
    public int getDailyTimes()
    {
        int v = readInt(KEY_DAILY_TIMES, DEFAULT_DAILY_TIMES);
        return v < 0 ? DEFAULT_DAILY_TIMES : v;
    }

    /** 受理开始小时，越界回落 9 点 */
    public int getStartHour()
    {
        int v = readInt(KEY_START_HOUR, DEFAULT_START_HOUR);
        return (v >= 0 && v <= 23) ? v : DEFAULT_START_HOUR;
    }

    /** 受理结束小时，越界回落 21 点 */
    public int getEndHour()
    {
        int v = readInt(KEY_END_HOUR, DEFAULT_END_HOUR);
        return (v >= 1 && v <= 24) ? v : DEFAULT_END_HOUR;
    }

    /** 手续费率（%），越界回落 0（免手续费） */
    public BigDecimal getFeeRate()
    {
        BigDecimal v = readDecimal(KEY_FEE_RATE, DEFAULT_FEE_RATE);
        if (v.compareTo(BigDecimal.ZERO) < 0 || v.compareTo(new BigDecimal("100")) >= 0)
        {
            return DEFAULT_FEE_RATE;
        }
        return v;
    }

    /** 到账时效文案 */
    public String getArrivalDesc()
    {
        String v = sysConfigService.selectConfigByKey(KEY_ARRIVAL_DESC);
        return StringUtils.isEmpty(v) ? DEFAULT_ARRIVAL_DESC : v.trim();
    }

    /** 受理时段是否覆盖全天（开始==结束，或 0-24） */
    public boolean isAllDay()
    {
        int start = getStartHour();
        int end = getEndHour();
        return start == end || (start == 0 && end == 24);
    }

    // ------------------------------------------------------------------ 校验

    /**
     * 申请提现前的规则校验。任何一条不满足直接抛 ServiceException，
     * 文案与页面展示的规则逐条对应，用户能立刻知道是哪一条挡住了。
     *
     * @param distributorId 推客ID
     * @param amount        本次申请金额
     * @param available     当前可提现余额
     */
    public void validate(Long distributorId, BigDecimal amount, BigDecimal available)
    {
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0)
        {
            throw new ServiceException("提现金额不合法");
        }
        BigDecimal min = getMinAmount();
        if (amount.compareTo(min) < 0)
        {
            throw new ServiceException("单笔最低提现 " + trim(min) + " 元");
        }
        BigDecimal max = getMaxAmount();
        if (max.compareTo(BigDecimal.ZERO) > 0 && amount.compareTo(max) > 0)
        {
            throw new ServiceException("单笔最高提现 " + trim(max) + " 元");
        }
        if (available == null || amount.compareTo(available) > 0)
        {
            throw new ServiceException("可提现余额不足");
        }
        if (!isWithinServiceHours(new Date()))
        {
            throw new ServiceException("提现受理时间为每日 " + getStartHour() + ":00-" + getEndHour()
                    + ":00，请在该时段内申请");
        }
        int limit = getDailyTimes();
        if (limit > 0)
        {
            int used = countTodayApplied(distributorId);
            if (used >= limit)
            {
                throw new ServiceException("今日提现次数已达上限（每日 " + limit + " 次）");
            }
        }
    }

    /** 当前时刻是否在受理时段内 */
    public boolean isWithinServiceHours(Date now)
    {
        if (isAllDay())
        {
            return true;
        }
        Calendar cal = Calendar.getInstance();
        cal.setTime(now == null ? new Date() : now);
        int hour = cal.get(Calendar.HOUR_OF_DAY);
        int start = getStartHour();
        int end = getEndHour();
        if (start < end)
        {
            return hour >= start && hour < end;
        }
        // 跨零点时段（如 22:00-次日 6:00）
        return hour >= start || hour < end;
    }

    /**
     * 今日已提交的提现笔数。
     *
     * <p>只排除「已驳回」(status=2)：驳回的钱已退回余额、不该占用次数额度。
     * 处理中(0) 和 已成功(1) 都算，否则用户可以在审核期间无限次提交。</p>
     */
    public int countTodayApplied(Long distributorId)
    {
        if (distributorId == null)
        {
            return 0;
        }
        Withdraw query = new Withdraw();
        query.setDistributorId(distributorId);
        List<Withdraw> list = withdrawService.selectWithdrawList(query);
        if (list == null || list.isEmpty())
        {
            return 0;
        }
        Date dayStart = startOfToday();
        int count = 0;
        for (Withdraw w : list)
        {
            if ("2".equals(w.getStatus()))
            {
                continue;
            }
            Date t = w.getApplyTime() == null ? w.getCreateTime() : w.getApplyTime();
            if (t != null && !t.before(dayStart))
            {
                count++;
            }
        }
        return count;
    }

    /** 今日剩余可提现次数，返回 -1 表示不限次 */
    public int remainingTimes(Long distributorId)
    {
        int limit = getDailyTimes();
        if (limit <= 0)
        {
            return -1;
        }
        int left = limit - countTodayApplied(distributorId);
        return left < 0 ? 0 : left;
    }

    /** 手续费金额（向下取整到分，避免多扣用户 1 分钱） */
    public BigDecimal calcFee(BigDecimal amount)
    {
        BigDecimal rate = getFeeRate();
        if (amount == null || rate.compareTo(BigDecimal.ZERO) <= 0)
        {
            return BigDecimal.ZERO;
        }
        return amount.multiply(rate)
                .divide(new BigDecimal("100"), 2, RoundingMode.DOWN);
    }

    // ------------------------------------------------------------------ 展示

    /**
     * 供小程序提现页展示的规则集合。
     *
     * <p>结构化字段给前端做金额/次数校验与文案拼接，rules 是给用户看的完整条款
     * 列表 —— 微信审核要的就是这一条：规则必须在提现页面上看得见。</p>
     *
     * @param distributorId 推客ID，可为空（未成为推客时只看通用规则）
     * @param available     可提现余额，可为空
     */
    public Map<String, Object> describe(Long distributorId, BigDecimal available)
    {
        BigDecimal min = getMinAmount();
        BigDecimal max = getMaxAmount();
        int dailyTimes = getDailyTimes();
        BigDecimal feeRate = getFeeRate();
        boolean allDay = isAllDay();
        String serviceHours = allDay ? "每日 00:00-24:00（全天受理）"
                : "每日 " + getStartHour() + ":00-" + getEndHour() + ":00";

        Map<String, Object> data = new LinkedHashMap<String, Object>();
        data.put("minAmount", min);
        data.put("maxAmount", max);
        data.put("dailyTimes", dailyTimes);
        data.put("usedTimes", distributorId == null ? 0 : countTodayApplied(distributorId));
        data.put("remainingTimes", distributorId == null ? dailyTimes : remainingTimes(distributorId));
        data.put("startHour", getStartHour());
        data.put("endHour", getEndHour());
        data.put("allDay", allDay);
        data.put("serviceHours", serviceHours);
        data.put("withinServiceHours", isWithinServiceHours(new Date()));
        data.put("feeRate", feeRate);
        data.put("arrivalDesc", getArrivalDesc());
        data.put("availableAmount", available == null ? BigDecimal.ZERO : available);

        List<String> rules = new ArrayList<String>();
        rules.add("可提现额度：仅「可提现余额」内的金额可申请，佣金需经订单冷静期结算后才会转入可提现余额。");
        rules.add("单笔额度：单笔最低 " + trim(min) + " 元"
                + (max.compareTo(BigDecimal.ZERO) > 0 ? "，单笔最高 " + trim(max) + " 元。" : "，不限单笔上限。"));
        rules.add("每日次数：" + (dailyTimes > 0 ? "每个账号每日最多可提现 " + dailyTimes + " 次，次日 00:00 重置。"
                : "不限提现次数。"));
        rules.add("提现时间：" + serviceHours + " 受理提现申请，非受理时段可先查询余额，次日受理。");
        rules.add("到账时间：" + getArrivalDesc() + "，具体到账以收款渠道（微信零钱 / 支付宝 / 银行卡）实际处理时间为准。");
        rules.add("手续费：" + (feeRate.compareTo(BigDecimal.ZERO) > 0
                ? "按提现金额收取 " + trim(feeRate) + "%，从提现金额中扣除。" : "本平台不收取提现手续费。"));
        rules.add("提现审核：申请提交后对应金额立即冻结并进入平台审核；审核通过后按上述时效打款，若被驳回，冻结金额将全额退回可提现余额。");
        rules.add("收款信息：请确保收款账号与收款人姓名真实一致，因信息填写错误导致的打款失败或转账至他人账户，需重新发起申请。");
        data.put("rules", rules);
        return data;
    }

    // ------------------------------------------------------------------ 工具

    private BigDecimal readDecimal(String key, BigDecimal fallback)
    {
        String v = sysConfigService.selectConfigByKey(key);
        if (StringUtils.isEmpty(v))
        {
            return fallback;
        }
        try
        {
            return new BigDecimal(v.trim());
        }
        catch (NumberFormatException e)
        {
            // 后台是数字输入框，但 sys_config 可以被人手工改成 "十元"，
            // 解析失败不能让整个提现页 500，回落默认值即可
            return fallback;
        }
    }

    private int readInt(String key, int fallback)
    {
        String v = sysConfigService.selectConfigByKey(key);
        if (StringUtils.isEmpty(v))
        {
            return fallback;
        }
        try
        {
            return Integer.parseInt(v.trim());
        }
        catch (NumberFormatException e)
        {
            return fallback;
        }
    }

    private static Date startOfToday()
    {
        Calendar cal = Calendar.getInstance();
        cal.set(Calendar.HOUR_OF_DAY, 0);
        cal.set(Calendar.MINUTE, 0);
        cal.set(Calendar.SECOND, 0);
        cal.set(Calendar.MILLISECOND, 0);
        return cal.getTime();
    }

    /** 去掉无意义的小数尾零：10.00 -> 10，2.50 -> 2.5 */
    private static String trim(BigDecimal v)
    {
        if (v == null)
        {
            return "0";
        }
        return v.stripTrailingZeros().toPlainString();
    }
}
