package com.ruoyi.biz.api.service;

import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Service;
import com.alibaba.fastjson2.JSONObject;
import com.ruoyi.biz.api.config.WxOpenConfig;
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
    private static final String COMPONENT_API = "https://api.weixin.qq.com/cgi-bin/component/api_component_token";
    private static final String AUTHORIZER_TOKEN_API = "https://api.weixin.qq.com/cgi-bin/component/api_authorizer_token";
    private static final String SUBMIT_AUDIT_API = "https://api.weixin.qq.com/wxa/submitaudit";
    private static final String RELEASE_API = "https://api.weixin.qq.com/wxa/release";
    private static final String REVERT_RELEASE_API = "https://api.weixin.qq.com/wxa/revertcoderelease";

    @Autowired
    private WxOpenConfig wxOpenConfig;

    @Autowired
    private RedisCache redisCache;

    /**
     * 第三方平台是否已配置（componentAppid/secret 都齐全）
     */
    public boolean isConfigured()
    {
        return StringUtils.isNotEmpty(wxOpenConfig.getComponentAppId())
                && StringUtils.isNotEmpty(wxOpenConfig.getComponentSecret());
    }

    /**
     * 拿 component_access_token，缓存到 Redis。
     * 同时会刷新 component_verify_ticket：真实接入时该值由回调维护，
     * 这里仅做 get 接口暴露给回调使用。
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
        body.put("component_verify_ticket", wxOpenConfig.getComponentVerifyTicket());
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
        // 微信同时返回新的 refresh_token（轮换），写回数据库
        String newRefresh = json.getString("authorizer_refresh_token");
        if (StringUtils.isNotEmpty(newRefresh) && !newRefresh.equals(authorizerRefreshToken))
        {
            log.info("[WxOpenService] authorizer_refresh_token 已轮换，appid={}", appid);
            // 调用方需在事务中落库；这里只 log，由调用方传回 service 处理
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
}
