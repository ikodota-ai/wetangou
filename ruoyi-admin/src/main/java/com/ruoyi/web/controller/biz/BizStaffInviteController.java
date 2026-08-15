package com.ruoyi.web.controller.biz;

import java.util.Date;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.common.config.RuoYiConfig;
import com.ruoyi.common.constant.Constants;
import com.ruoyi.framework.config.ServerConfig;
import com.ruoyi.biz.domain.MerchantStaff;
import com.ruoyi.biz.domain.MerchantStaffInvite;
import com.ruoyi.biz.api.service.WxMaService;
import com.ruoyi.biz.service.IMerchantStaffInviteService;
import com.ruoyi.biz.service.IMerchantStaffService;

/**
 * 商家员工邀请码 / 员工名单管理（admin 后台）
 *
 * <p>两个功能合在一个 controller：
 * 1) 邀请码 CRUD：店长在此生成 6 位短码 + 选择门店 + 设置角色 + 过期时间；
 *    小程序扫此码后调 /api/merchant/staff/acceptInvite 自动建账号。
 * 2) 员工名单：列出 biz_merchant_staff，可补录姓名/手机号/状态调整。</p>
 */
@RestController
@RequestMapping("/biz/staffInvite")
public class BizStaffInviteController extends BaseController
{
    @Autowired
    private IMerchantStaffInviteService inviteService;

    @Autowired
    private IMerchantStaffService staffService;

    @Autowired
    private WxMaService wxMaService;

    @Autowired
    private ServerConfig serverConfig;

    // ==================== 邀请码 ====================

