package com.ruoyi.web.api;

import java.nio.charset.StandardCharsets;
import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.util.Base64;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.alibaba.fastjson2.JSONObject;
import com.ruoyi.biz.api.config.WxOpenConfig;
import com.ruoyi.biz.api.service.WxOpenService;
import com.ruoyi.biz.domain.MpAuth;
import com.ruoyi.biz.service.IMpAuthService;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.service.ISysConfigService;

/**
 * 微信开放平台第三方平台回调
 *
 * <p>暴露三个端点给微信侧：
 * <ul>
 *   <li>GET /api/mpopen/authorize  —— 商户扫码授权入口（拼装授权 URL 后 302 跳转）</li>
 *   <li>POST /api/mpopen/callback   —— 授权事件接收 URL（每 10 分钟推 component_verify_ticket + 授权成功通知）</li>
 *   <li>GET /api/mpopen/callback    —— 验证 URL 有效性时返回 echostr</li>
 * </ul>
 * </p>
 *
 * <p>所有端点 @Anonymous（微信服务器调用，无 token），由 IP 白名单 + AES-256-CBC 签名保障安全。</p>
 */
@Anonymous
@RestController
@RequestMapping("/api/mpopen")
public class MpOpenCallbackController
{
    private static final Logger log = LoggerFactory.getLogger(MpOpenCallbackController.class);

    @Autowired
    private WxOpenService wxOpenService;

    @Autowired
    private WxOpenConfig wxOpenConfig;

    @Autowired
    private ISysConfigService sysConfigService;

    @Autowired
    private IMpAuthService mpAuthService;

    /**
     * 拼装授权 URL 并返回，前端用 window.location 跳转
     *
     * <p>前端调用：<code>GET /api/mpopen/authorize?redirect=/biz/mpauth</code></p>
     */
    @GetMapping("/authorize")
    public AjaxResult authorize(@RequestParam(value = "redirect", required = false) String redirect)
    {
        if (!wxOpenService.isConfigured())
        {
            return AjaxResult.error("未配置第三方平台 componentAppId/secret");
        }
        // 回调到当前服务，由前端 history.back() 拿 authorization_code
        String callback = StringUtils.isEmpty(redirect) ? "/api/mpopen/auth-code" : "/api/mpopen/auth-code?redirect=" + redirect;
        // 全路径（在 controller 里直接拼 base url）
        String fullCallback = "http://localhost" + callback; // 真实部署需要替换为公网域名
        String url = wxOpenService.buildAuthorizationUrl(fullCallback, 2);
        return AjaxResult.success().put("url", url);
    }

    /**
     * 授权回调：微信跳回来带 auth_code，用 code 换 authorizer_refresh_token 落库
     */
    @GetMapping("/auth-code")
    public AjaxResult authCode(@RequestParam(value = "auth_code", required = false) String authCode,
                               @RequestParam(value = "expires_in", required = false) Integer expiresIn,
                               @RequestParam(value = "redirect", required = false) String redirect)
    {
        if (StringUtils.isEmpty(authCode))
        {
            return AjaxResult.error("授权码为空");
        }
        // 用 auth_code 换 authorizer_refresh_token
        String componentToken = wxOpenService.getComponentAccessToken();
        String url = "https://api.weixin.qq.com/cgi-bin/component/api_query_auth?component_access_token=" + componentToken;
        JSONObject body = new JSONObject();
        body.put("component_appid", wxOpenConfig.getComponentAppId());
        body.put("authorization_code", authCode);
        String resp = com.ruoyi.common.utils.http.HttpUtils.sendPost(url, body.toJSONString(), "application/json");
        JSONObject json = JSONObject.parseObject(resp);
        if (json == null || json.getInteger("errcode") != null && json.getInteger("errcode") != 0)
        {
            log.error("[MpOpenCallback] 换 refresh_token 失败：{}", resp);
            return AjaxResult.error("授权失败：" + resp);
        }
        JSONObject authInfo = json.getJSONObject("authorization_info");
        if (authInfo == null)
        {
            return AjaxResult.error("授权信息为空");
        }
        String appid = authInfo.getString("authorizer_appid");
        String refreshToken = authInfo.getString("authorizer_refresh_token");
        String nickName = authInfo.getJSONObject("userinfo") == null ? "" : authInfo.getJSONObject("userinfo").getString("nick_name");
        // 落库
        MpAuth auth = mpAuthService.selectMpAuthByAppid(appid);
        if (auth == null)
        {
            auth = new MpAuth();
            auth.setAppid(appid);
        }
        auth.setRefreshToken(refreshToken);
        auth.setNickName(nickName);
        auth.setAuthStatus("0");
        if (auth.getAuthId() == null)
        {
            mpAuthService.insertMpAuth(auth);
        }
        else
        {
            mpAuthService.updateMpAuth(auth);
        }
        return AjaxResult.success("授权成功", auth);
    }

