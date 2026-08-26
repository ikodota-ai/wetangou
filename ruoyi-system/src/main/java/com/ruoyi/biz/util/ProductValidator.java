package com.ruoyi.biz.util;

import com.ruoyi.biz.domain.Product;
import com.ruoyi.common.exception.ServiceException;
import java.math.BigDecimal;

/**
 * 商品创建/编辑时的类型必填校验
 *
 * <p>不同 typeCode 有不同的必填字段：
 * <ul>
 *   <li>GROUPON（团购套餐）：price、stock、validityDays、maxPerOrder</li>
 *   <li>VOUCHER（代金券）：faceValue、minConsume、maxPerOrder</li>
 *   <li>COMBO（组合券包）：totalValue、validityDays、subitemPickRule</li>
 *   <li>BOOKING（预约服务）：bookingRequired=1、maxPerOrder、validityDays</li>
 *   <li>STORED_CARD（储值卡）：faceValue、minConsume、validityDays</li>
 *   <li>TIMECARD（次卡）：totalTimes、validityDays</li>
 *   <li>PERIOD_CARD（周期卡）：periodType、periodCount、validityDays</li>
 * </ul>
 */
public class ProductValidator
{
    /**
     * 完整校验（上架用）
     */
    public static void validate(Product p)
    {
        validate(p, false);
    }

    /**
     * 校验基础字段（草稿也必须满足）
     *
     * <p>为什么要区分草稿：admin 的「商品高级编辑」是分段式 ——
     * 第 1 步只填品类/类型/名称就要落库拿 productId，后面的 tab 才填库存、
     * 有效期、单次限购。若第 1 步就跑完整校验，会出现死锁：
     * 保存需要 stock → stock 在第 2 步 → 第 2 步需要 productId → productId 要先保存成功。
     * 结果是一个商品都建不出来。</p>
     *
     * @param draft true 时只校验基础字段，跳过按类型的必填项
     */
    public static void validate(Product p, boolean draft)
    {
        if (p == null) throw new ServiceException("商品为空");
        if (p.getTypeCode() == null || p.getTypeCode().isEmpty())
        {
            throw new ServiceException("商品类型 typeCode 不能为空");
        }
        if (p.getProductName() == null || p.getProductName().trim().isEmpty())
        {
            throw new ServiceException("商品名称不能为空");
        }
        // 填了就必须合法；没填留到上架前校验。
        // 售价输入框在第 2 步「售卖信息」tab，第 1 步拿不到值，
        // 若这里要求非空，会和「保存后才有 productId」形成死锁。
        if (p.getPrice() != null && p.getPrice().compareTo(BigDecimal.ZERO) < 0)
        {
            throw new ServiceException("售价 price 必须 >= 0");
        }
        if (draft)
        {
            // 草稿只保证「能唯一标识一个商品」，其余留给上架前校验。
            // 草稿一律是下架态，小程序端只查 status='0'，不会暴露给用户。
            return;
        }
        // 注意判 0 而不只是 null：price 建表带 DEFAULT '0.00'，没填在库里就是 0。
        // 0 元商品若真要做，应当走专门的免费领取活动，而不是普通商品上架。
        if (p.getPrice() == null || p.getPrice().compareTo(BigDecimal.ZERO) <= 0)
        {
            throw new ServiceException("上架前必须填写售价 price（且需大于 0）");
        }

        String type = p.getTypeCode();
        switch (type)
        {
            case "GROUPON":
                requirePositive(p.getStock(), "GROUPON 需填库存 stock");
                requirePositive(p.getValidityDays(), "GROUPON 需填有效期 validityDays");
                requirePositive(p.getMaxPerOrder(), "GROUPON 需填单次限购 maxPerOrder");
                break;

            case "VOUCHER":
                requirePositiveAmount(p.getFaceValue(), "VOUCHER 需填面值 faceValue");
                requireNonNull(p.getMinConsume(), "VOUCHER 需填最低消费 minConsume");
                requirePositive(p.getMaxPerOrder(), "VOUCHER 需填单次限购 maxPerOrder");
                if (p.getFaceValue().compareTo(p.getPrice()) < 0)
                {
                    throw new ServiceException("VOUCHER 面值不能小于售价");
                }
                break;

            case "COMBO":
                requirePositiveAmount(p.getTotalValue(), "COMBO 需填总价值 totalValue");
                requirePositive(p.getValidityDays(), "COMBO 需填有效期 validityDays");
                if (p.getSubitemPickRule() == null || p.getSubitemPickRule().trim().isEmpty())
                {
                    throw new ServiceException("COMBO 需填搭配规则 subitemPickRule");
                }
                break;

            case "BOOKING":
                if (p.getBookingRequired() == null || p.getBookingRequired() != 1)
                {
                    throw new ServiceException("BOOKING 类型必须设 bookingRequired=1");
                }
                requirePositive(p.getMaxPerOrder(), "BOOKING 需填单次限购 maxPerOrder");
                requirePositive(p.getValidityDays(), "BOOKING 需填有效期 validityDays");
                break;

            case "STORED_CARD":
                requirePositiveAmount(p.getFaceValue(), "STORED_CARD 需填面值 faceValue");
                requireNonNull(p.getMinConsume(), "STORED_CARD 需填最低消费 minConsume");
                requirePositive(p.getValidityDays(), "STORED_CARD 需填有效期 validityDays");
                break;

            case "TIMECARD":
                requirePositive(p.getTotalTimes(), "TIMECARD 需填总次数 totalTimes");
                requirePositive(p.getValidityDays(), "TIMECARD 需填有效期 validityDays");
                break;

            case "PERIOD_CARD":
                requireNonNull(p.getPeriodType(), "PERIOD_CARD 需填周期类型 periodType (MONTH/QUARTER/YEAR)");
                requirePositive(p.getPeriodCount(), "PERIOD_CARD 需填周期数 periodCount");
                requirePositive(p.getValidityDays(), "PERIOD_CARD 需填有效期 validityDays");
                break;

            default:
                break;
        }
    }

    private static void requireNonNull(Object v, String msg)
    {
        if (v == null) throw new ServiceException(msg);
    }

    /**
     * 数量型字段「必须填且必须 &gt; 0」。
     *
     * <p>不能只判 null：biz_product 的 price / stock / validity_days /
     * max_per_order / face_value 在建表时都带了 DEFAULT（0、0、30、1、0.00），
     * 所以「用户没填」在库里表现为 0 而不是 null，只判 null 永远拦不住。
     * 后果是库存 0、售价 0 的残缺商品能通过上架校验暴露给顾客：
     * 商品在小程序可见、可点进详情，但下单必然失败（库存不足），
     * 顾客只会认为"这家店的小程序是坏的"。</p>
     */
    private static void requirePositive(Number v, String msg)
    {
        if (v == null || v.longValue() <= 0) throw new ServiceException(msg);
    }

    /** 金额型字段「必须填且必须 &gt; 0」，同样是因为建表带了 DEFAULT '0.00' */
    private static void requirePositiveAmount(BigDecimal v, String msg)
    {
        if (v == null || v.compareTo(BigDecimal.ZERO) <= 0) throw new ServiceException(msg);
    }
}
