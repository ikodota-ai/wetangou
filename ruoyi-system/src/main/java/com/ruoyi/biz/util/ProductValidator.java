package com.ruoyi.biz.util;

import com.ruoyi.biz.domain.Product;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.bean.BeanUtils;
import java.math.BigDecimal;
import java.lang.reflect.Method;
import java.util.List;

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
    /** 上架 */
    public static final String STATUS_ON = "0";
    /** 下架 / 草稿 */
    public static final String STATUS_OFF = "1";

    /** 非上架态一律当草稿：字段允许不全 */
    public static boolean isDraft(Product product)
    {
        return product == null || !STATUS_ON.equals(product.getStatus());
    }

    /**
     * 把局部请求体盖到数据库原值上，得到「这次更新之后库里会长什么样」。
     *
     * <p>为什么要反射逐属性合并：updateProduct 的 SQL 对每个字段都是
     * {@code <if test="xxx != null">} 的局部更新，未提交的字段保留原值。
     * 校验必须和这套持久化语义完全对齐，否则会出现两个方向的错：
     * <ul>
     *   <li>只改一两个字段的局部 PUT（商品搭配抽屉只提交 productId + 明细）
     *       会因为 typeCode/productName 为 null 被判「不能为空」而存不进去，
     *       尽管这两个字段在库里明明是好的；</li>
     *   <li>反方向更隐蔽：status 没带时会被判成草稿，于是一个已上架商品能靠
     *       「不带 status 的局部 PUT」把售价改成 0 绕过上架校验，
     *       顾客侧就会看到点进去下不了单的商品。</li>
     * </ul>
     *
     * <p>这段原先是 admin 端 ProductController 的 private static，小程序商家端
     * 的 edit 端点因此复用不到，完全不做校验 —— 商家在手机上把已上架商品的
     * 价格改成 0 是能存下去的。商品维护主场景在商家端，两端必须同一套规则，
     * 所以下沉到这里。</p>
     *
     * <p>直接改 {@code origin} 不影响落库：真正写进数据库的是 incoming，
     * origin 只是这一次请求里用来做校验的临时视图。</p>
     */
    public static Product mergeOntoOrigin(Product origin, Product incoming)
    {
        if (origin == null) return incoming;
        if (incoming == null) return origin;
        try
        {
            List<Method> setters = BeanUtils.getSetterMethods(origin);
            for (Method getter : BeanUtils.getGetterMethods(incoming))
            {
                Object value = getter.invoke(incoming);
                // null 表示「这次没提交这个字段」，保留 origin 的原值
                if (value == null)
                {
                    continue;
                }
                for (Method setter : setters)
                {
                    if (BeanUtils.isMethodPropEquals(getter.getName(), setter.getName())
                            && setter.getParameterTypes()[0].isAssignableFrom(getter.getReturnType()))
                    {
                        setter.invoke(origin, value);
                        break;
                    }
                }
            }
        }
        catch (Exception e)
        {
            // 合并失败就退回请求体本身：宁可校验严一点报错，也不能静默放过非法数据
            return incoming;
        }
        return origin;
    }

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
