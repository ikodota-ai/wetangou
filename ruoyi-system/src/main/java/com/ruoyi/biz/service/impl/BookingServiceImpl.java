package com.ruoyi.biz.service.impl;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import com.ruoyi.common.utils.DateUtils;
import com.ruoyi.common.utils.StringUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.biz.mapper.BookingMapper;
import com.ruoyi.biz.mapper.BookingMemberMapper;
import com.ruoyi.biz.mapper.StoreMapper;
import com.ruoyi.biz.domain.Booking;
import com.ruoyi.biz.domain.BookingMember;
import com.ruoyi.biz.domain.Store;
import com.ruoyi.biz.service.IBookingService;
import com.ruoyi.system.service.ISysConfigService;

/**
 * 在线预约场次Service业务层处理
 *
 * @author dytuangou
 * @date 2026-07-24
 */
@Service
public class BookingServiceImpl implements IBookingService
{
    @Autowired
    private BookingMapper bookingMapper;

    @Autowired
    private BookingMemberMapper bookingMemberMapper;

    @Autowired
    private StoreMapper storeMapper;

    @Autowired
    private com.ruoyi.biz.mapper.ProductMapper productMapper;

    @Autowired
    @Lazy
    private ISysConfigService sysConfigService;

    /** 未挂商品时的预约项目名兜底 */
    private static final String DEFAULT_ITEM_NAME = "在线预约";

    /** 参数key：单个时段可接受的预约人数上限 */
    private static final String KEY_SLOT_LIMIT = "biz.booking.slotLimit";

    /** 单时段默认容量，参数未配置时使用 */
    private static final int DEFAULT_SLOT_LIMIT = 10;

    /** 营业时间中提取 HH:mm-HH:mm 的匹配式，兼容「周一至周日 09:00-22:30」这类带前缀的写法 */
    private static final Pattern HOURS_PATTERN = Pattern.compile("(\\d{1,2}):(\\d{2})\\s*[-~至]\\s*(\\d{1,2}):(\\d{2})");

    /** 白天与晚上的分界小时 */
    private static final int NIGHT_START_HOUR = 18;

    /** 可提前预约天数默认值（与小程序原先写死的 getNextDays(7) 一致） */
    private static final int DEFAULT_AHEAD_DAYS = 7;

    /** 可提前预约天数上限 */
    private static final int MAX_AHEAD_DAYS = 60;

    /** 时段粒度默认值（分钟）：60 即改造前的整点展开 */
    private static final int DEFAULT_SLOT_MINUTES = 60;

    @Override
    public Booking selectBookingByBookingId(Long bookingId)
    {
        Booking booking = bookingMapper.selectBookingByBookingId(bookingId);
        if (booking != null)
        {
            BookingMember query = new BookingMember();
            query.setBookingId(bookingId);
            booking.setBookingMembers(bookingMemberMapper.selectBookingMemberList(query));
        }
        return booking;
    }

    @Override
    public List<Booking> selectBookingList(Booking booking)
    {
        return bookingMapper.selectBookingList(booking);
    }

    @Override
    public int insertBooking(Booking booking)
    {
        booking.setCreateTime(DateUtils.getNowDate());
        applyItemName(booking);
        return bookingMapper.insertBooking(booking);
    }

    @Override
    public int updateBooking(Booking booking)
    {
        booking.setUpdateTime(DateUtils.getNowDate());
        applyItemName(booking);
        return bookingMapper.updateBooking(booking);
    }

