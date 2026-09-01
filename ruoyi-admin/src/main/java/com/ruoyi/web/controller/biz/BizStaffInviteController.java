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
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.common.config.RuoYiConfig;
import com.ruoyi.common.constant.Constants;
import com.ruoyi.framework.config.ServerConfig;
import com.ruoyi.biz.domain.MerchantStaff;
import com.ruoyi.biz.domain.Store;
import com.ruoyi.biz.domain.MerchantStaffInvite;
import com.ruoyi.biz.api.service.WxMaService;
import com.ruoyi.biz.service.IMerchantStaffInviteService;
import com.ruoyi.biz.service.IMerchantStaffService;
import com.ruoyi.biz.service.IStoreService;
import com.ruoyi.biz.tenant.TenantFilterHelper;

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

    @Autowired
    private com.ruoyi.system.service.ISysUserService userService;

    @Autowired
    private IStoreService storeService;

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
        // 商户账号带上别家 merchantId 请求时，TenantInsertInterceptor 会静默把落库值
        // 改写成自己商户（不会真的跨租户写入），但 scene 用的还是请求体里那个 merchantId，
        // 于是落库 merchant_id 与 scene 里的 mid 不一致。这里提前拒掉，让错误明确可见，
        // 而不是让店长拿到一个看起来成功、实际扫不动的码。
        TenantFilterHelper.assertDataScope(invite.getMerchantId());
        // 真正的缺陷在这：门店归属从来没校验过。选了别家门店同样返回「已生成邀请码」，
        // 但落库是「自己商户 + 别家门店」，acceptInvite 那步校验 mid/sid 必须与库中记录
        // 一致，这个组合永远过不去（实测库里 G5BRHE 就是这么来的死码，扫码只报
        // 「邀请码不存在」，店长完全不知道自己发了张废码）。
        Store store = storeService.selectStoreByStoreId(invite.getStoreId());
        if (store == null) return error("门店不存在");
        if (store.getMerchantId() == null || !store.getMerchantId().equals(invite.getMerchantId()))
        {
            return error("门店「" + store.getStoreName() + "」不属于该商户，不能作为入职门店");
        }
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
        if (invite.getInviteId() == null) return error("缺少 inviteId");
        // 按库里那条记录的归属判，不信请求体里的 merchantId。
        // 跨商户读本身已被 TenantSqlInterceptor 改写挡住（db 直接为 null），
        // 这里保留显式判断是为了给出确定的错误，而不是依赖 SQL 改写的副作用。
        MerchantStaffInvite db = inviteService.selectById(invite.getInviteId());
        if (db == null) return error("邀请码不存在");
        TenantFilterHelper.assertDataScope(db.getMerchantId());
        // 不允许把别人的码改到自己名下、或把自己的码挪给别家商户
        if (invite.getMerchantId() != null && !invite.getMerchantId().equals(db.getMerchantId()))
        {
            return error("不允许变更邀请码所属商户");
        }
        invite.setUpdateBy(getUsername());
        return toAjax(inviteService.update(invite));
    }

    @Log(title = "商家邀请码", businessType = BusinessType.DELETE)
    @PreAuthorize("@ss.hasPermi('biz:staffInvite:remove')")
    @DeleteMapping("/{inviteId}")
    public AjaxResult remove(@PathVariable("inviteId") Long inviteId)
    {
        // 删除别家的码不会真的删掉（DELETE 语句被租户拦截器追加了 merchant_id 条件，
        // 影响行数 0），但 toAjax(0) 只会返回含糊的「操作失败」，店长会以为是系统故障
        // 反复重试。先按归属判一次，直接告诉他这条码不在他名下。
        MerchantStaffInvite db = inviteService.selectById(inviteId);
        if (db == null) return error("邀请码不存在");
        TenantFilterHelper.assertDataScope(db.getMerchantId());
        return toAjax(inviteService.deleteById(inviteId));
    }

    // ==================== 员工名单 ====================

    @PreAuthorize("@ss.hasPermi('biz:staffInvite:list')")
    @GetMapping("/staff/list")
    public TableDataInfo staffList(MerchantStaff query)
    {
        // 防跨租户：代理商只见名下商户、商户只见自己
        com.ruoyi.biz.tenant.TenantFilterHelper.apply(query,
                (q, mid) -> ((MerchantStaff) q).setMerchantId(mid),
                q -> ((MerchantStaff) q).getMerchantId());
        startPage();
        List<MerchantStaff> list = staffService.selectList(query);
        // 补微信绑定状态（必须在 getDataTable 之前，否则改的是已复制走的对象）
        fillWxBindStatus(list);
        return getDataTable(list);
    }

    /**
     * 解绑员工微信（admin 端）。
     *
     * <p>场景：员工换手机/换微信、或离职后微信被误留。解绑后该 openid 释放，
     * 员工需重新用账号密码登录（登录时会自动绑定新微信）。</p>
     *
     * <p>只清 sys_user.openid，不动 biz_merchant_staff 关联 —— 解绑 ≠ 解除雇佣关系。</p>
     */
    @Log(title = "商家员工", businessType = BusinessType.UPDATE)
    @PreAuthorize("@ss.hasPermi('biz:staffInvite:edit')")
    @PutMapping("/staff/unbindWx/{userId}")
    public AjaxResult unbindWx(@PathVariable("userId") Long userId)
    {
        com.ruoyi.common.core.domain.entity.SysUser user = userService.selectUserByUserId(userId);
        if (user == null) return error("员工账号不存在");
        if (StringUtils.isEmpty(user.getOpenid())) {
            return error("该员工尚未绑定微信");
        }
        // 必须走专用语句：updateUser 的动态 set 不含 openid 列，置 null 不会落库
        if (!userService.unbindOpenid(userId)) {
            return error("解绑失败");
        }
        return success("已解绑微信，该员工下次需用账号密码登录");
    }

    /**
     * 重置员工登录密码（admin / 店长 / 老板用）。
     *
     * <p>为什么不复用 RuoYi 的 {@code PUT /system/user/resetPwd}：
     * 那个端点要 {@code system:user:resetPwd} 权限（商户账号没有），且要求调用方自己填新密码。
     * 商家场景需要的是「点一下生成随机密码并当场显示」。</p>
     *
     * <p>背景缺陷：扫码入职时 {@code createStaffByOpenid} 生成的 6 位随机密码
     * 既没返回给任何人、也没有任何重置入口，等于一个谁都不知道的废密码 ——
     * 员工一旦换微信（openid 失效）就永久登不进商家版。</p>
     *
     * <p>新密码明文只在本次响应返回一次，不落库、不写日志。</p>
     */
    @Log(title = "商家员工", businessType = BusinessType.UPDATE)
    @PreAuthorize("@ss.hasPermi('biz:staffInvite:edit')")
    @PutMapping("/staff/resetPwd/{userId}")
    public AjaxResult resetStaffPwd(@PathVariable("userId") Long userId)
    {
        com.ruoyi.common.core.domain.entity.SysUser user = userService.selectUserByUserId(userId);
        if (user == null) return error("员工账号不存在");
        // 防越权：只能重置本商户（代理商为名下商户）员工的密码
        MerchantStaff link = staffService.selectByUserId(userId);
        if (link == null) return error("该账号不是商家员工");
        com.ruoyi.biz.tenant.TenantFilterHelper.assertDataScope(link.getMerchantId());

        String rawPwd = randomPassword();
        com.ruoyi.common.core.domain.entity.SysUser upd = new com.ruoyi.common.core.domain.entity.SysUser();
        upd.setUserId(userId);
        upd.setPassword(com.ruoyi.common.utils.SecurityUtils.encryptPassword(rawPwd));
        upd.setUpdateBy(getUsername());
        if (userService.resetPwd(upd) <= 0)
        {
            return error("重置失败");
        }
        AjaxResult r = success("已重置密码");
        r.put("userName", user.getUserName());
        r.put("newPassword", rawPwd);
        return r;
    }

    /** 初始/重置密码：8 位大小写+数字，避开易混字符（0/O/1/l/I） */
    private String randomPassword()
    {
        String pool = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789";
        java.security.SecureRandom rnd = new java.security.SecureRandom();
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 8; i++)
        {
            sb.append(pool.charAt(rnd.nextInt(pool.length())));
        }
        return sb.toString();
    }

    /** 给员工列表补 wxBound / openidMasked 展示字段（非表字段） */
    private void fillWxBindStatus(List<MerchantStaff> list)
    {
        if (list == null || list.isEmpty()) return;
        for (MerchantStaff ms : list) {
            if (ms.getUserId() == null) continue;
            try {
                com.ruoyi.common.core.domain.entity.SysUser u = userService.selectUserByUserId(ms.getUserId());
                boolean bound = u != null && u.getOpenid() != null && !u.getOpenid().isEmpty();
                ms.setWxBound(bound ? 1 : 0);
                if (bound) {
                    String oid = u.getOpenid();
                    ms.setOpenidMasked(oid.length() <= 8 ? oid : oid.substring(0, 4) + "****" + oid.substring(oid.length() - 4));
                }
            } catch (Exception ignore) { }
        }
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
        com.ruoyi.biz.tenant.TenantFilterHelper.apply(q,
                (x, mid) -> ((MerchantStaff) x).setMerchantId(mid),
                x -> ((MerchantStaff) x).getMerchantId());
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
        // 防越权审批别家商户的员工
        com.ruoyi.biz.tenant.TenantFilterHelper.assertDataScope(db.getMerchantId());
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
