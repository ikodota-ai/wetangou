package com.ruoyi.biz.api.util;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import com.ruoyi.common.core.redis.RedisCache;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.common.utils.uuid.IdUtils;
import com.ruoyi.biz.api.domain.LoginMember;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import jakarta.servlet.http.HttpServletRequest;

/**
 * 小程序会员令牌服务（与后台管理token隔离，独立缓存前缀与密钥载荷）
 *
 * @author dytuangou
 */
@Component
public class MemberTokenService
{
    protected static final long MILLIS_SECOND = 1000;

    protected static final long MILLIS_MINUTE = 60 * MILLIS_SECOND;

    private static final Long MILLIS_MINUTE_TEN = 20 * 60 * 1000L;

    /** 会员token缓存前缀 */
    public static final String MEMBER_TOKEN_KEY = "member_tokens:";

    /** 令牌载荷中的会员标识key */
    public static final String MEMBER_LOGIN_KEY = "member_login_key";

    /** 请求头 */
    private static final String HEADER = "Authorization";

    private static final String TOKEN_PREFIX = "Bearer ";

    @Value("${token.secret}")
    private String secret;

    /** 会员token有效期（分钟），默认7天 */
    @Value("${token.memberExpireTime:10080}")
    private int expireTime;

    @Autowired
    private RedisCache redisCache;

    /**
     * 获取当前请求的登录会员
     */
    public LoginMember getLoginMember(HttpServletRequest request)
    {
        String token = getToken(request);
        if (StringUtils.isNotEmpty(token))
        {
            try
            {
                Claims claims = parseToken(token);
                String uuid = (String) claims.get(MEMBER_LOGIN_KEY);
                String key = getTokenKey(uuid);
                return redisCache.getCacheObject(key);
            }
            catch (Exception e)
            {
                return null;
            }
        }
        return null;
    }

    /**
     * 创建会员令牌
     */
    public String createToken(LoginMember loginMember)
    {
        String token = IdUtils.fastUUID();
        loginMember.setToken(token);
        refreshToken(loginMember);

        Map<String, Object> claims = new HashMap<>();
        claims.put(MEMBER_LOGIN_KEY, token);
        return Jwts.builder().setClaims(claims).signWith(SignatureAlgorithm.HS512, secret).compact();
    }

    /**
     * 刷新令牌有效期并写入缓存
     */
    public void refreshToken(LoginMember loginMember)
    {
        loginMember.setLoginTime(System.currentTimeMillis());
        loginMember.setExpireTime(loginMember.getLoginTime() + expireTime * MILLIS_MINUTE);
        String key = getTokenKey(loginMember.getToken());
        redisCache.setCacheObject(key, loginMember, expireTime, TimeUnit.MINUTES);
    }

    /**
     * 验证令牌有效期，相差不足20分钟自动刷新
     */
    public void verifyToken(LoginMember loginMember)
    {
        long expire = loginMember.getExpireTime();
        long current = System.currentTimeMillis();
        if (expire - current <= MILLIS_MINUTE_TEN)
        {
            refreshToken(loginMember);
        }
    }

    /**
     * 删除会员令牌（登出）
     */
    public void delLoginMember(String token)
    {
        if (StringUtils.isNotEmpty(token))
        {
            redisCache.deleteObject(getTokenKey(token));
        }
    }

    private Claims parseToken(String token)
    {
        return Jwts.parser().setSigningKey(secret).parseClaimsJws(token).getBody();
    }

    private String getToken(HttpServletRequest request)
    {
        String token = request.getHeader(HEADER);
        if (StringUtils.isNotEmpty(token) && token.startsWith(TOKEN_PREFIX))
        {
            token = token.replace(TOKEN_PREFIX, "");
        }
        return token;
    }

    private String getTokenKey(String uuid)
    {
        return MEMBER_TOKEN_KEY + uuid;
    }
}
