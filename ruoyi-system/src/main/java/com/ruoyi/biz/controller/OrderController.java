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
import com.ruoyi.biz.api.service.ApiOrderServiceImpl;
import com.ruoyi.biz.service.IOrderService;
import com.ruoyi.common.utils.poi.ExcelUtil;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.core.domain.model.TenantContext;
import com.ruoyi.common.utils.TenantContextHolder;

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
    private ApiOrderServiceImpl apiOrderService;

    /**
     * 查询订单列表
     */

    /**
     * 按当前租户上下文强制设置订单查询过滤条件（A1 防跨租户泄漏）
     *
     * <ul>
     *   <li>平台账号（userType=0）：不强制，覆盖全平台</li>
     *   <li>代理商账号（userType=1）：强制限定到名下商户集合，agent_id 不能由前端覆盖</li>
     *   <li>商户账号（userType=2）：强制限定到自己的 merchant_id，前端传的 merchantId 须一致</li>
     * </ul>
     */
    private void applyTenantFilter(Order order)
    {
        TenantContext ctx = TenantContextHolder.get();
        if (ctx == null || ctx.isPlatform()) {
            return;
        }
        if (ctx.isAgent()) {
            List<Long> ids = ctx.getMerchantIds();
            if (ids == null || ids.isEmpty()) {
                // 代理商名下无商户 → 强制返回空集
                order.getParams().put("merchantIdsIn", "-1");
                return;
            }
            // 覆盖前端传的 merchantId，强制限定到名下商户
            order.getParams().put("merchantIdsIn", ids);
            return;
        }
        if (ctx.isMerchant()) {
            Long mid = ctx.getMerchantId();
            // 商户强制按 token 的 merchantId 过滤；前端若传 merchantId 须一致
            if (order.getMerchantId() != null && !order.getMerchantId().equals(mid)) {
                throw new com.ruoyi.common.exception.ServiceException("无权查询其他商户的订单");
            }
            order.setMerchantId(mid);
            return;
        }
    }
    @PreAuthorize("@ss.hasPermi('biz:order:list')")
    @GetMapping("/list")
    public TableDataInfo list(Order order)
    {
        applyTenantFilter(order);
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
        applyTenantFilter(order);
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
     * <p>复用 {@link ApiOrderServiceImpl#verify} 业务逻辑：校验 status=1、未过期，
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