    /**
     * 预约项目名收口：一律按 product_id 查商品名写 service_name。
     *
     * <p>放在 Service 而不是 controller，是因为写入有两条路：后台
     * BookingController.add/edit 和小程序 ApiBookingController.create。
     * 只在小程序侧派生的话，后台新建的场次 service_name 会是空字符串 ——
     * 列表「预约项目」那一列什么都不显示（实测过）。</p>
     *
     * <p>原先 service_name 是自由文本，存的是字典 biz_booking_type 的类型名
     * （「堂食预约」），和真正上架的预约商品是两回事：商家在后台上架了
     * 「SPA理疗60分钟」，预约单上却只写着「堂食预约」，product_id 是 NULL。</p>
     *
     * <p>updateBooking 里也要跑：编辑时把项目换成另一个商品，项目名必须跟着换，
     * 否则库里会留下「product_id 指向 A、service_name 写着 B」的错位数据。
     * 但 productId 为 null 时不动 service_name —— 后台改状态/备注这类
     * 局部更新不传 productId，无脑覆盖会把项目名冲成「在线预约」。</p>
     */
    private void applyItemName(Booking booking)
    {
        if (booking == null || booking.getProductId() == null)
        {
            return;
        }
        com.ruoyi.biz.domain.Product product =
                productMapper.selectProductByProductId(booking.getProductId());
        if (product == null)
        {
            throw new com.ruoyi.common.exception.ServiceException("预约项目不存在或已下架");
        }
        booking.setServiceName(StringUtils.isEmpty(product.getProductName())
                ? DEFAULT_ITEM_NAME : product.getProductName());
    }

    @Override
    @Transactional
    public int deleteBookingByBookingIds(Long[] bookingIds)
    {
        bookingMemberMapper.deleteBookingMemberByBookingIds(bookingIds);
        return bookingMapper.deleteBookingByBookingIds(bookingIds);
    }

    @Override
    @Transactional
    public int deleteBookingByBookingId(Long bookingId)
    {
        bookingMemberMapper.deleteBookingMemberByBookingIds(new Long[] { bookingId });
        return bookingMapper.deleteBookingByBookingId(bookingId);
    }

    @Override
    public List<BookingMember> selectBookingMemberList(BookingMember bookingMember)
    {
        return bookingMemberMapper.selectBookingMemberList(bookingMember);
    }

    @Override
    public BookingMember selectBookingMemberById(Long id)
    {
        return bookingMemberMapper.selectBookingMemberById(id);
    }

    @Override
    public int signup(BookingMember bookingMember)
    {
        if (bookingMember.getPeople() == null || bookingMember.getPeople() < 1)
        {
            bookingMember.setPeople(1);
        }
        if (bookingMember.getStatus() == null)
        {
            bookingMember.setStatus("0");
        }
        bookingMember.setCreateTime(DateUtils.getNowDate());
        return bookingMemberMapper.insertBookingMember(bookingMember);
    }

    @Override
    public int updateBookingMember(BookingMember bookingMember)
    {
        bookingMember.setUpdateTime(DateUtils.getNowDate());
        return bookingMemberMapper.updateBookingMember(bookingMember);
    }

    @Override
    public Map<String, Object> selectAvailableSlots(Long storeId, String date)
    {
        Store store = storeMapper.selectStoreByStoreId(storeId);
        if (store == null)
        {
            throw new com.ruoyi.common.exception.ServiceException("门店不存在");
        }
        String queryDate = StringUtils.isEmpty(date) ? DateUtils.getDate() : date;
        Date bookingDate = parseDate(queryDate);

        int[] range = parseBusinessHours(store.getBusinessHours());
        int openHour = range[0];
        int closeHour = range[1];
        int slotLimit = resolveSlotLimit();
        int stepMinutes = resolveSlotMinutes(store);

        // 已有场次的报名人数按时段汇总，用于计算剩余容量
        Map<String, Integer> bookedPeople = countBookedPeople(storeId, bookingDate);

        // 当天只能约当前时刻之后的时段；非当天不受限
        boolean isToday = queryDate.equals(DateUtils.getDate());
        Calendar now = Calendar.getInstance();
        int nowMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE);

        // 歇业日 / 超出可提前预约范围时，整天不开放。
        // 仍然把时段列出来（标 closed），而不是返回空数组 ——
        // 前端空数组只能显示「暂无时段」，用户不知道是歇业还是没配营业时间。
        boolean closedDay = isClosedDay(store, bookingDate);
        boolean outOfRange = !isWithinAheadRange(store, queryDate);

