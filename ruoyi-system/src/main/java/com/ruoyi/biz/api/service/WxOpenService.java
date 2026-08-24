package com.ruoyi.biz.api.service;

import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Service;
import com.alibaba.fastjson2.JSONObject;
import com.ruoyi.biz.api.config.WxOpenConfig;
import com.ruoyi.biz.domain.MpAuth;
import com.ruoyi.biz.service.IMpAuthService;
import com.ruoyi.common.core.redis.RedisCache;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.common.utils.http.HttpUtils;

/**
 * 微信开放平台第三方平台服务：
 * - 拉取 component_access_token（缓存）
 * - 用 authorizer_refresh_token 换 authorizer_access_token（缓存）
 * - 真实调用提审 / 发布 / 回退等接口
 *
 * <p>component_verify_ticket 由微信每 10 分钟推送一次（回调地址），
 * 这里先提供缓存与查询入口，回调处理留作后续接入。
 * 没有配置 component_appid/secret 时所有方法走 no-op，由调用方降级为 mock 状态流转。</p>
 */
@Service
public class WxOpenService
{
    private static final Logger log = LoggerFactory.getLogger(WxOpenService.class);

    private static final String COMPONENT_TOKEN_KEY = "wx:open:component_access_token";
    private static final String AUTHORIZER_TOKEN_KEY_PREFIX = "wx:open:authorizer_access_token:";
    /** component_verify_ticket Redis 缓存 key（每 10 分钟微信推一次，保存到 Redis） */
    private static final String VERIFY_TICKET_KEY = "wx:open:component_verify_ticket";
    private static final String COMPONENT_API = "https://api.weixin.qq.com/cgi-bin/component/api_component_token";
    private static final String AUTHORIZER_TOKEN_API = "https://api.weixin.qq.com/cgi-bin/component/api_authorizer_token";
    private static final String SUBMIT_AUDIT_API = "https://api.weixin.qq.com/wxa/submitaudit";
    private static final String RELEASE_API = "https://api.weixin.qq.com/wxa/release";
    private static final String REVERT_RELEASE_API = "https://api.weixin.qq.com/wxa/revertcoderelease";
    private static final String COMMIT_API = "https://api.weixin.qq.com/wxa/commit";
    private static final String PRE_AUTH_CODE_API = "https://api.weixin.qq.com/cgi-bin/component/api_create_preauthcode";
    private static final String GET_AUTHORIZER_INFO_API = "https://api.weixin.qq.com/cgi-bin/component/api_get_authorizer_info";
    /** preauthcode 缓存 key */
    private static final String PRE_AUTH_CODE_KEY = "wx:open:pre_auth_code";
    private static final String MOBILE_AUTH_URL = "https://mp.weixin.qq.com/safebindoperation";
    private static final int TICKET_TTL_SECONDS = 12 * 60;

    @Autowired
    private WxOpenConfig wxOpenConfig;

    @Autowired
    private RedisCache redisCache;

    @Autowired
    @Lazy
    private IMpAuthService mpAuthService;

    @Autowired
    @Lazy
    private com.ruoyi.system.service.ISysConfigService sysConfigService;

    /**
     * 第三方平台是否已配置（componentAppid/secret 都齐全）
     */
    public boolean isConfigured()
    {
        return StringUtils.isNotEmpty(wxOpenConfig.getComponentAppId())
                && StringUtils.isNotEmpty(wxOpenConfig.getComponentSecret());
    }

    /**
     * 由回调 controller 写入最新的 verify_ticket
     */
    public void setComponentVerifyTicket(String ticket)
    {
        if (StringUtils.isEmpty(ticket))
        {
            return;
        }
        redisCache.setCacheObject(VERIFY_TICKET_KEY, ticket, TICKET_TTL_SECONDS, TimeUnit.SECONDS);
        // 同步持久化到 sys_config（防止 Redis 重启后丢失，微信侧 12 小时才过期）
        try
        {
            com.ruoyi.system.domain.SysConfig sc = new com.ruoyi.system.domain.SysConfig();
            sc.setConfigKey(WxOpenConfig.KEY_VERIFY_TICKET);
            sc.setConfigValue(ticket);
            sysConfigService.updateConfig(sc);
        }
        catch (Exception e)
        {
            log.warn("[WxOpenService] 同步 verify_ticket 到 sys_config 失败：{}", e.getMessage());
        }
    }

