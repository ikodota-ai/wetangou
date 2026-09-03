package com.ruoyi.biz.api.config;

import java.lang.reflect.Field;

import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import com.ruoyi.system.service.ISysConfigService;

/**
 * 小程序码指向版本（wx.miniapp.envVersion）的取值归一化单测
 *
 * <p>为什么值得单独护住：这个开关决定微信 getwxacodeunlimited 的 env_version。
 * 不传 / 传错时微信按 "release"（线上已发布版本）处理，而小程序还没发布过时
 * 根本不存在 release 版本，微信返 {"errcode":40066,"errmsg":"invalid url"} ——
 * 用户看到的是「生成小程序码失败」，错误码却指向 url/page，极易被误判成
 * page 路径写错（实测就误判过一轮）。所以这里锁住三件事：</p>
 *
 * <ul>
 *   <li>空 / null → release：保持加这个开关之前的老行为，不能因为没配就崩</li>
 *   <li>trial / develop / release 原样返回，且大小写与前后空格不敏感
 *       —— 后台是 radio，但 sys_config 可以被人手工改成 " Trial "</li>
 *   <li>非法值一律退回 release，绝不把不认识的字符串透传给微信，
 *       否则换来的是另一个更难查的错误码</li>
 * </ul>
 *
 * <p>不起 Spring、不连库：把 sysConfigService 换成动态代理桩，
 * 反射塞进 @Autowired 字段，CI 上无库也能跑。</p>
 */
@DisplayName("小程序码指向版本: envVersion 归一化")
class WxMaEnvVersionTest
{
    /** 造一个只认 wx.miniapp.envVersion 这个 key 的 sysConfigService 桩 */
    private WxMaConfig configReturning(final String stored) throws Exception
    {
        WxMaConfig cfg = new WxMaConfig();
        ISysConfigService stub = (ISysConfigService) java.lang.reflect.Proxy.newProxyInstance(
                ISysConfigService.class.getClassLoader(),
                new Class<?>[]{ISysConfigService.class},
                (proxy, method, args) -> {
                    if ("selectConfigByKey".equals(method.getName())
                            && args != null && args.length == 1
                            && WxMaConfig.KEY_ENV_VERSION.equals(args[0]))
                    {
                        return stored;
                    }
                    Class<?> rt = method.getReturnType();
                    if (rt == boolean.class) return false;
                    if (rt == int.class) return 0;
                    return null;
                });
        Field f = WxMaConfig.class.getDeclaredField("sysConfigService");
        f.setAccessible(true);
        f.set(cfg, stub);
        return cfg;
    }

    @Test
    @DisplayName("未配置 / 空串 → release（老行为不变）")
    void missingFallsBackToRelease() throws Exception
    {
        Assertions.assertEquals("release", configReturning(null).getEnvVersion());
        Assertions.assertEquals("release", configReturning("").getEnvVersion());
        Assertions.assertEquals("release", configReturning("   ").getEnvVersion());
    }

    @Test
    @DisplayName("三个合法值原样返回")
    void legalValuesPassThrough() throws Exception
    {
        Assertions.assertEquals("trial", configReturning("trial").getEnvVersion());
        Assertions.assertEquals("develop", configReturning("develop").getEnvVersion());
        Assertions.assertEquals("release", configReturning("release").getEnvVersion());
    }

    @Test
    @DisplayName("大小写 / 前后空格不敏感（sys_config 可能被手工改）")
    void trimAndLowercase() throws Exception
    {
        Assertions.assertEquals("trial", configReturning(" Trial ").getEnvVersion());
        Assertions.assertEquals("develop", configReturning("DEVELOP").getEnvVersion());
    }

    @Test
    @DisplayName("非法值退回 release，不透传给微信")
    void illegalValueFallsBackToRelease() throws Exception
    {
        Assertions.assertEquals("release", configReturning("prod").getEnvVersion());
        Assertions.assertEquals("release", configReturning("体验版").getEnvVersion());
        Assertions.assertEquals("release", configReturning("1").getEnvVersion());
    }
}
