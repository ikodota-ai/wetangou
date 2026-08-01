package com.ruoyi.biz.api.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.alibaba.fastjson2.JSONObject;
import com.ruoyi.common.core.redis.RedisCache;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.common.utils.http.HttpUtils;
import com.ruoyi.biz.api.config.WxMaConfig;
import java.util.concurrent.TimeUnit;

/**
 * 微信小程序服务：code2session、手机号获取等
 *
 * <p>手机号采用微信新版 getPhoneNumber 流程：前端 button open-type="getPhoneNumber"
 * 返回动态令牌 code，后端通过 access_token 调用 phonenumber/getPhoneNumber 换取手机号，
 * 无需再对 encryptedData/iv 做本地解密，避免引入额外加密依赖。</p>
 *
 * @author dytuangou
 */
@Service
public class WxMaService
{
    private static final Logger log = LoggerFactory.getLogger(WxMaService.class);

    private static final String CODE2SESSION_URL = "https://api.weixin.qq.com/sns/jscode2session";

    private static final String ACCESS_TOKEN_URL = "https://api.weixin.qq.com/cgi-bin/token";

    private static final String PHONE_URL = "https://api.weixin.qq.com/wxa/business/getuserphonenumber";

    /** access_token 缓存key */
    private static final String ACCESS_TOKEN_KEY = "wx:miniapp:access_token";

    /** 小程序码（无限制）接口 */
    private static final String WXACODE_URL = "https://api.weixin.qq.com/wxa/getwxacodeunlimited";

    @Autowired
    private WxMaConfig wxMaConfig;

    @Autowired
    private RedisCache redisCache;

    /**
     * 通过登录code换取openid/session_key
     *
     * @param jsCode 小程序wx.login返回的code
     * @return JSONObject，含openid、session_key、unionid
     */
    public JSONObject code2Session(String jsCode)
    {
        return code2Session(jsCode, null);
    }

    /**
     * 通过登录code换取openid/session_key（多商户：使用指定商户的appId/secret）
     *
     * @param jsCode 小程序wx.login返回的code
     * @param merchantId 商户ID，为空时使用全局配置
     * @return JSONObject，含openid、session_key、unionid
     */
    public JSONObject code2Session(String jsCode, Long merchantId)
    {
        if (StringUtils.isEmpty(jsCode))
        {
            throw new ServiceException("登录code不能为空");
        }
        String appId = wxMaConfig.getAppId(merchantId);
        String secret = wxMaConfig.getSecret(merchantId);
        // 本地联调模式：无真实appId时，用code派生openid，便于全链路测试
        if (wxMaConfig.isMockEnabled(merchantId) && StringUtils.isEmpty(appId))
        {
            JSONObject mock = new JSONObject();
            mock.put("openid", "mock_" + jsCode);
            mock.put("session_key", "mock_session");
            log.info("[WxMaService] mock登录，openid=mock_{}", jsCode);
            return mock;
        }
        String param = StringUtils.format("appid={}&secret={}&js_code={}&grant_type=authorization_code",
                appId, secret, jsCode);
        String resp = HttpUtils.sendGet(CODE2SESSION_URL, param);
        JSONObject json = JSONObject.parseObject(resp);
        if (json == null || json.getString("openid") == null)
        {
            throw new ServiceException("微信登录失败：" + resp);
        }
        return json;
    }

    /**
     * 通过手机号动态令牌code换取手机号（微信新版getPhoneNumber流程）
     *
     * @param phoneCode 前端 bindgetphonenumber 回调返回的 code
     * @return 纯手机号（不含区号）
     */
    public String getPhoneNumberByCode(String phoneCode)
    {
        if (StringUtils.isEmpty(phoneCode))
        {
            throw new ServiceException("手机号授权code不能为空");
        }
        // 本地联调模式：无真实appId时返回mock手机号，便于全链路测试
        if (wxMaConfig.isMockEnabled() && StringUtils.isEmpty(wxMaConfig.getAppId()))
        {
            log.info("[WxMaService] mock获取手机号，phoneCode={}", phoneCode);
            return "13800000000";
        }
        String accessToken = getAccessToken(null);
        JSONObject body = new JSONObject();
        body.put("code", phoneCode);
        String url = PHONE_URL + "?access_token=" + accessToken;
        String resp = HttpUtils.sendPost(url, body.toJSONString());
        JSONObject json = JSONObject.parseObject(resp);
        if (json == null || json.getIntValue("errcode") != 0)
        {
            throw new ServiceException("获取手机号失败：" + resp);
        }
        JSONObject phoneInfo = json.getJSONObject("phone_info");
        if (phoneInfo == null)
        {
            throw new ServiceException("获取手机号失败：" + resp);
        }
        return phoneInfo.getString("purePhoneNumber");
    }