    private String getVerifyTicketFromCache()
    {
        String v = redisCache.getCacheObject(VERIFY_TICKET_KEY);
        if (StringUtils.isNotEmpty(v))
        {
            return v;
        }
        // Redis 丢失时回退到 sys_config
        return wxOpenConfig.getComponentVerifyTicket();
    }

    /**
     * 拿 component_access_token，缓存到 Redis。
     * verify_ticket 优先从 Redis 取（10 分钟刷新），回退到 sys_config。
     */
    public String getComponentAccessToken()
    {
        if (!isConfigured())
        {
            throw new ServiceException("未配置第三方平台 componentAppId/secret");
        }
        String cached = redisCache.getCacheObject(COMPONENT_TOKEN_KEY);
        if (StringUtils.isNotEmpty(cached))
        {
            return cached;
        }
        JSONObject body = new JSONObject();
        body.put("component_appid", wxOpenConfig.getComponentAppId());
        body.put("component_appsecret", wxOpenConfig.getComponentSecret());
        body.put("component_verify_ticket", getVerifyTicketFromCache());
        String resp = HttpUtils.sendPost(COMPONENT_API, body.toJSONString(), "application/json");
        JSONObject json = JSONObject.parseObject(resp);
        if (json == null || StringUtils.isEmpty(json.getString("component_access_token")))
        {
            throw new ServiceException("获取 component_access_token 失败：" + resp);
        }
        String token = json.getString("component_access_token");
        int ttl = Math.max(json.getIntValue("expires_in") - 300, 60);
        redisCache.setCacheObject(COMPONENT_TOKEN_KEY, token, ttl, TimeUnit.SECONDS);
        return token;
    }

    /**
     * 用 authorizer_refresh_token 换 authorizer_access_token，按 appid 缓存
     *
     * @param appid 授权方小程序 appid
     * @param authorizerRefreshToken 长期有效的 refresh_token（来自 biz_mp_auth）
     */
    public String getAuthorizerAccessToken(String appid, String authorizerRefreshToken)
    {
        if (!isConfigured())
        {
            throw new ServiceException("未配置第三方平台 componentAppId/secret");
        }
        if (StringUtils.isEmpty(appid) || StringUtils.isEmpty(authorizerRefreshToken))
        {
            throw new ServiceException("appid / refresh_token 不能为空");
        }
        String key = AUTHORIZER_TOKEN_KEY_PREFIX + appid;
        String cached = redisCache.getCacheObject(key);
        if (StringUtils.isNotEmpty(cached))
        {
            return cached;
        }
        String componentToken = getComponentAccessToken();
        JSONObject body = new JSONObject();
        body.put("component_appid", wxOpenConfig.getComponentAppId());
        body.put("authorizer_appid", appid);
        body.put("authorizer_refresh_token", authorizerRefreshToken);
        String url = AUTHORIZER_TOKEN_API + "?component_access_token=" + componentToken;
        String resp = HttpUtils.sendPost(url, body.toJSONString(), "application/json");
        JSONObject json = JSONObject.parseObject(resp);
        if (json == null || StringUtils.isEmpty(json.getString("authorizer_access_token")))
        {
            throw new ServiceException("获取 authorizer_access_token 失败：" + resp);
        }
        String token = json.getString("authorizer_access_token");
        int ttl = Math.max(json.getIntValue("expires_in") - 300, 60);
        redisCache.setCacheObject(key, token, ttl, TimeUnit.SECONDS);
        // 微信同时返回新的 refresh_token（轮换），必须写回数据库。
        // 原实现只打日志、注释说"由调用方落库"，但没有任何调用方做这件事，
        // 结果轮换后库里仍是旧 refresh_token —— 旧值失效后提审/发布会直接 401。
        // refresh_token 是长期凭据，落库失败不该连带整个取 token 流程失败，故单独 try。
        String newRefresh = json.getString("authorizer_refresh_token");
        if (StringUtils.isNotEmpty(newRefresh) && !newRefresh.equals(authorizerRefreshToken))
        {
            log.info("[WxOpenService] authorizer_refresh_token 已轮换，appid={}", appid);
            try
            {
                saveAuthorizerRefreshToken(appid, newRefresh);
            }
            catch (Exception e)
            {
                log.error("[WxOpenService] refresh_token 轮换落库失败 appid={}，下次调用仍会用旧值，需人工核对", appid, e);
            }
        }
        return token;
    }

