package com.ruoyi.web.api;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.biz.domain.Agreement;
import com.ruoyi.biz.service.IAgreementService;

/**
 * 小程序-协议（用户/隐私/推客）
 *
 * @author dytuangou
 */
@Anonymous
@RestController
@RequestMapping("/api/agreement")
public class ApiAgreementController
{
    @Autowired
    private IAgreementService agreementService;

    /**
     * 按类型获取协议内容
     */
    @GetMapping
    public AjaxResult get(@RequestParam String type)
    {
        Agreement query = new Agreement();
        query.setAgreementType(type);
        query.setStatus("0");
        List<Agreement> list = agreementService.selectAgreementList(query);
        return AjaxResult.success(list.isEmpty() ? null : list.get(0));
    }
}
