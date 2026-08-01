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
import com.ruoyi.biz.domain.StoreUser;
import com.ruoyi.biz.service.IStoreUserService;
import com.ruoyi.common.utils.poi.ExcelUtil;
import com.ruoyi.common.core.page.TableDataInfo;

/**
 * 账号门店关联Controller
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@RestController
@RequestMapping("/biz/storeUser")
public class StoreUserController extends BaseController
{
    @Autowired
    private IStoreUserService storeUserService;

    /**
     * 查询账号门店关联列表
     */
    @PreAuthorize("@ss.hasPermi('biz:storeUser:list')")
    @GetMapping("/list")
    public TableDataInfo list(StoreUser storeUser)
    {
        startPage();
        List<StoreUser> list = storeUserService.selectStoreUserList(storeUser);
        return getDataTable(list);
    }

    /**
     * 导出账号门店关联列表
     */
    @PreAuthorize("@ss.hasPermi('biz:storeUser:export')")
    @Log(title = "账号门店关联", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, StoreUser storeUser)
    {
        List<StoreUser> list = storeUserService.selectStoreUserList(storeUser);
        ExcelUtil<StoreUser> util = new ExcelUtil<StoreUser>(StoreUser.class);
        util.exportExcel(response, list, "账号门店关联数据");
    }

    /**
     * 获取账号门店关联详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:storeUser:query')")
    @GetMapping(value = "/{id}")
    public AjaxResult getInfo(@PathVariable("id") Long id)
    {
        return success(storeUserService.selectStoreUserById(id));
    }

    /**
     * 新增账号门店关联
     */
    @PreAuthorize("@ss.hasPermi('biz:storeUser:add')")
    @Log(title = "账号门店关联", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody StoreUser storeUser)
    {
        return toAjax(storeUserService.insertStoreUser(storeUser));
    }

    /**
     * 修改账号门店关联
     */
    @PreAuthorize("@ss.hasPermi('biz:storeUser:edit')")
    @Log(title = "账号门店关联", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody StoreUser storeUser)
    {
        return toAjax(storeUserService.updateStoreUser(storeUser));
    }

    /**
     * 删除账号门店关联
     */
    @PreAuthorize("@ss.hasPermi('biz:storeUser:remove')")
    @Log(title = "账号门店关联", businessType = BusinessType.DELETE)
	@DeleteMapping("/{ids}")
    public AjaxResult remove(@PathVariable Long[] ids)
    {
        return toAjax(storeUserService.deleteStoreUserByIds(ids));
    }
}
