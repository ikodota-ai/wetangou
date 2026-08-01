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
    @Lazy
    private ISysConfigService sysConfigService;

    /** 参数key：单个时段可接受的预约人数上限 */
    private static final String KEY_SLOT_LIMIT = "biz.booking.slotLimit";

    /** 单时段默认容量，参数未配置时使用 */
    private static final int DEFAULT_SLOT_LIMIT = 10;

    /** 营业时间中提取 HH:mm-HH:mm 的匹配式，兼容「周一至周日 09:00-22:30」这类带前缀的写法 */
    private static final Pattern HOURS_PATTERN = Pattern.compile("(\\d{1,2}):(\\d{2})\\s*[-~至]\\s*(\\d{1,2}):(\\d{2})");

    /** 白天与晚上的分界小时 */
    private static final int NIGHT_START_HOUR = 18;

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
        return bookingMapper.insertBooking(booking);
    }

    @Override
    public int updateBooking(Booking booking)
    {
        booking.setUpdateTime(DateUtils.getNowDate());
        return bookingMapper.updateBooking(booking);
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

        // 已有场次的报名人数按时段汇总，用于计算剩余容量
        Map<String, Integer> bookedPeople = countBookedPeople(storeId, bookingDate);

        // 当天只能约当前时刻之后的时段；非当天不受限
        boolean isToday = queryDate.equals(DateUtils.getDate());
        Calendar now = Calendar.getInstance();
        int nowHour = now.get(Calendar.HOUR_OF_DAY);

        List<Map<String, Object>> day = new ArrayList<Map<String, Object>>();
        List<Map<String, Object>> night = new ArrayList<Map<String, Object>>();
        for (int hour = openHour; hour < closeHour; hour++)
        {
            String time = pad(hour) + ":00";
            int used = bookedPeople.containsKey(time) ? bookedPeople.get(time).intValue() : 0;
            int remain = Math.max(slotLimit - used, 0);
            boolean expired = isToday && hour <= nowHour;

            Map<String, Object> slot = new LinkedHashMap<String, Object>();
            slot.put("time", time);
            slot.put("remain", Integer.valueOf(remain));
            // full 与 expired 分开返回，前端可分别提示「已约满」「已过时」
            slot.put("full", Boolean.valueOf(remain <= 0));
            slot.put("expired", Boolean.valueOf(expired));
            slot.put("available", Boolean.valueOf(remain > 0 && !expired));
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
        result.put("dayRange", buildRange(day));
        result.put("nightRange", buildRange(night));
        result.put("day", day);
        result.put("night", night);
        return result;
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
