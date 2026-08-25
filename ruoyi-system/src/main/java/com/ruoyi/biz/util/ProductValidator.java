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
        if (p.getPrice() == null || p.getPrice().compareTo(BigDecimal.ZERO) < 0)
        {
            throw new ServiceException("售价 price 必须 >= 0");
        }
        if (draft)
        {
            // 草稿只保证「能唯一标识一个商品」，其余留给上架前校验。
            // 草稿一律是下架态，小程序端只查 status='0'，不会暴露给用户。
            return;
        }

        String type = p.getTypeCode();
        switch (type)
        {
            case "GROUPON":
                requireNonNull(p.getStock(), "GROUPON 需填库存 stock");
                requireNonNull(p.getValidityDays(), "GROUPON 需填有效期 validityDays");
                requireNonNull(p.getMaxPerOrder(), "GROUPON 需填单次限购 maxPerOrder");
                break;

            case "VOUCHER":
                requireNonNull(p.getFaceValue(), "VOUCHER 需填面值 faceValue");
                requireNonNull(p.getMinConsume(), "VOUCHER 需填最低消费 minConsume");
                requireNonNull(p.getMaxPerOrder(), "VOUCHER 需填单次限购 maxPerOrder");
                if (p.getFaceValue().compareTo(p.getPrice()) < 0)
                {
                    throw new ServiceException("VOUCHER 面值不能小于售价");
                }
                break;

            case "COMBO":
                requireNonNull(p.getTotalValue(), "COMBO 需填总价值 totalValue");
                requireNonNull(p.getValidityDays(), "COMBO 需填有效期 validityDays");
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
                requireNonNull(p.getMaxPerOrder(), "BOOKING 需填单次限购 maxPerOrder");
                requireNonNull(p.getValidityDays(), "BOOKING 需填有效期 validityDays");
                break;

            case "STORED_CARD":
                requireNonNull(p.getFaceValue(), "STORED_CARD 需填面值 faceValue");
                requireNonNull(p.getMinConsume(), "STORED_CARD 需填最低消费 minConsume");
                requireNonNull(p.getValidityDays(), "STORED_CARD 需填有效期 validityDays");
                break;

            case "TIMECARD":
                requireNonNull(p.getTotalTimes(), "TIMECARD 需填总次数 totalTimes");
                requireNonNull(p.getValidityDays(), "TIMECARD 需填有效期 validityDays");
                break;

            case "PERIOD_CARD":
                requireNonNull(p.getPeriodType(), "PERIOD_CARD 需填周期类型 periodType (MONTH/QUARTER/YEAR)");
                requireNonNull(p.getPeriodCount(), "PERIOD_CARD 需填周期数 periodCount");
                requireNonNull(p.getValidityDays(), "PERIOD_CARD 需填有效期 validityDays");
                break;

            default:
                break;
        }
    }

    private static void requireNonNull(Object v, String msg)
    {
        if (v == null) throw new ServiceException(msg);
    }
}
