package com.ruoyi.web.api;

import java.util.Calendar;
import java.util.Date;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.biz.api.annotation.LoginRequired;
import com.ruoyi.biz.api.util.MemberContextHolder;
import com.ruoyi.biz.domain.Voucher;
import com.ruoyi.biz.domain.MemberVoucher;
import com.ruoyi.biz.service.IVoucherService;
import com.ruoyi.biz.service.IMemberVoucherService;

/**
 * 小程序-代金券（可领列表、领取、我的代金券）
 *
 * @author dytuangou
 */
@Anonymous
@RestController
@RequestMapping("/api/voucher")
public class ApiVoucherController
{
    @Autowired
    private IVoucherService voucherService;

    @Autowired
    private IMemberVoucherService memberVoucherService;

    /**
     * 可领代金券列表
     */
    @GetMapping("/list")
    public AjaxResult list(@RequestParam(required = false) Long storeId,
                           @RequestParam(required = false) String voucherName)
    {
        Voucher query = new Voucher();
        query.setStatus("0");
        query.setStoreId(storeId);
        // 领券中心问的是「这家店能领哪些券」，本店专属券之外还要带上全门店通用券。
        // 原先直接复用了 admin 的精确匹配语义，于是 store_id=0 的通用券
        // 在小程序里一张都领不到（首页「领券中心」入口是带 storeId 进来的）。
        java.util.Map<String, Object> params = new java.util.HashMap<>();
        params.put("includeAnyStore", true);
        query.setParams(params);
        // 模糊搜索：与 admin /biz/voucher/list 行为对齐（VoucherMapper 已支持 LIKE）
        if (StringUtils.isNotEmpty(voucherName))
        {
            query.setVoucherName(voucherName);
        }
        return AjaxResult.success(voucherService.selectVoucherList(query));
    }

    /**
     * 领取代金券
     */
    @LoginRequired
    @PostMapping("/receive/{voucherId}")
    @Transactional
    public AjaxResult receive(@PathVariable Long voucherId)
    {
        Voucher voucher = voucherService.selectVoucherByVoucherId(voucherId);
        if (voucher == null || !"0".equals(voucher.getStatus()))
        {
            throw new ServiceException("代金券不存在或已停用");
        }
        if (voucher.getTotal() != null && voucher.getTotal() > 0
                && voucher.getReceived() != null && voucher.getReceived() >= voucher.getTotal())
        {
            throw new ServiceException("代金券已被领完");
        }
        // 模板有效期：valid_from / valid_to 原先建了字段但领取时从没读过，
        // 于是活动结束的券还能继续领，领到手还是「30 天有效」的新券。
        Date nowTime = new Date();
        if (voucher.getValidFrom() != null && voucher.getValidFrom().after(nowTime))
        {
            throw new ServiceException("活动未开始");
        }
        if (voucher.getValidTo() != null && voucher.getValidTo().before(nowTime))
        {
            throw new ServiceException("活动已结束");
        }
        // 同一会员不可重复领取同一张券（已使用/已过期的允许重领）
        MemberVoucher dupQuery = new MemberVoucher();
        dupQuery.setVoucherId(voucherId);
        dupQuery.setMemberId(MemberContextHolder.getMemberId());
        dupQuery.setStatus("0");
        if (!memberVoucherService.selectMemberVoucherList(dupQuery).isEmpty())
        {
            throw new ServiceException("您已领取该代金券，可在「我的代金券」中查看");
        }

        MemberVoucher mv = new MemberVoucher();
        mv.setVoucherId(voucherId);
        mv.setMemberId(MemberContextHolder.getMemberId());
        mv.setFaceValue(voucher.getFaceValue());
        mv.setThreshold(voucher.getThreshold());
        mv.setStatus("0");
        mv.setGetTime(nowTime);
        if (voucher.getValidDays() != null && voucher.getValidDays() > 0)
        {
            Calendar cal = Calendar.getInstance();
            cal.add(Calendar.DAY_OF_MONTH, voucher.getValidDays());
            mv.setExpireTime(cal.getTime());
        }
        else
        {
            mv.setExpireTime(voucher.getValidTo());
        }
        memberVoucherService.insertMemberVoucher(mv);

        voucher.setReceived((voucher.getReceived() == null ? 0 : voucher.getReceived()) + 1);
        voucherService.updateVoucher(voucher);
        return AjaxResult.success(mv);
    }

    /**
     * 我的代金券
     */
    @LoginRequired
    @GetMapping("/my")
    public AjaxResult my(@RequestParam(required = false) String status)
    {
        MemberVoucher query = new MemberVoucher();
        query.setMemberId(MemberContextHolder.getMemberId());
        query.setStatus(status);
        List<MemberVoucher> list = memberVoucherService.selectMemberVoucherList(query);
        return AjaxResult.success(list);
    }
}
