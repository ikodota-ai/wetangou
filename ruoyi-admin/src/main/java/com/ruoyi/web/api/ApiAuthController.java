package com.ruoyi.web.api;

import java.util.Date;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.alibaba.fastjson2.JSONObject;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.constant.TenantConstants;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.biz.api.annotation.LoginRequired;
import com.ruoyi.biz.api.domain.LoginMember;
import com.ruoyi.biz.api.service.WxMaService;
import com.ruoyi.biz.api.util.MemberContextHolder;
import com.ruoyi.biz.api.util.MemberTokenService;
import com.ruoyi.biz.domain.Member;
import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.biz.service.IMemberService;
import com.ruoyi.biz.service.ITenantService;
import com.ruoyi.common.exception.ServiceException;

/**
 * 小程序-认证登录
 *
 * @author dytuangou
 */
@Anonymous
@RestController
@RequestMapping("/api/auth")
public class ApiAuthController
{
    /** 存量单商户小程序未传appid时使用的默认商户ID */

    @Autowired
    private WxMaService wxMaService;

    @Autowired
    private IMemberService memberService;

    @Autowired
    private MemberTokenService memberTokenService;

    @Autowired
    private ITenantService tenantService;

    /**
     * 微信登录：code换openid，注册或更新会员，返回会员token
     */
    @PostMapping("/login")
    public AjaxResult login(@RequestBody JSONObject body)
    {
        String code = body.getString("code");
        String nickName = body.getString("nickName");
        String avatarUrl = body.getString("avatarUrl");
        String appid = body.getString("appid");

        // 多商户：按小程序appid确定所属商户，同一openid在不同商户下互相隔离
        Long merchantId = resolveMerchantId(appid);

        JSONObject session = wxMaService.code2Session(code, merchantId);
        String openid = session.getString("openid");
        String sessionKey = session.getString("session_key");
        String unionid = session.getString("unionid");

        Long inviteBy = body.getLong("inviteBy");
        // 防止自邀 / 邀请不存在的会员
        if (inviteBy != null && inviteBy.equals(memberId0(openid)))
        {
            inviteBy = null;
        }

        Member member = memberService.selectMemberByOpenid(merchantId, openid);
        if (member == null)
        {
            member = new Member();
            member.setMerchantId(merchantId);
            member.setOpenid(openid);
            member.setUnionid(unionid);
            member.setNickname(nickName);
            member.setAvatar(avatarUrl);
            member.setStatus("0");
            member.setCreateTime(new Date());
            member.setLastLoginTime(new Date());
            // 一次性写入邀请人：仅在新建时绑定，已存在会员不覆盖，避免「换 openid 登录被重新绑定」
            if (inviteBy != null && isValidInviter(merchantId, inviteBy))
            {
                member.setInviteBy(inviteBy);
                member.setInviteTime(new Date());
            }
            memberService.insertMember(member);
        }
        else
        {
            member.setLastLoginTime(new Date());
            if (StringUtils.isNotEmpty(nickName))
            {
                member.setNickname(nickName);
            }
            if (StringUtils.isNotEmpty(avatarUrl))
            {
                member.setAvatar(avatarUrl);
            }
            // 已存在会员且 invite_by 为空时，补一次邀请人（避免冷启动登录没拿到 inviteBy 后续回填）
            // 同时防御自邀：inviteBy 等于当前会员 id 时拒绝
            if (member.getInviteBy() == null && inviteBy != null
                    && !inviteBy.equals(member.getMemberId())
                    && isValidInviter(merchantId, inviteBy))
            {
                member.setInviteBy(inviteBy);
                member.setInviteTime(new Date());
            }
            memberService.updateMember(member);
        }

        LoginMember loginMember = new LoginMember(member);
        String token = memberTokenService.createToken(loginMember);

        AjaxResult ajax = AjaxResult.success("登录成功");
        ajax.put("token", token);
        ajax.put("memberId", member.getMemberId());
        // 顺带返回会员资料，登录后小程序能立刻显示昵称/头像/手机号，
        // 避免「我的」页一直显示默认「微信用户」和默认头像
        ajax.put("nickName", member.getNickname());
        ajax.put("avatarUrl", member.getAvatar());
        ajax.put("phone", member.getPhone());
        return ajax;
    }