        List<Map<String, Object>> day = new ArrayList<Map<String, Object>>();
        List<Map<String, Object>> night = new ArrayList<Map<String, Object>>();
        for (int minutes = openHour * 60; minutes < closeHour * 60; minutes += stepMinutes)
        {
            int hour = minutes / 60;
            String time = pad(hour) + ":" + pad2(minutes % 60);
            int used = bookedPeople.containsKey(time) ? bookedPeople.get(time).intValue() : 0;
            int remain = Math.max(slotLimit - used, 0);
            // 过时判断改用「分钟」比较：粒度 30 分钟时，用小时比会把
            // 同一小时内还没到的 11:30 也当成已过时
            boolean expired = isToday && minutes <= nowMinutes;

            Map<String, Object> slot = new LinkedHashMap<String, Object>();
            slot.put("time", time);
            slot.put("remain", Integer.valueOf(remain));
            // full / expired / closed 分开返回，前端可分别提示
            // 「已约满」「已过时」「今日歇业」
            slot.put("full", Boolean.valueOf(remain <= 0));
            slot.put("expired", Boolean.valueOf(expired));
            slot.put("closed", Boolean.valueOf(closedDay || outOfRange));
            slot.put("available", Boolean.valueOf(remain > 0 && !expired && !closedDay && !outOfRange));
            if (hour < NIGHT_START_HOUR)
            {
                day.add(slot);
            }
            else
            {
                night.add(slot);
            }
        }

