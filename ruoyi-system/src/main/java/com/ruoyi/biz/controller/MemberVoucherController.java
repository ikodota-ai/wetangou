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
import com.ruoyi.biz.domain.MemberVoucher;
import com.ruoyi.biz.service.IMemberVoucherService;
import com.ruoyi.common.utils.poi.ExcelUtil;
import com.ruoyi.common.core.page.TableDataInfo;

/**
 * 会员代金券Controller
 * 
 * @author dytuangou
 * @date 2026-07-24
 */
@RestController
@RequestMapping("/biz/memberVoucher")
public class MemberVoucherController extends BaseController
{
    @Autowired
    private IMemberVoucherService memberVoucherService;

    /**
     * 查询会员代金券列表
     */
    @PreAuthorize("@ss.hasPermi('biz:memberVoucher:list')")
    @GetMapping("/list")
    public TableDataInfo list(MemberVoucher memberVoucher)
    {
        startPage();
        List<MemberVoucher> list = memberVoucherService.selectMemberVoucherList(memberVoucher);
        return getDataTable(list);
    }

    /**
     * 导出会员代金券列表
     */
    @PreAuthorize("@ss.hasPermi('biz:memberVoucher:export')")
    @Log(title = "会员代金券", businessType = BusinessType.EXPORT)
    @PostMapping("/export")
    public void export(HttpServletResponse response, MemberVoucher memberVoucher)
    {
        List<MemberVoucher> list = memberVoucherService.selectMemberVoucherList(memberVoucher);
        ExcelUtil<MemberVoucher> util = new ExcelUtil<MemberVoucher>(MemberVoucher.class);
        util.exportExcel(response, list, "会员代金券数据");
    }

    /**
     * 获取会员代金券详细信息
     */
    @PreAuthorize("@ss.hasPermi('biz:memberVoucher:query')")
    @GetMapping(value = "/{id}")
    public AjaxResult getInfo(@PathVariable("id") Long id)
    {
        return success(memberVoucherService.selectMemberVoucherById(id));
    }

    /**
     * 新增会员代金券
     */
    @PreAuthorize("@ss.hasPermi('biz:memberVoucher:add')")
    @Log(title = "会员代金券", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody MemberVoucher memberVoucher)
    {
        return toAjax(memberVoucherService.insertMemberVoucher(memberVoucher));
    }

    /**
     * 修改会员代金券
     */
    @PreAuthorize("@ss.hasPermi('biz:memberVoucher:edit')")
    @Log(title = "会员代金券", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody MemberVoucher memberVoucher)
    {
        return toAjax(memberVoucherService.updateMemberVoucher(memberVoucher));
    }

    /**
     * 删除会员代金券
     */
    @PreAuthorize("@ss.hasPermi('biz:memberVoucher:remove')")
    @Log(title = "会员代金券", businessType = BusinessType.DELETE)
	@DeleteMapping("/{ids}")
    public AjaxResult remove(@PathVariable Long[] ids)
    {
        return toAjax(memberVoucherService.deleteMemberVoucherByIds(ids));
    }
}