    /**
     * 校验邀请人合法性：同商户 + 状态正常
     */
    private boolean isValidInviter(Long merchantId, Long inviteBy)
    {
        Member inviter = memberService.selectMemberByMemberId(inviteBy);
        return inviter != null && "0".equals(inviter.getStatus())
                && merchantId.equals(inviter.getMerchantId());
    }

    /**
     * 自邀检查：当前会员（通过 openid 已识别）的 memberId 由调用方在拿到 member 对象后判定。
     * 此方法作为保留 hook 留空——具体自邀防御在登录主流程里通过对 member.getMemberId() 与 inviteBy 比较实现。
     */
    private Long memberId0(String openid)
    {
        return null;
    }

    /**
     * 按appid解析商户ID
     *
     * <p>未传appid时兼容单商户存量小程序：回退到默认商户（ID=1）。
     * 传了appid但查不到对应商户则直接拒绝，避免数据落到错误商户。</p>
     */
    private Long resolveMerchantId(String appid)
    {
        if (StringUtils.isEmpty(appid))
        {
            return TenantConstants.DEFAULT_MERCHANT_ID;
        }
        Merchant merchant = tenantService.getMerchantByAppid(appid);
        if (merchant == null)
        {
            throw new ServiceException("小程序未接入或已停用：" + appid);
        }
        if (!"0".equals(merchant.getStatus()))
        {
            throw new ServiceException("商户已停用，请联系服务商");
        }
        return merchant.getMerchantId();
    }

    /**
     * 获取当前登录会员信息
     */
    @LoginRequired
    @PostMapping("/info")
    public AjaxResult info()
    {
        LoginMember loginMember = MemberContextHolder.get();
        Member member = memberService.selectMemberByMemberId(loginMember.getMemberId());
        return AjaxResult.success(member);
    }

    /**
     * 退出登录
     */
    @LoginRequired
    @PostMapping("/logout")
    public AjaxResult logout()
    {
        LoginMember loginMember = MemberContextHolder.get();
        if (loginMember != null && StringUtils.isNotEmpty(loginMember.getToken()))
        {
            memberTokenService.delLoginMember(loginMember.getToken());
        }
        return AjaxResult.success("退出成功");
    }

    /**
     * 已登录用户回填邀请人（用于扫码进入后未在登录时携带 inviteBy 场景）
     *
     * <p>仅在当前会员 invite_by 为空时回写一次，防止覆盖既有邀请关系。
     * 同一商户内的会员可以互相邀请，跨商户邀请自动拒绝。</p>
     */
    @LoginRequired
    @PostMapping("/bind-invite")
    public AjaxResult bindInvite(@RequestBody JSONObject body)
    {
        Long inviteBy = body.getLong("inviteBy");
        if (inviteBy == null)
        {
            return AjaxResult.error("缺少 inviteBy");
        }
        if (inviteBy.equals(MemberContextHolder.getMemberId()))
        {
            return AjaxResult.error("不能邀请自己");
        }
        Member me = memberService.selectMemberByMemberId(MemberContextHolder.getMemberId());
        if (me == null)
        {
            return AjaxResult.error("会员不存在");
        }
        if (me.getInviteBy() != null)
        {
            return AjaxResult.success("已有邀请人，无需重复绑定");
        }
        if (!isValidInviter(me.getMerchantId(), inviteBy))
        {
            return AjaxResult.error("邀请人不存在或跨商户");
        }
        Member update = new Member();
        update.setMemberId(me.getMemberId());
        update.setInviteBy(inviteBy);
        update.setInviteTime(new Date());
        memberService.updateMember(update);
        return AjaxResult.success("绑定成功");
    }
}