    /**
     * 生成小程序太阳码（无数量限制）
     *
     * <p>scene 格式约定：distributor:{merchantId}:{memberId}。
     * 长度不能超过 32 字符，merchantId 与 memberId 都用纯数字。
     * 返回图片二进制（PNG），调用方自行保存为文件或转 base64。</p>
     *
     * @param scene 场景值，32 字符内
     * @param page 小程序页面（可选，例如 pages/index/index）
     * @param merchantId 商户ID，决定走哪个小程序的 access_token
     * @return 太阳码图片二进制
     */
    public byte[] getWxaCodeUnlimited(String scene, String page, Long merchantId)
    {
        if (StringUtils.isEmpty(scene))
        {
            throw new ServiceException("scene 不能为空");
        }
        if (scene.length() > 32)
        {
            throw new ServiceException("scene 长度不能超过 32 字符");
        }
        if (wxMaConfig.isMockEnabled(merchantId) && StringUtils.isEmpty(wxMaConfig.getAppId(merchantId)))
        {
            log.info("[WxMaService] mock 模式返回 1x1 透明 PNG, scene={}", scene);
            // 1x1 透明 PNG，便于联调时前端仍能拿到图片链接
            return new byte[]{(byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
                    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, (byte) 0xC4,
                    (byte) 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, (byte) 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
                    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, (byte) 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, (byte) 0xAE,
                    0x42, 0x60, (byte) 0x82};
        }
        String accessToken = getAccessToken(merchantId);
        JSONObject body = new JSONObject();
        body.put("scene", scene);
        if (StringUtils.isNotEmpty(page))
        {
            body.put("page", page);
        }
        // 280x280 太阳码 + 圆形头像缩进；不传 env_version 默认"release"
        body.put("width", 430);
        body.put("check_path", false);
        String url = WXACODE_URL + "?access_token=" + accessToken;
        byte[] bytes = HttpUtils.sendPostBytes(url, body.toJSONString(), "application/json");
        if (bytes == null || bytes.length == 0)
        {
            throw new ServiceException("生成小程序码失败：微信接口无响应");
        }
        // 微信错误时仍以 JSON 返回（content-type: application/json），
        // 成功时返回 image/png 二进制
        if (bytes.length > 0 && bytes[0] == '{')
        {
            String text = new String(bytes, java.nio.charset.StandardCharsets.UTF_8);
            JSONObject json = JSONObject.parseObject(text);
            if (json != null && json.getIntValue("errcode") != 0)
            {
                throw new ServiceException("生成小程序码失败：" + text);
            }
        }
        return bytes;
    }

    /**
     * 多商户版 access_token 缓存
     *
     * <p>多商户场景下不同 appid 的 access_token 必须分别缓存，
     * 避免串号。先兼容单 appid（merchantId 为空时复用原 key）。</p>
     */
    public String getAccessToken(Long merchantId)
    {
        String key = merchantId == null ? ACCESS_TOKEN_KEY : ACCESS_TOKEN_KEY + ":" + merchantId;
        String cached = redisCache.getCacheObject(key);
        if (StringUtils.isNotEmpty(cached))
        {
            return cached;
        }
        String appId = wxMaConfig.getAppId(merchantId);
        String secret = wxMaConfig.getSecret(merchantId);
        if (StringUtils.isEmpty(appId) || StringUtils.isEmpty(secret))
        {
            throw new ServiceException("未配置小程序appId/secret");
        }
        String param = StringUtils.format("grant_type=client_credential&appid={}&secret={}", appId, secret);
        String resp = HttpUtils.sendGet(ACCESS_TOKEN_URL, param);
        JSONObject json = JSONObject.parseObject(resp);
        if (json == null || StringUtils.isEmpty(json.getString("access_token")))
        {
            throw new ServiceException("获取access_token失败：" + resp);
        }
        String accessToken = json.getString("access_token");
        int expiresIn = json.getIntValue("expires_in");
        int ttl = Math.max(expiresIn - 300, 60);
        redisCache.setCacheObject(key, accessToken, ttl, TimeUnit.SECONDS);
        return accessToken;
    }
}