    /**
     * 验证 URL 有效性（GET 回调）
     * 微信首次配置回调 URL 时会带 echostr 验证，返回原文即可
     */
    @GetMapping("/callback")
    public String verifyCallbackUrl(@RequestParam("echostr") String echostr)
    {
        return echostr;
    }

    /**
     * 接收微信推送（每 10 分钟一次 component_verify_ticket + 授权成功/取消事件）
     * 报文为 AES-256-CBC 加密（PKCS#7），密钥是 componentEncodingAesKey（base64 解码后 32 字节）
     */
    @PostMapping("/callback")
    public String onCallback(@RequestBody String xmlBody)
    {
        try
        {
            String decrypted = decryptMessage(xmlBody);
            if (decrypted == null)
            {
                return "success";
            }
            // 解析 component_verify_ticket
            if (decrypted.contains("component_verify_ticket"))
            {
                int s = decrypted.indexOf("<ComponentVerifyTicket><![CDATA[");
                if (s > 0)
                {
                    s += "<ComponentVerifyTicket><![CDATA[".length();
                    int e = decrypted.indexOf("]]></ComponentVerifyTicket>", s);
                    if (e > s)
                    {
                        String ticket = decrypted.substring(s, e);
                        wxOpenService.setComponentVerifyTicket(ticket);
                        log.info("[MpOpenCallback] verify_ticket 已保存，长度={}", ticket.length());
                    }
                }
            }
            return "success";
        }
        catch (Exception ex)
        {
            log.error("[MpOpenCallback] 处理失败", ex);
            return "success"; // 微信要求非空即视为成功
        }
    }

    /**
     * 解密微信 AES-256-CBC 加密消息
     */
    private String decryptMessage(String encryptedBase64) throws Exception
    {
        String aesKeyBase64 = sysConfigService.selectConfigByKey("wx.open.componentAesKey");
        if (StringUtils.isEmpty(aesKeyBase64) || aesKeyBase64.length() < 43)
        {
            throw new ServiceException("未配置 componentAesKey");
        }
        // 微信 EncodingAESKey 是 43 位 base64，加 "=" 补齐到 44 位再解码
        if (aesKeyBase64.length() == 43)
        {
            aesKeyBase64 = aesKeyBase64 + "=";
        }
        byte[] aesKey = Base64.getDecoder().decode(aesKeyBase64);
        byte[] cipherBytes = Base64.getDecoder().decode(encryptedBase64);
        // 前 16 字节是 IV
        IvParameterSpec iv = new IvParameterSpec(aesKey, 0, 16);
        SecretKeySpec key = new SecretKeySpec(aesKey, "AES");
        Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5Padding");
        cipher.init(Cipher.DECRYPT_MODE, key, iv);
        byte[] plain = cipher.doFinal(cipherBytes);
        String result = new String(plain, StandardCharsets.UTF_8);
        // 去掉 PKCS#7 padding
        int pad = result.charAt(result.length() - 1);
        if (pad >= 1 && pad <= 32)
        {
            result = result.substring(0, result.length() - pad);
        }
        return result;
    }
}