    /**
     * 提交审核（/wxa/submitaudit）
     */
    public JSONObject submitAudit(String authorizerAccessToken, String appid, JSONObject item)
    {
        String url = SUBMIT_AUDIT_API + "?access_token=" + authorizerAccessToken;
        // 微信要求 authorizer_access_token 用 access_token 字段名
        item.put("authorizer_access_token", authorizerAccessToken);
        item.put("appid", appid);
        String resp = HttpUtils.sendPost(url, item.toJSONString(), "application/json");
        return JSONObject.parseObject(resp);
    }

    /**
     * 发布（/wxa/release）
     */
    public JSONObject release(String authorizerAccessToken, String appid)
    {
        String url = RELEASE_API + "?access_token=" + authorizerAccessToken;
        JSONObject body = new JSONObject();
        body.put("appid", appid);
        String resp = HttpUtils.sendPost(url, body.toJSONString(), "application/json");
        return JSONObject.parseObject(resp);
    }

    /**
     * 回退已发布版本（/wxa/revertcoderelease）
     */
    public JSONObject revertRelease(String authorizerAccessToken, String appid)
    {
        String url = REVERT_RELEASE_API + "?access_token=" + authorizerAccessToken;
        JSONObject body = new JSONObject();
        body.put("appid", appid);
        String resp = HttpUtils.sendPost(url, body.toJSONString(), "application/json");
        return JSONObject.parseObject(resp);
    }

    /**
     * 拼装 ext_json（<b>已废弃，请勿使用</b>）
     *
     * <p>零调用点。真正生效的是
     * {@code MpReleaseServiceImpl.buildExtJson(Merchant)} —— 它产出的是带
     * extAppid / extEnable / ext 的完整结构，并落到 biz_mp_release.ext_json。</p>
     *
     * <p>这里的实现还有两处错：<br>
     * 1) 只返回 ext 内层，缺 extAppid / extEnable 外层，微信 /wxa/commit 不认；<br>
     * 2) 域名键名写成 {@code apiBaseUrl}，而小程序端
     * {@code miniprogram7/utils/config.js} 读的是 {@code ext.baseUrl}，键名对不上，
     * 用它注入的话小程序拿不到域名会静默回落到默认值。</p>
     *
     * <p>保留而不删除：仅为避免外部若有反射/脚本引用而破坏兼容；
     * 新代码一律走 MpReleaseServiceImpl。
     * 确认无引用后可直接删掉本方法。</p>
     *
     * @deprecated 改用 {@code IMpReleaseService.buildExtJson(Long merchantId)}
     */
    @Deprecated
    public JSONObject buildExtJson(Long merchantId, String appid, String apiBaseUrl)
    {
        JSONObject ext = new JSONObject();
        ext.put("merchantId", merchantId);
        ext.put("appid", appid);
        ext.put("apiBaseUrl", apiBaseUrl);
        return ext;
    }

    /**
     * 调用 /wxa/commit 上传小程序代码
     *
     * <p><b>尚未接入</b>：当前零调用点。MpReleaseServiceImpl 已接
     * submitAudit / release / revertRelease，独缺这一步，
     * 而微信侧的顺序是 commit（上传代码模板）→ submitaudit（提审）→ release（发布），
     * 没 commit 就提审会报「无待审核版本」。
     * 接第三方平台代发布时必须在 submitAudit 之前调用本方法。
     * 保留实现是为了那一步到来时直接可用，不是死代码。</p>
     *
     * @param authorizerAccessToken 授权方 token
     * @param appid                 授权方 appid
     * @param templateId            模板 ID
     * @param extJson               注入的 ext_json（JSONObject）
     * @param userVersion           版本号
     * @param userDesc              版本描述
     */
    public JSONObject commit(String authorizerAccessToken, String appid, String templateId, JSONObject extJson, String userVersion, String userDesc)
    {
        JSONObject body = new JSONObject();
        body.put("appid", appid);
        body.put("template_id", templateId);
        body.put("ext_json", extJson);
        body.put("user_version", userVersion);
        body.put("user_desc", userDesc);
        String url = COMMIT_API + "?access_token=" + authorizerAccessToken;
        String resp = HttpUtils.sendPost(url, body.toJSONString(), "application/json");
        return JSONObject.parseObject(resp);
    }

