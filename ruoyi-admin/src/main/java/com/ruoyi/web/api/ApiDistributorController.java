package com.ruoyi.web.api;

import java.math.BigDecimal;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.alibaba.fastjson2.JSONObject;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.config.RuoYiConfig;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.file.FileUploadUtils;
import com.ruoyi.biz.api.annotation.LoginRequired;
import com.ruoyi.biz.api.service.WxMaService;
import com.ruoyi.biz.api.util.MemberContextHolder;
import com.ruoyi.biz.domain.Distributor;
import com.ruoyi.biz.domain.Commission;
import com.ruoyi.biz.domain.Member;
import com.ruoyi.biz.domain.Withdraw;
import com.ruoyi.biz.service.IDistributorService;
import com.ruoyi.biz.service.ITenantService;
import com.ruoyi.biz.service.ICommissionService;
import com.ruoyi.biz.service.IMemberService;
import com.ruoyi.biz.service.IWithdrawService;
import com.ruoyi.framework.config.ServerConfig;

/**
 * 小程序-推客中心（加入、佣金、提现）
 *
 * @author dytuangou
 */
@Anonymous
@RestController
@RequestMapping("/api/distributor")
public class ApiDistributorController
{
    @Autowired
    private IDistributorService distributorService;

    @Autowired
    private ICommissionService commissionService;

    @Autowired
    private IWithdrawService withdrawService;

    @Autowired
    private IMemberService memberService;

    @Autowired
    private ITenantService tenantService;

    @Autowired
    private WxMaService wxMaService;

    @Autowired
    private ServerConfig serverConfig;

    private Distributor currentDistributor()
    {
        Long memberId = MemberContextHolder.getMemberId();
        Distributor query = new Distributor();
        query.setMemberId(memberId);
        List<Distributor> list = distributorService.selectDistributorList(query);
        return list.isEmpty() ? null : list.get(0);
    }

    /**
     * 推客中心信息
     *
     * <p>除推客档案外一并返回概览统计，避免小程序端为几个数字多发几次请求。
     * 未成为推客时 data 为 null，前端据此展示「成为推客」入口。</p>
     */
    /**
     * C1 代理商佣金概览：代理商账号调用，返回名下商户的本月佣金汇总
     * 入参：无（从 token 拿 agentId，再查名下 merchantIds）
     * 返回：{ totalAmount, settledAmount, pendingAmount, commissionCount, merchants: [...] }
     */
    @LoginRequired
    @GetMapping("/agent/summary")
    public AjaxResult agentSummary()
    {
        com.ruoyi.biz.api.domain.LoginMember me = MemberContextHolder.get();
        if (me == null) {
            throw new ServiceException("未登录");
        }
        if (!"1".equals(me.getUserType())) {
            throw new ServiceException("仅代理商账号可调用");
        }
        // 从 tenant context 反查 agentId（LoginMember 没存 agentId 字段）
        com.ruoyi.common.core.domain.model.TenantContext ctx = com.ruoyi.common.utils.TenantContextHolder.get();
        Long agentId = ctx == null ? null : ctx.getAgentId();
        if (agentId == null) {
            throw new ServiceException("账号未绑定代理商");
        }
        // 名下商户
        java.util.List<Long> merchantIds = tenantService.getMerchantIdsByAgentId(agentId);
        // 本月 1 号 00:00:00 ~ 现在
        java.util.Calendar cal = java.util.Calendar.getInstance();
        cal.set(java.util.Calendar.DAY_OF_MONTH, 1);
        cal.set(java.util.Calendar.HOUR_OF_DAY, 0);
        cal.set(java.util.Calendar.MINUTE, 0);
        cal.set(java.util.Calendar.SECOND, 0);
        cal.set(java.util.Calendar.MILLISECOND, 0);
        java.util.Date beginTime = cal.getTime();
        java.util.Date endTime = new java.util.Date();
        java.util.Map<String, Object> overview = commissionService.sumAgentOverview(merchantIds, beginTime, endTime);
        java.util.List<java.util.Map<String, Object>> byMerchant = commissionService.sumByMerchantIds(merchantIds, beginTime, endTime);
        java.util.Map<String, Object> data = new java.util.LinkedHashMap<>();
        data.put("agentId", agentId);
        data.put("merchantCount", merchantIds == null ? 0 : merchantIds.size());
        data.put("beginTime", beginTime);
        data.put("endTime", endTime);
        data.put("totalAmount", overview.get("totalAmount"));
        data.put("settledAmount", overview.get("settledAmount"));
        data.put("pendingAmount", overview.get("pendingAmount"));
        data.put("commissionCount", overview.get("commissionCount"));
        data.put("byMerchant", byMerchant);
        return AjaxResult.success(data);
    }

