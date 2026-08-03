package com.ruoyi.biz.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.biz.domain.Member;
import com.ruoyi.biz.service.IMemberService;

/**
 * 业务对象手机号完整查看接口（脱敏反操作）
 *
 * <p>会员表的 {@code phone} 字段使用 {@code @Sensitive(PHONE)} 序列化时会被
 * 中间 4 位脱敏。客服回呼、财务对账等场景需要看到完整手机号，
 * 走本接口时同时写入 {@code sys_oper_log} 作为审计。</p>
 *
 * <p>权限：{@code biz:phone:decrypt}（只授给平台账号 / 客服账号）。</p>
 *
 * <p>未来扩展：增加 withdraw / order 等业务类型时，按 bizType 分支返回相应字段即可。</p>
 */
@RestController
@RequestMapping("/biz/phone")
public class BizPhoneController extends BaseController
{
    private static final Logger log = LoggerFactory.getLogger(BizPhoneController.class);

    @Autowired
    private IMemberService memberService;

    /**
     * 查看会员完整手机号（脱敏反操作）
     *
     * @param req 请求体
     * @return 完整手机号
     */
    @PreAuthorize("@ss.hasPermi('biz:phone:decrypt')")
    @Log(title = "会员手机号解密", businessType = BusinessType.OTHER)
    @PostMapping("/decrypt")
    public AjaxResult decrypt(@RequestBody PhoneDecryptRequest req)
    {
        if (req == null || StringUtils.isEmpty(req.getBizType()) || req.getBizId() == null)
        {
            return AjaxResult.error("参数错误：bizType / bizId 必填");
        }
        if (StringUtils.isEmpty(req.getReason()))
        {
            return AjaxResult.error("参数错误：reason 必填（用于审计）");
        }
        if (!"member".equalsIgnoreCase(req.getBizType()))
        {
            return AjaxResult.error("暂不支持的业务类型：" + req.getBizType());
        }

        Long memberId = req.getBizId();
        Member member = memberService.selectMemberByMemberId(memberId);
        if (member == null)
        {
            return AjaxResult.error("会员不存在");
        }
        String phone = member.getPhone();
        log.info("[biz/phone/decrypt] operator={} memberId={} reason={}",
                SecurityUtils.getUsername(), memberId, req.getReason());
        return AjaxResult.success("ok", phone == null ? "" : phone);
    }

    /**
     * 手机号解密请求体
     */
    public static class PhoneDecryptRequest
    {
        /** 业务类型：member（其他类型暂未启用） */
        private String bizType;
        /** 业务对象 ID */
        private Long bizId;
        /** 解密原因（必填，写审计日志） */
        private String reason;

        public String getBizType() { return bizType; }
        public void setBizType(String bizType) { this.bizType = bizType; }
        public Long getBizId() { return bizId; }
        public void setBizId(Long bizId) { this.bizId = bizId; }
        public String getReason() { return reason; }
        public void setReason(String reason) { this.reason = reason; }
    }
}
