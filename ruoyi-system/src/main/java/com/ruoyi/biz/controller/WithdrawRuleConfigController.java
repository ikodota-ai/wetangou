package com.ruoyi.biz.controller;

import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.biz.api.service.WithdrawRuleService;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.enums.BusinessType;

/**
 * 提现规则配置Controller（存储于 sys_config）
 *
 * <p>微信小程序审核要求提现页面清晰展示提现规则（可提现额度、每日次数、
 * 受理时间、到账时间等）。规则做成可配而不是写死在代码里，运营改完即时生效，
 * 小程序端 GET /api/distributor/withdraw/rules 读的是同一批 key，
 * 后端申请提现时的校验也读同一批 key —— 页面展示、接口返回、实际拦截三处
 * 永远一致，不会出现「页面写最低 10 元、实际提 1 元也能过」。</p>
 *
 * @author dytuangou
 */
@RestController
@RequestMapping("/biz/withdrawRule")
public class WithdrawRuleConfigController extends BaseSysConfigController
{
    /** 该功能维护的参数键（key -> 参数名称） */
    private static final Map<String, String> KEY_NAMES = new LinkedHashMap<String, String>();
    static
    {
        KEY_NAMES.put(WithdrawRuleService.KEY_MIN_AMOUNT, "单笔最低提现金额");
        KEY_NAMES.put(WithdrawRuleService.KEY_MAX_AMOUNT, "单笔最高提现金额");
        KEY_NAMES.put(WithdrawRuleService.KEY_DAILY_TIMES, "每日提现次数上限");
        KEY_NAMES.put(WithdrawRuleService.KEY_START_HOUR, "提现受理开始小时");
        KEY_NAMES.put(WithdrawRuleService.KEY_END_HOUR, "提现受理结束小时");
        KEY_NAMES.put(WithdrawRuleService.KEY_FEE_RATE, "提现手续费率(%)");
        KEY_NAMES.put(WithdrawRuleService.KEY_ARRIVAL_DESC, "到账时效说明");
    }

    @Autowired
    private WithdrawRuleService withdrawRuleService;

    @Override
    protected Map<String, String> keyNames()
    {
        return KEY_NAMES;
    }

    @Override
    protected String configRemark()
    {
        return "提现规则";
    }

    /**
     * 获取提现规则配置
     *
     * <p>顺带返回 preview —— 也就是小程序提现页会原样展示给用户的条款列表。
     * 运营改完金额/次数能立刻看到用户端看到的是什么文案，避免改错了要等到
     * 打开小程序才发现。</p>
     */
    @PreAuthorize("@ss.hasPermi('biz:withdrawRule:query')")
    @GetMapping
    public AjaxResult get()
    {
        Map<String, Object> data = new LinkedHashMap<String, Object>();
        data.putAll(readConfigs());
        data.put("preview", withdrawRuleService.describe(null, null).get("rules"));
        return AjaxResult.success(data);
    }

    /**
     * 保存提现规则配置
     */
    @PreAuthorize("@ss.hasPermi('biz:withdrawRule:edit')")
    @Log(title = "提现规则", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult save(@RequestBody Map<String, String> body)
    {
        writeConfigs(body);
        return AjaxResult.success();
    }
}
