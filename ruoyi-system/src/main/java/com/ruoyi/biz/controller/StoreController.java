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
            s.setLogo(ImageUrlUtils.toAbsolute(s.getLogo()));
        }
        return success(s);
    }

    /**
     * 新增门店
     */
    @PreAuthorize("@ss.hasPermi('biz:store:add')")
    @Log(title = "门店", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody Store store)
    {
        return toAjax(storeService.insertStore(store));
    }

    /**
     * 修改门店
     */
    @PreAuthorize("@ss.hasPermi('biz:store:edit')")
    @Log(title = "门店", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody Store store)
    {
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