    @LoginRequired
    @GetMapping("/center")
    public AjaxResult center()
    {
        Distributor distributor = currentDistributor();
        if (distributor == null)
        {
            return AjaxResult.success();
        }

        Commission commissionQuery = new Commission();
        commissionQuery.setDistributorId(distributor.getDistributorId());
        List<Commission> commissions = commissionService.selectCommissionList(commissionQuery);

        Withdraw withdrawQuery = new Withdraw();
        withdrawQuery.setDistributorId(distributor.getDistributorId());
        List<Withdraw> withdraws = withdrawService.selectWithdrawList(withdrawQuery);

        // 提现中的金额 = 待审核(0) + 已通过待打款(1)，与推客表的已提现金额区分开
        BigDecimal withdrawing = BigDecimal.ZERO;
        for (Withdraw item : withdraws)
        {
            if ("0".equals(item.getStatus()) || "1".equals(item.getStatus()))
            {
                withdrawing = withdrawing.add(item.getAmount() == null ? BigDecimal.ZERO : item.getAmount());
            }
        }

        Map<String, Object> data = new LinkedHashMap<String, Object>();
        data.put("distributorId", distributor.getDistributorId());
        data.put("memberId", distributor.getMemberId());
        data.put("memberName", distributor.getMemberName());
        data.put("level", distributor.getLevel());
        data.put("status", distributor.getStatus());
        data.put("joinTime", distributor.getJoinTime());
        data.put("totalCommission", distributor.getTotalCommission());
        data.put("availableAmount", distributor.getAvailableAmount());
        data.put("frozenAmount", distributor.getFrozenAmount());
        data.put("withdrawAmount", distributor.getWithdrawAmount());
        data.put("withdrawingAmount", withdrawing);
        data.put("orderCount", Integer.valueOf(commissions.size()));
        data.put("withdrawCount", Integer.valueOf(withdraws.size()));
        return AjaxResult.success(data);
    }

    /**
     * 成为推客
     */
    @LoginRequired
    @PostMapping("/join")
    public AjaxResult join()
    {
        Distributor exist = currentDistributor();
        if (exist != null)
        {
            return AjaxResult.success(exist);
        }
        Distributor distributor = new Distributor();
        distributor.setMemberId(MemberContextHolder.getMemberId());
        distributor.setLevel(1);
        distributor.setTotalCommission(BigDecimal.ZERO);
        distributor.setAvailableAmount(BigDecimal.ZERO);
        distributor.setFrozenAmount(BigDecimal.ZERO);
        distributor.setWithdrawAmount(BigDecimal.ZERO);
        distributor.setStatus("0");
        distributor.setJoinTime(new Date());
        distributorService.insertDistributor(distributor);
        return AjaxResult.success(distributor);
    }

    /**
     * 佣金明细
     */
    @LoginRequired
    @GetMapping("/commission/list")
    public AjaxResult commissionList()
    {
        Distributor distributor = currentDistributor();
        if (distributor == null)
        {
            return AjaxResult.success(new java.util.ArrayList<Commission>());
        }
        Commission query = new Commission();
        query.setDistributorId(distributor.getDistributorId());
        return AjaxResult.success(commissionService.selectCommissionList(query));
    }

    /**
     * 提现记录
     */
    @LoginRequired
    @GetMapping("/withdraw/list")
    public AjaxResult withdrawList()
    {
        Distributor distributor = currentDistributor();
        if (distributor == null)
        {
            return AjaxResult.success(new java.util.ArrayList<Withdraw>());
        }
        Withdraw query = new Withdraw();
        query.setDistributorId(distributor.getDistributorId());
        return AjaxResult.success(withdrawService.selectWithdrawList(query));
    }

    /**
     * 申请提现
     */
    @LoginRequired
    @PostMapping("/withdraw")
    @Transactional
    public AjaxResult withdraw(@RequestBody JSONObject body)
    {
        Distributor distributor = currentDistributor();
        if (distributor == null)
        {
            throw new ServiceException("您还不是推客");
        }
        BigDecimal amount = body.getBigDecimal("amount");
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0)
        {
            throw new ServiceException("提现金额不合法");
        }
        BigDecimal available = distributor.getAvailableAmount() == null ? BigDecimal.ZERO : distributor.getAvailableAmount();
        if (amount.compareTo(available) > 0)
        {
            throw new ServiceException("可提现余额不足");
        }

        Withdraw withdraw = new Withdraw();
        withdraw.setWithdrawNo("W" + System.currentTimeMillis() + (int) (Math.random() * 900 + 100));
        withdraw.setDistributorId(distributor.getDistributorId());
        withdraw.setAmount(amount);
        withdraw.setWithdrawType(body.getString("withdrawType"));
        withdraw.setAccount(body.getString("account"));
        withdraw.setAccountName(body.getString("accountName"));
        withdraw.setStatus("0");
        withdraw.setApplyTime(new Date());
        withdrawService.insertWithdraw(withdraw);

