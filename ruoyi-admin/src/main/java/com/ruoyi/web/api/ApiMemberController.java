package com.ruoyi.web.api;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import com.alibaba.fastjson2.JSONObject;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.config.RuoYiConfig;
import com.ruoyi.common.utils.file.FileUploadUtils;
import com.ruoyi.framework.config.ServerConfig;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.biz.api.annotation.LoginRequired;
import com.ruoyi.biz.api.service.WxMaService;
import com.ruoyi.biz.api.util.MemberContextHolder;
import com.ruoyi.biz.domain.Member;
import com.ruoyi.biz.service.IMemberService;

/**
 * 小程序-会员资料
 *
 * @author dytuangou
 */
@Anonymous
@RestController
@RequestMapping("/api/member")
public class ApiMemberController
{
    @Autowired
    private IMemberService memberService;

    @Autowired
    private WxMaService wxMaService;

    @Autowired
    private ServerConfig serverConfig;

    /**
     * 获取我的资料
     *
     * <p>会员查看自己的资料需要看到明文手机号。直接返回 Member 实体
     * 会被 @Sensitive 把 phone 变 138****0000，所以这里手工拷贝字段，
     * 不用 Jackson 反序列化 @Sensitive 注解。</p>
     */
    @LoginRequired
    @GetMapping("/profile")
    public AjaxResult profile()
    {
        Member m = memberService.selectMemberByMemberId(MemberContextHolder.getMemberId());
        if (m == null) return AjaxResult.success();
        java.util.Map<String, Object> vo = new java.util.LinkedHashMap<>();
        vo.put("memberId", m.getMemberId());
        vo.put("merchantId", m.getMerchantId());
        vo.put("openid", m.getOpenid());
        vo.put("unionid", m.getUnionid());
        vo.put("nickname", m.getNickname());
        vo.put("nickName", m.getNickname());
        vo.put("avatar", m.getAvatar());
        vo.put("avatarUrl", m.getAvatar());
        vo.put("phone", m.getPhone());        // 明文
        vo.put("gender", m.getGender());
        vo.put("birthday", m.getBirthday());
        vo.put("status", m.getStatus());
        vo.put("lastLoginTime", m.getLastLoginTime());
        vo.put("inviteBy", m.getInviteBy());
        vo.put("inviteTime", m.getInviteTime());
        vo.put("createTime", m.getCreateTime());
        return AjaxResult.success(vo);
    }

    /**
     * 更新我的资料（昵称、头像、性别、生日等）
     */
    @LoginRequired
    @PutMapping
    public AjaxResult updateProfile(@RequestBody Member member)
    {
        member.setMemberId(MemberContextHolder.getMemberId());
        // 禁止篡改敏感字段
        member.setOpenid(null);
        member.setUnionid(null);
        member.setStatus(null);
        memberService.updateMember(member);
        return AjaxResult.success();
    }

    /**
     * 绑定微信授权手机号（新版getPhoneNumber流程：前端回传code，后端换取手机号）
     */
    @LoginRequired
    @PostMapping("/phone")
    public AjaxResult updatePhone(@RequestBody JSONObject body)
    {
        String code = body.getString("code");
        if (StringUtils.isEmpty(code))
        {
            return AjaxResult.error("缺少手机号授权code");
        }
        String phone = wxMaService.getPhoneNumberByCode(code);

        Member update = new Member();
        update.setMemberId(MemberContextHolder.getMemberId());
        update.setPhone(phone);
        memberService.updateMember(update);

        return AjaxResult.success().put("phone", phone);
    }

    /**
     * 上传会员头像
     */
    @LoginRequired
    @PostMapping("/avatar")
    public AjaxResult uploadAvatar(MultipartFile avatarfile) throws Exception
    {
        if (avatarfile == null || avatarfile.isEmpty())
        {
            return AjaxResult.error("上传头像不能为空");
        }
        String avatar = FileUploadUtils.upload(RuoYiConfig.getAvatarPath(), avatarfile);
        String url = serverConfig.getUrl() + avatar;

        Member update = new Member();
        update.setMemberId(MemberContextHolder.getMemberId());
        update.setAvatar(url);
        memberService.updateMember(update);

        return AjaxResult.success().put("imgUrl", url).put("url", url);
    }
}
