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
import com.ruoyi.biz.domain.StoreAlbum;
import com.ruoyi.biz.service.IStoreAlbumService;
import com.ruoyi.common.utils.poi.ExcelUtil;
import com.ruoyi.biz.tenant.TenantFilterHelper;
import com.ruoyi.common.core.page.TableDataInfo;

/**
 * 门店相册Controller
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@RestController
@RequestMapping("/biz/album")
public class StoreAlbumController extends BaseController
{
    @Autowired
    private IStoreAlbumService storeAlbumService;

    /**
     * 查询门店相册列表
     */
    @PreAuthorize("@ss.hasPermi('biz:album:list')")
    @GetMapping("/list")
    public TableDataInfo list(StoreAlbum storeAlbum)
    {
        startPage();
        List<StoreAlbum> list = storeAlbumService.selectStoreAlbumList(storeAlbum);
        return getDataTable(list);
    }

    /**
     * 导出门店相册列表
     */
    @PreAuthorize("@ss.hasPermi('biz:album:export')")
    @Log(title = "门店相册", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, StoreAlbum storeAlbum)
    {
        List<StoreAlbum> list = storeAlbumService.selectStoreAlbumList(storeAlbum);
        ExcelUtil<StoreAlbum> util = new ExcelUtil<StoreAlbum>(StoreAlbum.class);
        util.exportExcel(response, list, "门店相册数据");
    }

    /**
     * 获取门店相册详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:album:query')")
    @GetMapping(value = "/{albumId}")
    public AjaxResult getInfo(@PathVariable("albumId") Long albumId)
    {
        StoreAlbum storeAlbum = storeAlbumService.selectStoreAlbumByAlbumId(albumId);
        if (storeAlbum != null)
        {
            TenantFilterHelper.assertDataScope(storeAlbum.getMerchantId());
        }
        return success(storeAlbum);
    }

    /**
     * 新增门店相册
     */
    @PreAuthorize("@ss.hasPermi('biz:album:add')")
    @Log(title = "门店相册", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody StoreAlbum storeAlbum)
    {
        return toAjax(storeAlbumService.insertStoreAlbum(storeAlbum));
    }

    /**
     * 修改门店相册
     */
    @PreAuthorize("@ss.hasPermi('biz:album:edit')")
    @Log(title = "门店相册", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody StoreAlbum storeAlbum)
    {
        return toAjax(storeAlbumService.updateStoreAlbum(storeAlbum));
    }

    /**
     * 删除门店相册
     */
    @PreAuthorize("@ss.hasPermi('biz:album:remove')")
    @Log(title = "门店相册", businessType = BusinessType.DELETE)
	@DeleteMapping("/{albumIds}")
    public AjaxResult remove(@PathVariable Long[] albumIds)
    {
        return toAjax(storeAlbumService.deleteStoreAlbumByAlbumIds(albumIds));
    }
}
