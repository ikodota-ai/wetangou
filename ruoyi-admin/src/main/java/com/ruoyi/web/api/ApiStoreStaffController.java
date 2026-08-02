package com.ruoyi.web.api;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.alibaba.fastjson2.JSONObject;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.biz.api.domain.LoginMember;
import com.ruoyi.biz.api.util.MemberTokenService;
import com.ruoyi.biz.domain.StoreUser;
import com.ruoyi.biz.service.IStoreUserService;
import com.ruoyi.system.service.ISysUserService;

/**
 * 小程序门店端员工登录
 *
 * <p>用管理端 sys_user 账号密码登录，返回小程序同款 token（userType=store，
 * storeId=该员工在 biz_store_user 中关联的门店）。登录后即可在门店端工作台
 * （核销码、确认买单、审核预约等）调用 {@code @StoreStaffRequired} 端点。</p>
 *
 * <p>未在 biz_store_user 中关联门店的账号禁止登录，提示「无门店权限」。</p>
 *
 * @author dytuangou
 */
@Anonymous
@RestController
@RequestMapping("/api/store/staff")
public class ApiStoreStaffController
{
    @Autowired
    private ISysUserService userService;

    @Autowired
    private IStoreUserService storeUserService;

    @Autowired
    private MemberTokenService memberTokenService;

    /**
     * 门店员工登录
     */
    @PostMapping("/login")
    public AjaxResult login(@RequestBody JSONObject body)
    {
        String username = body.getString("username");
        String password = body.getString("password");
        if (username == null || password == null)
        {
            throw new ServiceException("账号或密码不能为空");
        }

        SysUser user = userService.selectUserByUserName(username);
        if (user == null)
        {
            throw new ServiceException("账号或密码错误");
        }
        if (!"0".equals(user.getStatus()))
        {
            throw new ServiceException("账号已被停用");
        }
        if (!SecurityUtils.matchesPassword(password, user.getPassword()))
        {
            throw new ServiceException("账号或密码错误");
        }

        // 必须先在 biz_store_user 中挂门店，否则不允许门店端登录
        StoreUser query = new StoreUser();
        query.setUserId(user.getUserId());
        List<StoreUser> links = storeUserService.selectStoreUserList(query);
        if (links == null || links.isEmpty())
        {
            throw new ServiceException("该账号未关联门店，无门店端权限");
        }
        // 一个 sys_user 多门店时取第一个，后续可扩展选门店
        StoreUser link = links.get(0);

        LoginMember loginMember = new LoginMember();
        loginMember.setUserType("store");
        loginMember.setStoreId(link.getStoreId());
        loginMember.setMerchantId(link.getMerchantId());
        // 会员 ID 字段借用 sys_user.userId，门店员工无 biz_member 行
        loginMember.setMemberId(user.getUserId());
        loginMember.setOpenid("staff:" + user.getUserId());
        // createToken 内部将 loginMember.token 设为 UUID，再用 UUID 签出 JWT 并返回
        String jwt = memberTokenService.createToken(loginMember);
        loginMember.setToken(jwt);

        AjaxResult ajax = AjaxResult.success();
        ajax.put("token", loginMember.getToken());
        ajax.put("userType", "store");
        ajax.put("storeId", link.getStoreId());
        ajax.put("storeName", "");
        ajax.put("realName", user.getNickName() == null ? user.getUserName() : user.getNickName());
        return ajax;
    }

    /**
     * 员工登出：清掉 JWT（前端同步清 wx.storage 即可，后端无状态）
     */
    @PostMapping("/logout")
    public AjaxResult logout()
    {
        // JWT 无状态，后端只需要返回成功即可；前端清 staffUser / staffTokenBackup / token
        return AjaxResult.success();
    }
}
