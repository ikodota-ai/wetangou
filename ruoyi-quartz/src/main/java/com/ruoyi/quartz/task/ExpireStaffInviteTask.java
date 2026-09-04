package com.ruoyi.quartz.task;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import com.ruoyi.biz.service.IMerchantStaffInviteService;

/**
 * 员工邀请码过期自动失效
 *
 * <p>{@code IMerchantStaffInviteService.expireOverdue()} 早就写好了，但从来
 * 没有人调用它 —— 只有单条的 {@code markExpired(inviteId)} 在
 * {@code ApiMerchantStaffController} 扫码时惰性触发。结果：</p>
 * <ul>
 *   <li>没人扫的过期码永远停在 status='0'（实测本地积压 52 个），后台
 *       员工邀请列表里一片「待使用」，店长根本分不清哪个还能用；</li>
 *   <li>邀请码列表的二维码按钮按 status 判断是否 disabled，过期码不置 '2'
 *       就还是可点的，店长把废码发出去、员工扫了才报错。</li>
 * </ul>
 *
 * <p>Quartz 调用：{@code expireStaffInviteTask.ryNoParams()}，建议 Cron
 * 每小时（{@code 0 5 * * * ?}）—— 邀请码有效期按小时/天计，不需要更密。</p>
 *
 * @author dytuangou
 */
@Component("expireStaffInviteTask")
public class ExpireStaffInviteTask
{
    private static final Logger log = LoggerFactory.getLogger(ExpireStaffInviteTask.class);

    @Autowired
    private IMerchantStaffInviteService inviteService;

    public void ryNoParams()
    {
        int rows = inviteService.expireOverdue();
        log.info("[ExpireStaffInviteTask] 过期邀请码失效 rows={}", rows);
    }
}