        // 冻结提现金额
        distributor.setAvailableAmount(available.subtract(amount));
        distributorService.updateDistributor(distributor);
        return AjaxResult.success(withdraw);
    }

    /**
     * 获取推客专属邀请太阳码
     *
     * <p>scene = distributor:{merchantId}:{memberId}，小程序 onShow 解析后回传给后端。
     * 太阳码图片保存到本地 upload/distributor/ 目录，返回相对 URL，前端可直接用于
     * 海报 canvas 绘制 + wx.saveImageToPhotosAlbum。</p>
     */
    @LoginRequired
    @GetMapping("/qrcode")
    public AjaxResult qrcode() throws Exception
    {
        Distributor distributor = currentDistributor();
        if (distributor == null)
        {
            throw new ServiceException("您还不是推客");
        }
        Member member = memberService.selectMemberByMemberId(MemberContextHolder.getMemberId());
        if (member == null)
        {
            throw new ServiceException("会员不存在");
        }
        Long merchantId = member.getMerchantId() == null ? 1L : member.getMerchantId();
        String scene = "distributor:" + merchantId + ":" + member.getMemberId();

        // E10 缓存：按 memberId 复用已生成文件，命中直接返 URL，避免重复调 wxacode
        String dir = RuoYiConfig.getProfile() + "/distributor";
        java.io.File dirFile = new java.io.File(dir);
        if (!dirFile.exists() && !dirFile.mkdirs())
        {
            throw new ServiceException("无法创建太阳码目录");
        }
        String baseName = "qr_" + member.getMemberId();
        java.io.File[] existing = dirFile.listFiles(new java.io.FilenameFilter()
        {
            @Override
            public boolean accept(java.io.File d, String name)
            {
                return name.startsWith(baseName + "_") && name.endsWith(".png");
            }
        });
        if (existing != null && existing.length > 0)
        {
            // 命中：选最近 mtime 的那张
            java.io.File latest = existing[0];
            for (java.io.File f : existing)
            {
                if (f.lastModified() > latest.lastModified()) latest = f;
            }
            String relativePath = "/distributor/" + latest.getName();
            String url = serverConfig.getUrl() + com.ruoyi.common.constant.Constants.RESOURCE_PREFIX + relativePath;
            return AjaxResult.success().put("url", url).put("scene", scene).put("fileName", latest.getName()).put("cached", true);
        }

        // miss：调 wxacode 并落盘
        byte[] bytes = wxMaService.getWxaCodeUnlimited(scene, "pages/index/index", merchantId);
        if (bytes == null || bytes.length == 0)
        {
            throw new ServiceException("生成太阳码失败");
        }
        String fileName = baseName + "_" + System.currentTimeMillis() + ".png";
        java.io.File target = new java.io.File(dir, fileName);
        try (java.io.FileOutputStream fos = new java.io.FileOutputStream(target))
        {
            fos.write(bytes);
        }
        String relativePath = "/distributor/" + fileName;
        String url = serverConfig.getUrl() + com.ruoyi.common.constant.Constants.RESOURCE_PREFIX + relativePath;
        return AjaxResult.success().put("url", url).put("scene", scene).put("fileName", fileName).put("cached", false);
    }

    /**
     * 我的粉丝列表
     *
     * <p>基于 biz_member.invite_by = 当前 member_id 查询，仅返回昵称 / 头像 / 绑定时间。
     * 推客可在推客中心「我的粉丝」入口查看，引导裂变。</p>
     */
    @LoginRequired
    @GetMapping("/fans")
    public AjaxResult fans()
    {
        Distributor distributor = currentDistributor();
        if (distributor == null)
        {
            throw new ServiceException("您还不是推客");
        }
        Member query = new Member();
        query.setInviteBy(MemberContextHolder.getMemberId());
        // 推客档案未填 merchantId 时回退到当前会员的商户（拦截器也会自动追加，但保持显式一致）
        if (distributor.getMerchantId() != null && distributor.getMerchantId() > 0)
        {
            query.setMerchantId(distributor.getMerchantId());
        }
        List<Member> fans = memberService.selectMemberList(query);
        java.util.List<java.util.Map<String, Object>> rows = new java.util.ArrayList<>();
        for (Member fan : fans)
        {
            java.util.Map<String, Object> row = new java.util.LinkedHashMap<>();
            row.put("memberId", fan.getMemberId());
            row.put("nickname", fan.getNickname());
            row.put("avatar", fan.getAvatar());
            row.put("inviteTime", fan.getInviteTime());
            row.put("lastLoginTime", fan.getLastLoginTime());
            rows.add(row);
        }
        return AjaxResult.success(rows).put("total", rows.size());
    }
}