    /**
     * 拿预授权码 preauthcode（10 分钟有效，缓存到 Redis 9 分钟）
     * 用于拼装授权 URL：前端跳到该 URL 让商户管理员扫码授权
     */
    public String getPreAuthCode()
    {
        if (!isConfigured())
        {
            throw new ServiceException("未配置第三方平台 componentAppId/secret");
        }
        String cached = redisCache.getCacheObject(PRE_AUTH_CODE_KEY);
        if (StringUtils.isNotEmpty(cached))
        {
            return cached;
        }
        String componentToken = getComponentAccessToken();
        String url = PRE_AUTH_CODE_API + "?component_access_token=" + componentToken;
        JSONObject resp = JSONObject.parseObject(HttpUtils.sendGet(url));
        if (resp == null || StringUtils.isEmpty(resp.getString("pre_auth_code")))
        {
            throw new ServiceException("获取 pre_auth_code 失败：" + resp);
        }
        String code = resp.getString("pre_auth_code");
        redisCache.setCacheObject(PRE_AUTH_CODE_KEY, code, 9 * 60, TimeUnit.SECONDS);
        return code;
    }

    /**
     * 拼装商户扫码授权 URL（移动端 / PC 扫码均可）
     *
     * @param redirectUri 授权后回调地址
     * @param authType    1 表示仅展示授权页，2 表示点击授权，3 表示直接授权
     */
    public String buildAuthorizationUrl(String redirectUri, int authType)
    {
        String preAuthCode = getPreAuthCode();
        StringBuilder url = new StringBuilder(MOBILE_AUTH_URL);
        url.append("?action=bindcomponent&component_appid=").append(wxOpenConfig.getComponentAppId());
        url.append("&pre_auth_code=").append(preAuthCode);
        url.append("&redirect_uri=").append(java.net.URLEncoder.encode(redirectUri, java.nio.charset.StandardCharsets.UTF_8));
        url.append("&auth_type=").append(authType);
        return url.toString();
    }

    /**
     * 拿授权方小程序信息（昵称 / 头像 / 主体名 / 验证类型）
     * 用于授权回调中获取 refresh_token 后回填 biz_mp_auth
     *
     * <p><b>尚未接入</b>：当前零调用点。MpOpenCallbackController 处理授权回调时
     * 只存了 refresh_token，没回填昵称/主体名，所以「小程序授权」列表里
     * 这些字段要靠人工录入。后续应在授权回调成功后调用本方法自动补齐。</p>
     */
    public JSONObject getAuthorizerInfo(String authorizerAccessToken, String appid)
    {
        JSONObject body = new JSONObject();
        body.put("component_appid", wxOpenConfig.getComponentAppId());
        body.put("authorizer_appid", appid);
        String url = GET_AUTHORIZER_INFO_API + "?component_access_token=" + getComponentAccessToken();
        String resp = HttpUtils.sendPost(url, body.toJSONString(), "application/json");
        return JSONObject.parseObject(resp);
    }

    /**
     * authorizer_refresh_token 轮换后落库
     *
     * <p>由 {@link #getAuthorizerAccessToken(String, String)} 在检测到轮换时调用。</p>
     */
    public void saveAuthorizerRefreshToken(String appid, String refreshToken)
    {
        MpAuth auth = mpAuthService.selectMpAuthByAppid(appid);
        if (auth == null)
        {
            log.warn("[WxOpenService] refresh_token 轮换但找不到 appid={} 的授权记录", appid);
            return;
        }
        auth.setRefreshToken(refreshToken);
        mpAuthService.updateMpAuth(auth);
        log.info("[WxOpenService] refresh_token 已落库 appid={}", appid);
    }
}