        Map<String, Object> result = new LinkedHashMap<String, Object>();
        result.put("storeId", storeId);
        result.put("storeName", store.getStoreName());
        result.put("date", queryDate);
        result.put("businessHours", store.getBusinessHours());
        result.put("slotLimit", Integer.valueOf(slotLimit));
        result.put("slotMinutes", Integer.valueOf(stepMinutes));
        result.put("closedDay", Boolean.valueOf(closedDay));
        result.put("outOfRange", Boolean.valueOf(outOfRange));
        // 整天不可约时给出原因，前端直接展示，不用自己拼文案
        result.put("closedReason", closedDay ? "本店当日歇业" : (outOfRange ? "超出可预约日期范围" : ""));
        result.put("dayRange", buildRange(day));
        result.put("nightRange", buildRange(night));
        result.put("day", day);
        result.put("night", night);
        return result;
    }

    /**
     * 可预约日期列表（供小程序渲染日期选择条）
     *
     * <p>原先小程序写死 getNextDays(7)，运营既不能收窄成「只接今天和明天」，
     * 也不能放宽成「提前半个月」，更没法把歇业日排除掉 —— 门店周一休息，
     * 顾客照样能选到周一，提交后才被拒。现在天数取门店
     * booking_ahead_days，并给每天标出 closed 与原因。</p>
     */
    @Override
    public Map<String, Object> selectBookableDays(Long storeId)
    {
        Store store = storeMapper.selectStoreByStoreId(storeId);
        if (store == null)
        {
            throw new com.ruoyi.common.exception.ServiceException("门店不存在");
        }
        int aheadDays = resolveAheadDays(store);

        java.text.SimpleDateFormat ymd = new java.text.SimpleDateFormat("yyyy-MM-dd");
        java.text.SimpleDateFormat md = new java.text.SimpleDateFormat("MM-dd");
        String[] weekLabels = new String[] { "周一", "周二", "周三", "周四", "周五", "周六", "周日" };

        Calendar cursor = Calendar.getInstance();
        cursor.set(Calendar.HOUR_OF_DAY, 0);
        cursor.set(Calendar.MINUTE, 0);
        cursor.set(Calendar.SECOND, 0);
        cursor.set(Calendar.MILLISECOND, 0);

        List<Map<String, Object>> days = new ArrayList<Map<String, Object>>();
        int openCount = 0;
        for (int i = 0; i < aheadDays; i++)
        {
            Date d = cursor.getTime();
            boolean closed = isClosedDay(store, d);
            int iso = toIsoWeekday(d);

            Map<String, Object> item = new LinkedHashMap<String, Object>();
            item.put("date", ymd.format(d));
            item.put("label", md.format(d));
            item.put("weekday", Integer.valueOf(iso));
            item.put("weekdayText", i == 0 ? "今天" : (i == 1 ? "明天" : weekLabels[iso - 1]));
            item.put("closed", Boolean.valueOf(closed));
            item.put("closedReason", closed ? "歇业" : "");
            days.add(item);
            if (!closed)
            {
                openCount++;
            }
            cursor.add(Calendar.DAY_OF_MONTH, 1);
        }

        Map<String, Object> result = new LinkedHashMap<String, Object>();
        result.put("storeId", storeId);
        result.put("storeName", store.getStoreName());
        result.put("aheadDays", Integer.valueOf(aheadDays));
        result.put("slotMinutes", Integer.valueOf(resolveSlotMinutes(store)));
        result.put("closedDays", store.getBookingClosedDays() == null ? "" : store.getBookingClosedDays());
        result.put("openCount", Integer.valueOf(openCount));
        result.put("days", days);
        return result;
    }

    /**
     * 提交预约前的服务端校验：日期在可约范围内、不是歇业日、时段真在营业时间里。
     *
     * <p>为什么必须有：可约范围原先只在小程序端拦（日期条置灰、时段标 closed）。
     * 实测直接 POST /api/booking 绕过界面，歇业日、超出可提前天数的日期、
     * 已经过去的日期、营业时间之外的 03:00、甚至「随便填」这种非时段字符串，
     * 后端一律返 200 落库。而 selectBookableDays 的注释里写着
     * 「顾客照样能选到周一，提交后才被拒」—— 实际上从来没被拒过。</p>
     *
     * <p>校验依据与 selectAvailableSlots / selectBookableDays 完全同源
     * （同样的 resolveAheadDays / isClosedDay / isWithinAheadRange /
     * parseBusinessHours / resolveSlotMinutes），避免出现「界面允许但提交被拒」
     * 或反过来的不一致。</p>
     *
     * @param storeId  门店
     * @param date     预约日期 yyyy-MM-dd
     * @param timeSlot 时段，形如 "10:00" 或 "10:00-11:00"（取起始时刻）
     */
    @Override
    public void assertSlotBookable(Long storeId, String date, String timeSlot)
    {
        Store store = storeMapper.selectStoreByStoreId(storeId);
        if (store == null)
        {
            throw new com.ruoyi.common.exception.ServiceException("门店不存在");
        }
        if (StringUtils.isEmpty(date))
        {
            throw new com.ruoyi.common.exception.ServiceException("预约日期不能为空");
        }
        // 日期格式先卡住：yyyy-MM-dd 之外的写法后面按范围算会得到错误结论
        Date bookingDate;
        try
        {
            java.text.SimpleDateFormat ymd = new java.text.SimpleDateFormat("yyyy-MM-dd");
            ymd.setLenient(false);
            bookingDate = ymd.parse(date);
        }
        catch (Exception e)
        {
            throw new com.ruoyi.common.exception.ServiceException("预约日期格式不正确");
        }

        if (!isWithinAheadRange(store, date))
        {
            throw new com.ruoyi.common.exception.ServiceException(
                    "该日期不可预约，本店最多可提前 " + resolveAheadDays(store) + " 天预约");
        }
        if (isClosedDay(store, bookingDate))
        {
            throw new com.ruoyi.common.exception.ServiceException("本店当日歇业，请选择其他日期");
        }

        // 时段：必须能解析出 HH:mm，且落在营业时间内、对齐到配置的粒度
        String start = startOf(timeSlot);
        if (StringUtils.isEmpty(start) || !start.matches("\\d{1,2}:\\d{2}"))
        {
            throw new com.ruoyi.common.exception.ServiceException("预约时段格式不正确");
        }
        String[] hm = start.split(":");
        int minutes;
        try
        {
            minutes = Integer.parseInt(hm[0]) * 60 + Integer.parseInt(hm[1]);
        }
        catch (NumberFormatException e)
        {
            throw new com.ruoyi.common.exception.ServiceException("预约时段格式不正确");
        }
        int[] range = parseBusinessHours(store.getBusinessHours());
        int openMinutes = range[0] * 60;
        int closeMinutes = range[1] * 60;
        if (minutes < openMinutes || minutes >= closeMinutes)
        {
            throw new com.ruoyi.common.exception.ServiceException(
                    "该时段不在营业时间内（" + pad(range[0]) + ":00-" + pad(range[1]) + ":00）");
        }
        int step = resolveSlotMinutes(store);
        if ((minutes - openMinutes) % step != 0)
        {
            throw new com.ruoyi.common.exception.ServiceException(
                    "该时段不可选，本店按 " + step + " 分钟为一档开放预约");
        }

        // 当天不能约已经过去的时段（前端标 expired，后端同样要兜底）
        if (date.equals(DateUtils.getDate()))
        {
            Calendar now = Calendar.getInstance();
            int nowMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE);
            if (minutes <= nowMinutes)
            {
                throw new com.ruoyi.common.exception.ServiceException("该时段已过，请选择更晚的时段");
            }
        }

        // 容量：与 selectAvailableSlots 的 remain 同一套算法
        Map<String, Integer> booked = countBookedPeople(storeId, bookingDate);
        int used = booked.containsKey(start) ? booked.get(start).intValue() : 0;
        if (used >= resolveSlotLimit())
        {
            throw new com.ruoyi.common.exception.ServiceException("该时段已约满，请选择其他时段");
        }
    }

    /**
     * 门店可提前预约天数，非法值回退 7（与小程序原先写死的 7 天一致，保证升级后行为不变）
     */
    private int resolveAheadDays(Store store)
    {
        Integer v = store.getBookingAheadDays();
        if (v == null || v.intValue() < 1)
        {
            return DEFAULT_AHEAD_DAYS;
        }
        // 上限 60：再长的排期没有业务意义，且会让前端日期条渲染上百个元素
        return Math.min(v.intValue(), MAX_AHEAD_DAYS);
    }

    /**
     * 时段粒度，非法值回退 60（整点，与改造前行为一致）
     *
     * <p>必须做兜底：粒度参与 {@code minutes += stepMinutes} 的循环步长，
     * 取到 0 或负数会直接死循环把线程占满。</p>
     */
    private int resolveSlotMinutes(Store store)
    {
        Integer v = store.getBookingSlotMinutes();
        if (v == null)
        {
            return DEFAULT_SLOT_MINUTES;
        }
        int m = v.intValue();
        // 只认这几档：任意分钟数会切出 07:13 这类没人会填的时间
        if (m == 15 || m == 30 || m == 60 || m == 120)
        {
            return m;
        }
        return DEFAULT_SLOT_MINUTES;
    }

    /**
     * 该日期是否落在门店歇业日上
     */
    private boolean isClosedDay(Store store, Date date)
    {
        String conf = store.getBookingClosedDays();
        if (StringUtils.isEmpty(conf) || date == null)
        {
            return false;
        }
        int iso = toIsoWeekday(date);
        for (String part : conf.split(","))
        {
            String t = part.trim();
            if (t.isEmpty())
            {
                continue;
            }
            try
            {
                if (Integer.parseInt(t) == iso)
                {
                    return true;
                }
            }
            catch (NumberFormatException e)
            {
                // 脏数据（例如存了「周一」）忽略，不能因此让整个预约页报错
            }
        }
        return false;
    }

    /**
     * 目标日期是否在「今天 ~ 今天+可提前天数-1」范围内
     *
     * <p>过去的日期同样算越界 —— 否则顾客改一下请求参数就能约到昨天。</p>
     */
    private boolean isWithinAheadRange(Store store, String queryDate)
    {
        try
        {
            java.text.SimpleDateFormat ymd = new java.text.SimpleDateFormat("yyyy-MM-dd");
            ymd.setLenient(false);
            Date target = ymd.parse(queryDate);
            Date today = ymd.parse(DateUtils.getDate());
            long diffDays = (target.getTime() - today.getTime()) / (24L * 60L * 60L * 1000L);
            return diffDays >= 0 && diffDays < resolveAheadDays(store);
        }
        catch (Exception e)
        {
            // 日期格式异常时不拦，交由既有 parseDate 的行为处理
            return true;
        }
    }

    /**
     * java.util.Calendar 的 DAY_OF_WEEK 是 1=周日，业务侧统一用 ISO 的 1=周一
     */
    private int toIsoWeekday(Date date)
    {
        Calendar c = Calendar.getInstance();
        c.setTime(date);
        int dow = c.get(Calendar.DAY_OF_WEEK);
        return dow == Calendar.SUNDAY ? 7 : dow - 1;
    }

    /**
     * 汇总门店某天各时段的已报名人数
     *
     * <p>时段字段存的是「11:00-12:00」这类文本，此处按起始时刻归并，
     * 便于与按小时切分出来的候选时段对齐。</p>
     */
    private Map<String, Integer> countBookedPeople(Long storeId, Date bookingDate)
    {
        Map<String, Integer> counter = new HashMap<String, Integer>();
        Booking query = new Booking();
        query.setStoreId(storeId);
        query.setBookingDate(bookingDate);
        List<Booking> list = bookingMapper.selectBookingList(query);
        for (Booking booking : list)
        {
            // 已取消的场次不占用容量
            if ("3".equals(booking.getStatus()))
            {
                continue;
            }
            String start = startOf(booking.getTimeSlot());
            if (start == null)
            {
                continue;
            }
            int people = booking.getSignupPeople() == null ? 0 : booking.getSignupPeople().intValue();
            Integer exists = counter.get(start);
            counter.put(start, Integer.valueOf((exists == null ? 0 : exists.intValue()) + people));
        }
        return counter;
    }

    /**
     * 取时段文本的起始时刻，统一为 HH:mm
     */
    private String startOf(String timeSlot)
    {
        if (StringUtils.isEmpty(timeSlot))
        {
            return null;
        }
        Matcher matcher = Pattern.compile("(\\d{1,2}):(\\d{2})").matcher(timeSlot);
        if (!matcher.find())
        {
            return null;
        }
        return pad(Integer.parseInt(matcher.group(1))) + ":" + matcher.group(2);
    }

    /**
     * 解析门店营业时间为起止小时，解析失败时回退 10:00-22:00
     */
    private int[] parseBusinessHours(String businessHours)
    {
        int open = 10;
        int close = 22;
        if (StringUtils.isNotEmpty(businessHours))
        {
            Matcher matcher = HOURS_PATTERN.matcher(businessHours);
            if (matcher.find())
            {
                open = Integer.parseInt(matcher.group(1));
                close = Integer.parseInt(matcher.group(3));
                // 收档分钟数大于0时仍算作可约到该小时之前，故不做进位
                if (close <= open)
                {
                    // 跨天营业（如 18:00-02:00）按当天营业到 24 点处理
                    close = 24;
                }
            }
        }
        return new int[] { open, Math.min(close, 24) };
    }

    /**
     * 读取单时段容量参数，非法或未配置时用默认值
     */
    private int resolveSlotLimit()
    {
        try
        {
            String value = sysConfigService.selectConfigByKey(KEY_SLOT_LIMIT);
            if (StringUtils.isNotEmpty(value))
            {
                int limit = Integer.parseInt(value.trim());
                if (limit > 0)
                {
                    return limit;
                }
            }
        }
        catch (Exception e)
        {
            // 参数配置异常不应影响预约页展示，走默认容量
        }
        return DEFAULT_SLOT_LIMIT;
    }

    /**
     * 拼接分组时间范围文本，供前端「白天 11:00-17:00」这类标签展示
     */
    private String buildRange(List<Map<String, Object>> slots)
    {
        if (slots.isEmpty())
        {
            return "";
        }
        return slots.get(0).get("time") + "-" + slots.get(slots.size() - 1).get("time");
    }

    private String pad(int hour)
    {
        return hour < 10 ? "0" + hour : String.valueOf(hour);
    }

    /**
     * 分钟补零。粒度为 30 时要输出 "11:30"，为 60 时输出 "11:00"
     */
    private String pad2(int minute)
    {
        return minute < 10 ? "0" + minute : String.valueOf(minute);
    }

    private Date parseDate(String date)
    {
        try
        {
            return new SimpleDateFormat("yyyy-MM-dd").parse(date);
        }
        catch (ParseException e)
        {
            throw new com.ruoyi.common.exception.ServiceException("预约日期格式应为 yyyy-MM-dd");
        }
    }
}
