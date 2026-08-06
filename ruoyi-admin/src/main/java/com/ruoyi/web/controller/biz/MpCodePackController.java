package com.ruoyi.web.controller.biz;

import java.io.IOException;
import java.io.OutputStream;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

import jakarta.servlet.http.HttpServletResponse;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.biz.mapper.MerchantMapper;
import com.ruoyi.biz.service.IMpCodePackService;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;

/**
 * 小程序代码包下载（传统发布流程）
 *
 * <p>在「未接入微信第三方平台」阶段，商家必须自己上传代码到微信公众平台。
 * 后台提供一键打包：把 miniprogram7 模板里写死的 appid / BASE_URL 替换成对应商家的值，
 * 打成 zip 让商家下载导入微信开发者工具。</p>
 *
 * <p>与 /biz/mprelease/* 的关系：mprelease 是状态机（待提交/审核/发布），本接口是产物下载。</p>
 *
 * @author dytuangou
 */
@RestController
@RequestMapping("/biz/codepack")
public class MpCodePackController extends BaseController
{
    @Autowired
    private IMpCodePackService mpCodePackService;

    @Autowired
    private MerchantMapper merchantMapper;

    /**
     * 下载代码包（流式返回 zip）
     *
     * @param merchantId 商家 ID
     * @param baseUrl    API 地址（必填）。生产 https://api.wetangou.com；测试 http://192.168.x.x:8080
     */
    @PreAuthorize("@ss.hasPermi('biz:mprelease:upload')")
    @GetMapping("/{merchantId}")
    public void download(@PathVariable("merchantId") Long merchantId,
                         @RequestParam("baseUrl") String baseUrl,
                         HttpServletResponse response) throws IOException
    {
        Merchant merchant = merchantMapper.selectMerchantByMerchantId(merchantId);
        if (merchant == null)
        {
            throw new ServiceException("商家不存在 id=" + merchantId);
        }
        if (StringUtils.isEmpty(merchant.getAppid()))
        {
            throw new ServiceException("商家未配置 appid（biz_merchant.appid 为空），请先在「商户管理」里填写");
        }

        byte[] zip = mpCodePackService.buildCodePack(merchant, baseUrl);
        String fileName = mpCodePackService.defaultFileName(merchant);
        String encoded = URLEncoder.encode(fileName, StandardCharsets.UTF_8).replace("+", "%20");

        response.setContentType("application/zip");
        response.setContentLength(zip.length);
        response.setHeader("Content-Disposition", "attachment; filename=\"" + fileName + "\"; filename*=UTF-8''" + encoded);
        response.setHeader("Cache-Control", "no-cache");

        try (OutputStream os = response.getOutputStream())
        {
            os.write(zip);
            os.flush();
        }
    }

    /**
     * 预览：检查商家 appid 是否配置，以及生成文件名
     * 供前端在点击「下载」前先调一次，能立即给出友好提示
     */
    @PreAuthorize("@ss.hasPermi('biz:mprelease:upload')")
    @GetMapping("/preview/{merchantId}")
    public AjaxResult preview(@PathVariable("merchantId") Long merchantId)
    {
        Merchant merchant = merchantMapper.selectMerchantByMerchantId(merchantId);
        if (merchant == null)
        {
            return error("商家不存在 id=" + merchantId);
        }
        java.util.Map<String, Object> data = new java.util.LinkedHashMap<>();
        data.put("merchantId", merchant.getMerchantId());
        data.put("merchantNo", merchant.getMerchantNo());
        data.put("merchantName", merchant.getMerchantName());
        data.put("appid", merchant.getAppid());
        data.put("appidConfigured", StringUtils.isNotEmpty(merchant.getAppid()));
        data.put("defaultFileName", mpCodePackService.defaultFileName(merchant));
        return success(data);
    }
}
