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
import com.ruoyi.biz.domain.Store;
import com.ruoyi.biz.service.IStoreService;
import com.ruoyi.common.utils.image.ImageUrlUtils;
import com.ruoyi.common.utils.poi.ExcelUtil;
import com.ruoyi.biz.tenant.TenantFilterHelper;
import com.ruoyi.common.utils.TenantContextHolder;
import com.ruoyi.common.core.domain.BaseEntity;
import com.ruoyi.common.core.page.TableDataInfo;

/**
 * 门店Controller
 *
 * @author dytuangou
 * @date 2026-07-24
 */
@RestController
@RequestMapping("/biz/store")
public class StoreController extends BaseController
{
    @Autowired
    private IStoreService storeService;

    /**
     * 查询门店列表
     */
    @PreAuthorize("@ss.hasPermi('biz:store:list')")
    @GetMapping("/list")
    public TableDataInfo list(Store store)
    {
        TenantFilterHelper.apply((BaseEntity) store,
                                  (e, v) -> ((com.ruoyi.biz.domain.Store) e).setMerchantId(v),
                                  e -> ((com.ruoyi.biz.domain.Store) e).getMerchantId());
        startPage();
        List<Store> list = storeService.selectStoreList(store);
        return getDataTable(fillImageUrls(list));
    }

    /**
     * 导出门店列表
     */
    @PreAuthorize("@ss.hasPermi('biz:store:export')")
    @Log(title = "门店", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, Store store)
    {
        TenantFilterHelper.apply((BaseEntity) store,
                                  (e, v) -> ((com.ruoyi.biz.domain.Store) e).setMerchantId(v),
                                  e -> ((com.ruoyi.biz.domain.Store) e).getMerchantId());
        List<Store> list = storeService.selectStoreList(store);
        ExcelUtil<Store> util = new ExcelUtil<Store>(Store.class);
        util.exportExcel(response, list, "门店数据");
    }

    /**
     * 获取门店详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:store:query')")
    @GetMapping(value = "/{storeId}")
    public AjaxResult getInfo(@PathVariable("storeId") Long storeId)
    {
        Store s = storeService.selectStoreByStoreId(storeId);
        if (s != null)
        {
            TenantFilterHelper.assertDataScope(s.getMerchantId());
            s.setLogo(ImageUrlUtils.toAbsolute(s.getLogo()));
        }
        return success(s);
    }

    /**
     * 新增门店
     *
     * <p>merchantId 的确定规则（原先完全没处理，导致门店建出来 merchant_id 为 null，
     * 既不出现在任何商户的门店列表里，也拿不到商品，小程序按商户查门店直接查不到）：
     * <ul>
     *   <li>商户账号：忽略前端传值，一律取 token 里的 merchantId —— 它只能给自己建店；</li>
     *   <li>平台/代理商：必须显式指定；代理商只能指定名下商户（assertDataScope 拦越权）。</li>
     * </ul></p>
     */
    @PreAuthorize("@ss.hasPermi('biz:store:add')")
    @Log(title = "门店", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody Store store)
    {
        Long tokenMerchantId = TenantContextHolder.getMerchantId();
        if (tokenMerchantId != null)
        {
            store.setMerchantId(tokenMerchantId);
        }
        if (store.getMerchantId() == null)
        {
            return AjaxResult.error("请选择所属商户：门店必须归属某个商户，否则不会出现在门店列表和小程序中");
        }
        TenantFilterHelper.assertDataScope(store.getMerchantId());
        return toAjax(storeService.insertStore(store));
    }

    /**
     * 修改门店
     *
     * <p>既要校验「改的是自己有权限的门店」，也要校验「不能把门店改到别家商户去」，
     * 只查其中一边都能被绕过（前者可越权改他人门店，后者可把自家门店塞给别人）。</p>
     */
    @PreAuthorize("@ss.hasPermi('biz:store:edit')")
    @Log(title = "门店", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody Store store)
    {
        Store origin = storeService.selectStoreByStoreId(store.getStoreId());
        if (origin == null)
        {
            return AjaxResult.error("门店不存在");
        }
        // 1) 有没有权限动这家门店
        TenantFilterHelper.assertDataScope(origin.getMerchantId());

        Long tokenMerchantId = TenantContextHolder.getMerchantId();
        if (tokenMerchantId != null)
        {
            // 商户账号不允许转移归属，直接钉回自身
            store.setMerchantId(tokenMerchantId);
        }
        else if (store.getMerchantId() == null)
        {
            // 平台/代理商漏传时保持原归属，而不是把 merchant_id 清成 null
            store.setMerchantId(origin.getMerchantId());
        }
        // 2) 改完之后的归属是否仍在权限范围内
        TenantFilterHelper.assertDataScope(store.getMerchantId());
        return toAjax(storeService.updateStore(store));
    }

    /**
     * 删除门店
     */
    @PreAuthorize("@ss.hasPermi('biz:store:remove')")
    @Log(title = "门店", businessType = BusinessType.DELETE)
    @DeleteMapping("/{storeIds}")
    public AjaxResult remove(@PathVariable Long[] storeIds)
    {
        return toAjax(storeService.deleteStoreByStoreIds(storeIds));
    }

    /**
     * 把列表里所有图片字段（logo/cover/photos）转成绝对 URL，
     * 避免前端 &lt;el-image&gt; 走原生 src 时因相对路径访问到错误端口。
     */
    private List<Store> fillImageUrls(List<Store> list)
    {
        if (list == null)
        {
            return null;
        }
        for (Store s : list)
        {
            s.setLogo(ImageUrlUtils.toAbsolute(s.getLogo()));
        }
        return list;
    }
}
