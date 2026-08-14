package com.ruoyi.biz.controller;

import java.util.List;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.biz.domain.Booking;
import com.ruoyi.biz.domain.BookingMember;
import com.ruoyi.biz.service.IBookingService;
import com.ruoyi.common.utils.poi.ExcelUtil;
import com.ruoyi.biz.tenant.TenantFilterHelper;
import com.ruoyi.common.core.page.TableDataInfo;

/**
 * 在线预约Controller
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@RestController
@RequestMapping("/biz/booking")
public class BookingController extends BaseController
{
    @Autowired
    private IBookingService bookingService;

    /**
     * 查询在线预约列表
     */
    @PreAuthorize("@ss.hasPermi('biz:booking:list')")
    @GetMapping("/list")
    public TableDataInfo list(Booking booking)
    {
        TenantFilterHelper.apply((com.ruoyi.common.core.domain.BaseEntity) booking,
                                    (b, v) -> ((com.ruoyi.biz.domain.Booking) b).setMerchantId(v),
                                    b -> ((com.ruoyi.biz.domain.Booking) b).getMerchantId());
        startPage();
        List<Booking> list = bookingService.selectBookingList(booking);
        return getDataTable(list);
    }

    /**
     * 导出在线预约列表
     */
    @PreAuthorize("@ss.hasPermi('biz:booking:export')")
    @Log(title = "在线预约", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, Booking booking)
    {
        TenantFilterHelper.apply((com.ruoyi.common.core.domain.BaseEntity) booking,
                                    (b, v) -> ((com.ruoyi.biz.domain.Booking) b).setMerchantId(v),
                                    b -> ((com.ruoyi.biz.domain.Booking) b).getMerchantId());
        List<Booking> list = bookingService.selectBookingList(booking);
        ExcelUtil<Booking> util = new ExcelUtil<Booking>(Booking.class);
        util.exportExcel(response, list, "在线预约数据");
    }

    /**
     * 获取在线预约详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:booking:query')")
    @GetMapping(value = "/{bookingId}")
    public AjaxResult getInfo(@PathVariable("bookingId") Long bookingId)
    {
        return success(bookingService.selectBookingByBookingId(bookingId));
    }

    /**
     * 查询某场次的报名会员明细
     */
    @PreAuthorize("@ss.hasPermi('biz:booking:query')")
    @GetMapping(value = "/members/{bookingId}")
    public AjaxResult members(@PathVariable("bookingId") Long bookingId)
    {
        BookingMember query = new BookingMember();
        query.setBookingId(bookingId);
        return success(bookingService.selectBookingMemberList(query));
    }

    /**
     * 查询预约报名明细列表（分页，支持门店/服务/日期/会员筛选）
     */
    @PreAuthorize("@ss.hasPermi('biz:booking:list')")
    @GetMapping("/member/list")
    public TableDataInfo memberList(BookingMember bookingMember)
    {
        startPage();
        List<BookingMember> list = bookingService.selectBookingMemberList(bookingMember);
        return getDataTable(list);
    }

    /**
     * 导出预约报名明细列表
     */
    @PreAuthorize("@ss.hasPermi('biz:booking:export')")
    @Log(title = "预约明细", businessType = BusinessType.EXPORT)
    @PostMapping("/member/export")
    public void memberExport(HttpServletResponse response, BookingMember bookingMember)
    {
        List<BookingMember> list = bookingService.selectBookingMemberList(bookingMember);
        ExcelUtil<BookingMember> util = new ExcelUtil<BookingMember>(BookingMember.class);
        util.exportExcel(response, list, "预约明细数据");
    }

    /**
     * 新增在线预约
     */
    @PreAuthorize("@ss.hasPermi('biz:booking:add')")
    @Log(title = "在线预约", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody Booking booking)
    {
        if (booking.getBookingNo() == null || booking.getBookingNo().isEmpty())
        {
            booking.setBookingNo("B" + System.currentTimeMillis() + (int) (Math.random() * 900 + 100));
        }
        if (booking.getStatus() == null || booking.getStatus().isEmpty())
        {
            booking.setStatus("0");
        }
        return toAjax(bookingService.insertBooking(booking));
    }

    /**
     * 修改在线预约
     */
    @PreAuthorize("@ss.hasPermi('biz:booking:edit')")
    @Log(title = "在线预约", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody Booking booking)
    {
        return toAjax(bookingService.updateBooking(booking));
    }

    /**
     * 删除在线预约
     */
    @PreAuthorize("@ss.hasPermi('biz:booking:remove')")
    @Log(title = "在线预约", businessType = BusinessType.DELETE)
	@DeleteMapping("/{bookingIds}")
    public AjaxResult remove(@PathVariable Long[] bookingIds)
    {
        return toAjax(bookingService.deleteBookingByBookingIds(bookingIds));
    }
}
