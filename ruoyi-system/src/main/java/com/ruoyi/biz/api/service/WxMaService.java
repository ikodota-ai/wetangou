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

    /** 小程序 URL Scheme 生成接口（用于「微信扫一扫」直达） */
    private static final String WXA_SCHEME_URL = "https://api.weixin.qq.com/wxa/generatescheme";

    /** 小程序短链生成接口（压短 Scheme 到 32 字符内） */
    private static final String WXA_SHORT_URL = "https://api.weixin.qq.com/cgi-bin/shorturl";

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
        // 本地联调模式：mock 开关开启时直接用 code 派生 openid（即便有 appId 也优先 mock，
        // 避免真实微信 code 过期/无效时无法联调）
        if (wxMaConfig.isMockEnabled(merchantId))
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
/**
     * 发送订阅消息（核销成功通知 / 退款通知等）
     *
     * @param openid 接收者 openid
     * @param templateId 微信公众平台模板 ID
     * @param merchantId 商户 ID（用于多租户路由到正确 appId）
     * @param data 模板字段 { key1: { value: "..." }, ... }
     * @return 微信返回的 msgid；失败抛 ServiceException
     */
    public String sendSubscribeMessage(String openid, String templateId, Long merchantId, java.util.Map<String, java.util.Map<String, String>> data)
    {
        if (StringUtils.isEmpty(openid)) throw new ServiceException("openid 不能为空");
        if (StringUtils.isEmpty(templateId)) throw new ServiceException("templateId 不能为空");
        if (data == null || data.isEmpty()) throw new ServiceException("模板数据不能为空");
        // mock 模式：直接 log 后返回 fake msgid
        if (wxMaConfig.isMockEnabled(merchantId)) {
            log.info("[WxMaService] mock sendSubscribeMessage to={} tpl={} data={}", openid, templateId, data);
            return "mock_msg_" + System.currentTimeMillis();
        }
        // 真实模式：POST https://api.weixin.qq.com/cgi-bin/message/subscribe/send
        String accessToken = getAccessToken(merchantId);
        String url = "https://api.weixin.qq.com/cgi-bin/message/subscribe/send?access_token=" + accessToken;
        com.alibaba.fastjson2.JSONObject body = new com.alibaba.fastjson2.JSONObject();
        body.put("touser", openid);
        body.put("template_id", templateId);
        body.put("data", data);
        String resp = com.ruoyi.common.utils.http.HttpUtils.sendPost(url, body.toJSONString());
        com.alibaba.fastjson2.JSONObject json = com.alibaba.fastjson2.JSONObject.parseObject(resp);
        if (json == null || json.getInteger("errcode") == null || json.getInteger("errcode") != 0) {
            throw new ServiceException("订阅消息发送失败：" + resp);
        }
        return json.getString("msgid");
    }

    public String getPhoneNumberByCode(String phoneCode)
    {
        return getPhoneNumberByCode(phoneCode, null);
    }

    /**
     * 换取微信授权手机号
     *
     * @param phoneCode  前端 getPhoneNumber 回调里的 code
     * @param merchantId 当前会员所属商户；决定用哪套 appId/secret 去换 access_token
     */
    public String getPhoneNumberByCode(String phoneCode, Long merchantId)
    {
        if (StringUtils.isEmpty(phoneCode))
        {
            throw new ServiceException("手机号授权code不能为空");
        }
        // 本地联调模式：无真实appId时返回mock手机号，便于全链路测试
        if (wxMaConfig.isMockEnabled() && StringUtils.isEmpty(wxMaConfig.getAppId(merchantId)))
        {
            log.info("[WxMaService] mock获取手机号，phoneCode={}", phoneCode);
            return "13800000000";
        }
        // 必须把 merchantId 传下去。原来写死 getAccessToken(null)，
        // 而 getAppId(null)/getSecret(null) 只读全局 sys_config 参数 ——
        // 多商户版的 appId/secret 是配在 biz_merchant 表里的，
        // 全局参数为空时就抛「未配置小程序appId/secret」，
        // 于是后台明明在「微信配置」里填好了，取手机号照样失败。
        String accessToken = getAccessToken(merchantId);
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
        if (wxMaConfig.isMockEnabled(merchantId))
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
        body.put("width", 430);
        // check_path=false：不校验 page 是否真实存在。必须关，否则未发布的小程序
        // 任何 page 都被判为不存在。
        body.put("check_path", false);
        // env_version 必须显式传。不传时微信按 "release"（线上已发布版本）处理，
        // 小程序还没发布过就没有 release 版本，微信返
        // {"errcode":40066,"errmsg":"invalid url"} —— 错误码指向 url/page，
        // 实际 page 路径是对的，缺的是"已发布"这个前提，极易误判成路径写错。
        // 未发布阶段后台「微信配置」填 trial 即可扫体验版，上线后改回 release。
        body.put("env_version", wxMaConfig.getEnvVersion());
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

    /**
     * 生成小程序 URL Scheme（用于「微信扫一扫」直达核销页）
     *
     * <p>店员扫桌上的核销二维码（内容是 Scheme URL）→ 微信自动唤起小程序
     * → 跳到 pages/merchant/verify/index?code=xxx&sid=xxx → 自动核销。</p>
     *
     * <p>真上线调用 https://api.weixin.qq.com/wxa/generatescheme；mock 模式直接拼
     * weixin://dl/business/?appid=xxx&path=xxx&query=xxx 字符串返回（微信识别 OK）。</p>
     *
     * @param page    小程序页面路径（如 pages/merchant/verify/index）
     * @param query   query 串（如 code=138F31FA1271&sid=200）
     * @param permanent true=永久有效（每天 50w 配额），false=最长 30 天
     * @param merchantId 商户 ID（路由到正确 appId）
     * @return Scheme URL
     */
    public String generateScheme(String page, String query, boolean permanent, Long merchantId)
    {
        if (StringUtils.isEmpty(page)) throw new ServiceException("page 不能为空");
        String appid = wxMaConfig.getAppId(merchantId);

        // mock 模式：直接拼 weixin:// URL，便于本地调试 + smoke 端到端
        if (wxMaConfig.isMockEnabled(merchantId)) {
            String url = "weixin://dl/business/?appid=" + appid
                + "&path=" + java.net.URLEncoder.encode(page, java.nio.charset.StandardCharsets.UTF_8);
            if (StringUtils.isNotEmpty(query)) {
                url += "&query=" + java.net.URLEncoder.encode(query, java.nio.charset.StandardCharsets.UTF_8);
            }
            log.info("[WxMaService] mock generateScheme appid={} page={} query={} -> {}", appid, page, query, url);
            return url;
        }

        // 真实模式：POST https://api.weixin.qq.com/wxa/generatescheme
        String accessToken = getAccessToken(merchantId);
        String url = WXA_SCHEME_URL + "?access_token=" + accessToken;
        com.alibaba.fastjson2.JSONObject body = new com.alibaba.fastjson2.JSONObject();
        body.put("jump_wxa", true);
        body.put("expire_type", permanent ? 0 : 1);
        if (!permanent) {
            body.put("expire_interval", 30); // 30 天
        }
        body.put("path", page);
        if (StringUtils.isNotEmpty(query)) {
            body.put("query", query);
        }
        // 同 getWxaCodeUnlimited：不传 env_version 微信按"线上已发布版本"处理，
        // 小程序未发布时生成的 Scheme 扫开是「该小程序未发布」。
        // 店员扫桌上核销码走的就是这条链，所以这里也必须跟着走同一个开关。
        body.put("env_version", wxMaConfig.getEnvVersion());
        String resp = com.ruoyi.common.utils.http.HttpUtils.sendPost(url, body.toJSONString());
        com.alibaba.fastjson2.JSONObject json = com.alibaba.fastjson2.JSONObject.parseObject(resp);
        if (json == null || json.getInteger("errcode") == null || json.getInteger("errcode") != 0) {
            throw new ServiceException("生成 Scheme 失败：" + resp);
        }
        String openlink = json.getString("openlink");
        if (StringUtils.isEmpty(openlink)) {
            throw new ServiceException("生成 Scheme 失败：openlink 为空");
        }
        log.info("[WxMaService] generateScheme appid={} page={} -> {}", appid, page, openlink);
        return openlink;
    }

    /**
     * 把 Scheme URL 压成短链（cgi-bin/shorturl 限制 32 字符内）
     */
    public String shortenUrl(String longUrl, Long merchantId)
    {
        if (StringUtils.isEmpty(longUrl)) throw new ServiceException("url 不能为空");
        if (wxMaConfig.isMockEnabled(merchantId)) {
            // mock：直接 base62 短串 + .link 后缀，模拟微信短链
            String fake = "weixin://s/" + Long.toString(Math.abs((long) longUrl.hashCode()), 36);
            log.info("[WxMaService] mock shortenUrl {} -> {}", longUrl, fake);
            return fake;
        }
        String accessToken = getAccessToken(merchantId);
        String url = WXA_SHORT_URL + "?access_token=" + accessToken;
        com.alibaba.fastjson2.JSONObject body = new com.alibaba.fastjson2.JSONObject();
        body.put("action", "long2short");
        body.put("long_url", longUrl);
        String resp = com.ruoyi.common.utils.http.HttpUtils.sendPost(url, body.toJSONString());
        com.alibaba.fastjson2.JSONObject json = com.alibaba.fastjson2.JSONObject.parseObject(resp);
        if (json == null || json.getInteger("errcode") == null || json.getInteger("errcode") != 0) {
            throw new ServiceException("短链生成失败：" + resp);
        }
        return json.getString("short_url");
    }
}
