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
import com.ruoyi.biz.service.IStoredCardService;
import com.ruoyi.biz.domain.StoredCard;
import com.ruoyi.biz.domain.StoredCardTransaction;
import com.ruoyi.biz.domain.Product;

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

    @Autowired
    private IStoredCardService storedCardService;

    @Autowired
    private com.ruoyi.biz.service.IProductService productService;

    /**
     * 获取我的资料
     *
     * <p>会员查看自己的资料需要看到明文手机号。直接返回 Member 实体
     * 会被 @Sensitive 把 phone 变 138****0000，所以这里手工拷贝字段，
     * 不用 Jackson 反序列化 @Sensitive 注解。</p>
     *
     * <p>注意 phone 必须是明文：手工拷贝的目的就是绕开 @Sensitive，
     * 结果这里又手动调了一次 desensitizer()，等于白绕。
     * 而这个接口是「当前会员看自己的手机号」，不是给别人看的，脱敏没有意义。
     *
     * 更要紧的是它会污染下游：app.js 的 bootUser 和下单页的
     * _refreshUserContact 都拿这个返回值 Object.assign 进 globalData.user，
     * 把登录接口给的明文覆盖成 138****1234；下单/买单/预约提交时带过去的
     * 就是含星号的号码，既存不进订单也拨不出去。</p>
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
        vo.put("phone", m.getPhone());
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
        // 带上当前会员的 merchantId：多商户版每个商户有自己的 appId/secret，
        // 不传就只读全局参数，后台配过也会报「未配置小程序appId/secret」。
        String phone = wxMaService.getPhoneNumberByCode(code, MemberContextHolder.getMerchantId());

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
        // upload() 返回的已经是 /profile/avatar/2026/08/31/xxx.jpg 这种相对路径。
        //
        // 入库必须存相对路径，不能存 serverConfig.getUrl() 拼出来的绝对地址：
        // getUrl() 取的是当前请求的 host，本地跑就写进 http://127.0.0.1:8080/...、
        // 内网调试写进 http://172.31.26.216:8080/...（库里存量数据就是这样），
        // 换个环境或换台手机全部打不开；而且 <image> 不支持 http，
        // 生产 https 域名下这些 http 绝对地址会被微信直接拦掉。
        // 昵称是纯文本所以没事 —— 这就是「昵称能读出来、头像读不出来」的原因。
        //
        // 前端 toFullUrl() 会用当前接口 baseUrl 补全相对路径，跨环境都对。
        String avatar = FileUploadUtils.upload(RuoYiConfig.getAvatarPath(), avatarfile);

        Member update = new Member();
        update.setMemberId(MemberContextHolder.getMemberId());
        update.setAvatar(avatar);
        memberService.updateMember(update);

        // 响应仍给绝对地址：前端拿到就能直接预览，不用等下次 profile 刷新
        String url = serverConfig.getUrl() + avatar;
        return AjaxResult.success().put("imgUrl", url).put("url", url);
    }


    // ============================================================
    //  储值卡 STORED_CARD 闭环（会员端）
    //  PRD §STORED_CARD / doc/PRD-抖音来客商品模型.md
    // ============================================================

    /**
     * 查询我的储值卡列表（含余额）
     */
    @LoginRequired
    @GetMapping("/stored-card/list")
    public AjaxResult listMyCards()
    {
        Long memberId = MemberContextHolder.getMemberId();
        StoredCard q = new StoredCard();
        q.setMemberId(memberId);
        // 不带 merchantId 过滤，会员查自己的卡跨商户可见
        // （卡的归属按 memberId 寻址，避免会员因租户识别不到 merchantId 而看不到自己的卡）
        java.util.List<StoredCard> cards = storedCardService.selectList(q);
        java.util.List<java.util.Map<String, Object>> out = new java.util.ArrayList<>();
        for (StoredCard c : cards) {
            java.util.Map<String, Object> vo = new java.util.LinkedHashMap<>();
            vo.put("cardId", c.getCardId());
            vo.put("productId", c.getProductId());
            vo.put("productName", productNameOf(c.getProductId()));
            vo.put("faceValue", c.getFaceValue());
            vo.put("balance", c.getBalance());
            vo.put("usedAmount", c.getUsedAmount());
            vo.put("rechargeAmount", c.getRechargeAmount());
            vo.put("refundAmount", c.getRefundAmount());
            vo.put("expireAt", c.getExpireAt());
            vo.put("status", c.getStatus());
            vo.put("statusName", c.getStatus() == null ? ""
                : ("0".equals(c.getStatus()) ? "正常" : ("1".equals(c.getStatus()) ? "已冻结" : "已退卡")));
            out.add(vo);
        }
        return AjaxResult.success(out);
    }

    /**
     * 查询余额（单卡）
     */
    @LoginRequired
    @GetMapping("/stored-card/balance")
    public AjaxResult balance(java.lang.Long cardId)
    {
        if (cardId == null) return AjaxResult.error("cardId 不能为空");
        StoredCard c = storedCardService.selectById(cardId);
        if (c == null) return AjaxResult.error("卡不存在");
        if (!c.getMemberId().equals(MemberContextHolder.getMemberId())) {
            return AjaxResult.error("无权查看该卡");
        }
        java.util.Map<String, Object> vo = new java.util.LinkedHashMap<>();
        vo.put("cardId", c.getCardId());
        vo.put("balance", c.getBalance());
        vo.put("faceValue", c.getFaceValue());
        vo.put("usedAmount", c.getUsedAmount());
        vo.put("expireAt", c.getExpireAt());
        vo.put("status", c.getStatus());
        return AjaxResult.success(vo);
    }

    /**
     * 会员自助充值（幂等 bizNo）
     */
    @LoginRequired
    @PostMapping("/stored-card/recharge")
    public AjaxResult recharge(@RequestBody JSONObject body)
    {
        Long cardId = body.getLong("cardId");
        java.math.BigDecimal amount = body.getBigDecimal("amount");
        String bizNo = body.getString("bizNo");
        if (cardId == null || amount == null) return AjaxResult.error("cardId/amount 不能为空");
        if (amount.signum() <= 0) return AjaxResult.error("充值金额必须大于 0");
        if (bizNo == null || bizNo.isEmpty()) bizNo = "R" + System.currentTimeMillis() + "_" + cardId;
        StoredCard c = storedCardService.selectById(cardId);
        if (c == null) return AjaxResult.error("卡不存在");
        if (!c.getMemberId().equals(MemberContextHolder.getMemberId())) {
            return AjaxResult.error("无权充值该卡");
        }
        StoredCard after = storedCardService.recharge(cardId, amount, bizNo, "MEMBER", String.valueOf(MemberContextHolder.getMemberId()));
        java.util.Map<String, Object> vo = new java.util.LinkedHashMap<>();
        vo.put("cardId", after.getCardId());
        vo.put("balance", after.getBalance());
        vo.put("rechargeAmount", after.getRechargeAmount());
        vo.put("bizNo", bizNo);
        return AjaxResult.success(vo);
    }

    /**
     * 储值卡退款（会员发起 / 商家后台调）
     */
    @LoginRequired
    @PostMapping("/stored-card/refund")
    public AjaxResult refund(@RequestBody JSONObject body)
    {
        Long cardId = body.getLong("cardId");
        java.math.BigDecimal amount = body.getBigDecimal("amount");
        String bizNo = body.getString("bizNo");
        Long orderId = body.getLong("orderId");
        if (cardId == null || amount == null) return AjaxResult.error("cardId/amount 不能为空");
        if (amount.signum() <= 0) return AjaxResult.error("退款金额必须大于 0");
        if (bizNo == null || bizNo.isEmpty()) bizNo = "F" + System.currentTimeMillis() + "_" + cardId;
        StoredCard c = storedCardService.selectById(cardId);
        if (c == null) return AjaxResult.error("卡不存在");
        if (!c.getMemberId().equals(MemberContextHolder.getMemberId())) {
            return AjaxResult.error("无权退款该卡");
        }
        StoredCard after = storedCardService.refund(cardId, amount, bizNo, orderId, "MEMBER", String.valueOf(MemberContextHolder.getMemberId()));
        java.util.Map<String, Object> vo = new java.util.LinkedHashMap<>();
        vo.put("cardId", after.getCardId());
        vo.put("balance", after.getBalance());
        vo.put("refundAmount", after.getRefundAmount());
        vo.put("bizNo", bizNo);
        return AjaxResult.success(vo);
    }

    /**
     * 储值卡流水
     */
    @LoginRequired
    @GetMapping("/stored-card/transactions")
    public AjaxResult transactions(java.lang.Long cardId, java.lang.String txType, java.lang.Integer limit)
    {
        java.util.List<StoredCardTransaction> list;
        if (cardId != null) {
            StoredCard c = storedCardService.selectById(cardId);
            if (c == null) return AjaxResult.error("卡不存在");
            if (!c.getMemberId().equals(MemberContextHolder.getMemberId())) {
                return AjaxResult.error("无权查看");
            }
            list = storedCardService.selectTransactions(cardId, null, 0);
            java.util.List<StoredCardTransaction> filtered = new java.util.ArrayList<>();
            for (StoredCardTransaction t : list) {
                if (cardId.equals(t.getCardId())) filtered.add(t);
            }
            list = filtered;
        } else {
            list = storedCardService.selectTransactions(MemberContextHolder.getMemberId(), txType, limit == null ? 50 : limit);
        }
        java.util.List<java.util.Map<String, Object>> out = new java.util.ArrayList<>();
        for (StoredCardTransaction t : list) {
            java.util.Map<String, Object> vo = new java.util.LinkedHashMap<>();
            vo.put("txId", t.getTxId());
            vo.put("cardId", t.getCardId());
            vo.put("txType", t.getTxType());
            vo.put("amount", t.getAmount());
            vo.put("balanceBefore", t.getBalanceBefore());
            vo.put("balanceAfter", t.getBalanceAfter());
            vo.put("orderId", t.getOrderId());
            vo.put("bizNo", t.getBizNo());
            vo.put("operatorType", t.getOperatorType());
            vo.put("remark", t.getRemark());
            vo.put("createTime", t.getCreateTime());
            out.add(vo);
        }
        return AjaxResult.success(out);
    }

    private String productNameOf(Long productId) {
        if (productId == null) return "";
        try {
            Product p = productService.selectProductByProductId(productId);
            return p == null ? "" : p.getProductName();
        } catch (Exception e) {
            return "";
        }
    }
}