    @PreAuthorize("@ss.hasPermi('biz:staffInvite:list')")
    @GetMapping("/list")
    public TableDataInfo list(MerchantStaffInvite query)
    {
        startPage();
        List<MerchantStaffInvite> list = inviteService.selectList(query);
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('biz:staffInvite:query')")
    @GetMapping("/{inviteId}")
    public AjaxResult getInfo(@PathVariable("inviteId") Long inviteId)
    {
        return success(inviteService.selectById(inviteId));
    }

    /**
     * 重新生成小程序太阳码（仅作补图用，生成时已默认生成）
     */
    @PreAuthorize("@ss.hasPermi('biz:staffInvite:query')")
    @GetMapping("/qrcode/{inviteId}")
    public AjaxResult qrcode(@PathVariable("inviteId") Long inviteId) throws Exception
    {
        MerchantStaffInvite inv = inviteService.selectById(inviteId);
        if (inv == null) return error("邀请码不存在");
        String scene = "invite:" + inv.getMerchantId() + ":" + inv.getStoreId() + ":" + inv.getInviteCode();
        byte[] png = wxMaService.getWxaCodeUnlimited(scene, "pages/merchant/scan/index", inv.getMerchantId());
        if (png == null || png.length == 0) return error("生成太阳码失败");
        String dir = RuoYiConfig.getProfile() + "/staffInvite";
        java.io.File dirFile = new java.io.File(dir);
        if (!dirFile.exists() && !dirFile.mkdirs()) return error("无法创建目录");
        String fileName = "inv_" + inv.getInviteCode() + "_" + System.currentTimeMillis() + ".png";
        java.io.File target = new java.io.File(dir, fileName);
        try (java.io.FileOutputStream fos = new java.io.FileOutputStream(target)) { fos.write(png); }
        String relativePath = "/staffInvite/" + fileName;
        String fullUrl = serverConfig.getUrl() + Constants.RESOURCE_PREFIX + relativePath;
        inv.setWxacodeUrl(fullUrl);
        inviteService.update(inv);
        return success().put("url", fullUrl).put("scene", scene);
    }

    @Log(title = "商家邀请码", businessType = BusinessType.INSERT)
    @PreAuthorize("@ss.hasPermi('biz:staffInvite:add')")
    @PostMapping
    public AjaxResult add(@RequestBody MerchantStaffInvite invite)
    {
        if (invite.getMerchantId() == null) return error("请选择商户");
        if (invite.getStoreId() == null) return error("请选择门店");
        if (invite.getExpireAt() == null)
        {
            // 默认 7 天后过期
            invite.setExpireAt(new Date(System.currentTimeMillis() + 7L * 24 * 3600 * 1000));
        }
        // scene 是 NOT NULL 必填; 客户端不传时自动生成 (C32 摸出 P1 缺陷, 修复)
        if (invite.getScene() == null || invite.getScene().isEmpty())
        {
            invite.setScene("invite:" + invite.getMerchantId() + ":" + invite.getStoreId() + ":AUTO");
        }
        invite.setStatus("0");
        invite.setCreateBy(getUsername());
        int rows = inviteService.insert(invite);
        if (rows <= 0) return error("生成失败");
        // 生成小程序太阳码（scene = invite:MID:SID:CODE），供店长截图分发
        try {
            String scene = "invite:" + invite.getMerchantId() + ":" + invite.getStoreId() + ":" + invite.getInviteCode();
            byte[] png = wxMaService.getWxaCodeUnlimited(scene, "pages/merchant/scan/index", invite.getMerchantId());
            if (png != null && png.length > 0) {
                String dir = RuoYiConfig.getProfile() + "/staffInvite";
                java.io.File dirFile = new java.io.File(dir);
                if (!dirFile.exists() && !dirFile.mkdirs()) throw new RuntimeException("dir");
                String fileName = "inv_" + invite.getInviteCode() + "_" + System.currentTimeMillis() + ".png";
                java.io.File target = new java.io.File(dir, fileName);
                try (java.io.FileOutputStream fos = new java.io.FileOutputStream(target)) { fos.write(png); }
                String relativePath = "/staffInvite/" + fileName;
                String fullUrl = serverConfig.getUrl() + Constants.RESOURCE_PREFIX + relativePath;
                invite.setWxacodeUrl(fullUrl);
                inviteService.update(invite);
            }
        } catch (Exception ex) {
            // 太阳码生成失败不阻塞主流程，店长可以手动复制 6 位短码
        }
        return success("已生成邀请码：" + invite.getInviteCode()).put("wxacodeUrl", invite.getWxacodeUrl());
    }

    @Log(title = "商家邀请码", businessType = BusinessType.UPDATE)
    @PreAuthorize("@ss.hasPermi('biz:staffInvite:edit')")
    @PutMapping
    public AjaxResult edit(@RequestBody MerchantStaffInvite invite)
    {
        invite.setUpdateBy(getUsername());
        return toAjax(inviteService.update(invite));
    }

    @Log(title = "商家邀请码", businessType = BusinessType.DELETE)
    @PreAuthorize("@ss.hasPermi('biz:staffInvite:remove')")
    @DeleteMapping("/{inviteId}")
    public AjaxResult remove(@PathVariable("inviteId") Long inviteId)
    {
        return toAjax(inviteService.deleteById(inviteId));
    }

    // ==================== 员工名单 ====================

    @PreAuthorize("@ss.hasPermi('biz:staffInvite:list')")
    @GetMapping("/staff/list")
    public TableDataInfo staffList(MerchantStaff query)
    {
        startPage();
        List<MerchantStaff> list = staffService.selectList(query);
        return getDataTable(list);
    }

    @Log(title = "商家员工", businessType = BusinessType.UPDATE)
    @PreAuthorize("@ss.hasPermi('biz:staffInvite:edit')")
    @PutMapping("/staff")
    public AjaxResult editStaff(@RequestBody MerchantStaff staff)
    {
        staff.setUpdateBy(getUsername());
        return toAjax(staffService.update(staff));
    }

    @Log(title = "商家员工", businessType = BusinessType.UPDATE)
    @PreAuthorize("@ss.hasPermi('biz:staffInvite:edit')")
    @PostMapping("/staff/profile")
    public AjaxResult profile(@RequestBody MerchantStaff staff)
    {
        if (staff.getUserId() == null) return error("缺少 userId");
        staff.setUpdateBy(getUsername());
        return toAjax(staffService.updateByUserId(staff));
    }

    @Log(title = "商家员工", businessType = BusinessType.DELETE)
    @PreAuthorize("@ss.hasPermi('biz:staffInvite:remove')")
    @DeleteMapping("/staff/{id}")
    public AjaxResult removeStaff(@PathVariable("id") Long id)
    {
        return toAjax(staffService.deleteById(id));
    }

    // ==================== 员工审核（V6-3）====================
    // 员工通过邀请码扫入后默认 status=3（待审核），OWNER/MANAGER 在此审批：
    //  - approve=true  → status=0（在职）
    //  - approve=false → 物理删除关联（员工账号保留可重发邀请）

    @PreAuthorize("@ss.hasPermi('biz:staffInvite:list')")
    @GetMapping("/staff/audit")
    public AjaxResult auditList()
    {
        MerchantStaff q = new MerchantStaff();
        q.setStatus("3");
        return success(staffService.selectList(q));
    }

    @Log(title = "员工审核", businessType = BusinessType.UPDATE)
    @PreAuthorize("@ss.hasPermi('biz:staffInvite:edit')")
    @PostMapping("/staff/audit")
    public AjaxResult audit(@RequestBody MerchantStaff body)
    {
        if (body.getId() == null) return error("缺少 id");
        MerchantStaff db = staffService.selectById(body.getId());
        if (db == null) return error("员工关联不存在");
        if (!"3".equals(db.getStatus())) return error("该员工不在待审核状态");
        Boolean approve = body.getApprove();
        if (approve == null) return error("缺少 approve 字段");
        if (approve) {
            db.setStatus("0");
            db.setUpdateBy(getUsername());
            return toAjax(staffService.update(db));
        } else {
            // 拒绝：物理删除关联
            return toAjax(staffService.deleteById(db.getId()));
        }
    }
}
