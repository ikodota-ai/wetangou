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
import com.ruoyi.biz.domain.Order;
import com.ruoyi.biz.api.service.ApiOrderService;
import com.ruoyi.biz.service.IOrderService;
import com.ruoyi.common.utils.poi.ExcelUtil;
import com.ruoyi.common.core.page.TableDataInfo;

/**
 * 订单Controller
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@RestController
@RequestMapping("/biz/order")
public class OrderController extends BaseController
{
    @Autowired
    private IOrderService orderService;

    @Autowired
    private ApiOrderService apiOrderService;

    /**
     * 查询订单列表
     */
    @PreAuthorize("@ss.hasPermi('biz:order:list')")
    @GetMapping("/list")
    public TableDataInfo list(Order order)
    {
        startPage();
        List<Order> list = orderService.selectOrderList(order);
        return getDataTable(list);
    }

    /**
     * 导出订单列表
     */
    @PreAuthorize("@ss.hasPermi('biz:order:export')")
    @Log(title = "订单", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, Order order)
    {
        List<Order> list = orderService.selectOrderList(order);
        ExcelUtil<Order> util = new ExcelUtil<Order>(Order.class);
        util.exportExcel(response, list, "订单数据");
    }

    /**
     * 获取订单详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:order:query')")
    @GetMapping(value = "/{orderId}")
    public AjaxResult getInfo(@PathVariable("orderId") Long orderId)
    {
        return success(orderService.selectOrderByOrderId(orderId));
    }

    /**
     * 新增订单
     */
    @PreAuthorize("@ss.hasPermi('biz:order:add')")
    @Log(title = "订单", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody Order order)
    {
        return toAjax(orderService.insertOrder(order));
    }

    /**
     * 修改订单
     */
    @PreAuthorize("@ss.hasPermi('biz:order:edit')")
    @Log(title = "订单", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody Order order)
    {
        return toAjax(orderService.updateOrder(order));
    }

    /**
     * 删除订单
     */
    @PreAuthorize("@ss.hasPermi('biz:order:remove')")
    @Log(title = "订单", businessType = BusinessType.DELETE)
	@DeleteMapping("/{orderIds}")
    public AjaxResult remove(@PathVariable Long[] orderIds)
    {
        return toAjax(orderService.deleteOrderByOrderIds(orderIds));
    }

    /**
     * 核销订单（后台 web 端：店长/收银员输入核销码）
     *
     * <p>复用 {@link ApiOrderService#verify} 业务逻辑：校验 status=1、未过期，
     * 置为 status=2 + verify_time/verify_user。requirePermi 与 storeId 的额外
     * 校验由调用方（运营/店长）通过 sys_user 的角色限定（biz:order:verify 权限）。</p>
     */
    @PreAuthorize("@ss.hasPermi('biz:order:verify')")
    @Log(title = "订单", businessType = BusinessType.UPDATE)
    @PostMapping("/verify")
    public AjaxResult verify(@RequestBody Order body)
    {
        String verifyCode = body.getVerifyCode();
        if (verifyCode == null || verifyCode.isEmpty())
        {
            throw new com.ruoyi.common.exception.ServiceException("核销码不能为空");
        }
        // 后台不强制 storeId：允许从订单表回填
        Order order = orderService.selectOrderByOrderNo(verifyCode.trim());
        Long storeId = null;
        if (order != null)
        {
            storeId = order.getStoreId();
        }
        else
        {
            // 兼容：部分场景 verifyCode 字段是 orderNo，这里再按 verifyCode 字段查一次
            Order q = new Order();
            q.setVerifyCode(verifyCode.trim());
            java.util.List<Order> list = orderService.selectOrderList(q);
            if (!list.isEmpty())
            {
                order = list.get(0);
                storeId = order.getStoreId();
            }
        }
        if (order == null)
        {
            throw new com.ruoyi.common.exception.ServiceException("核销码无效");
        }
        // 拿当前登录 sys_user 名字作为核销人
        String operator = "";
        try
        {
            operator = com.ruoyi.common.utils.SecurityUtils.getUsername();
        }
        catch (Exception ignore)
        {
        }
        return success(apiOrderService.verify(verifyCode.trim(), storeId, operator));
    }
}
