package com.ruoyi.testsupport;

import java.sql.Connection;
import java.sql.DriverManager;

/**
 * 测试用 MySQL 可用性探测。
 *
 * <p>本仓库的 mapper 单测刻意不用 H2/mock —— 它们要验证的正是真实 MySQL 上
 * MyBatis 动态 SQL 的行为（例如空 list 时 {@code IN ()} 会语法错、
 * {@code merchantIdsEmpty} guard 是否真的生成 {@code 1=0}）。换成内存库就失去意义。</p>
 *
 * <p>代价是这些测试需要一个真实 MySQL。CI runner（macos-14）上没有，
 * 且 GitHub Actions 的 service container 是 Linux-only 特性，在 macOS runner 上无效。
 * 因此测试用 {@link org.junit.jupiter.api.Assumptions} 在无库时优雅跳过（skipped 而非 failed）：
 * 本地有库照常跑真 SQL，CI 无库不会把流水线弄红。</p>
 *
 * <p>连接参数可用环境变量覆盖，便于将来在带 MySQL 的 runner 上真跑：
 * {@code TEST_DB_URL} / {@code TEST_DB_USERNAME} / {@code TEST_DB_PASSWORD}。
 * 各测试类的 {@code @TestPropertySource} 用同名 {@code ${TEST_DB_URL:...}} 占位符读同一组变量
 * （注解里不能用 SpEL，所以默认值在两处各写一份，改的时候要同步）。</p>
 */
public final class TestDb
{
    /** 默认连本地开发库（与 application-druid.yml 一致） */
    public static final String DEFAULT_URL =
            "jdbc:mysql://127.0.0.1:3306/ry-vue?useUnicode=true&characterEncoding=utf8"
            + "&useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true";
    public static final String DEFAULT_USERNAME = "root";
    public static final String DEFAULT_PASSWORD = "133301";

    /** 探测结果缓存：一次测试 JVM 内只连一次，避免每个测试方法都付 2s 超时 */
    private static volatile Boolean available;

    private TestDb()
    {
    }

    public static String url()
    {
        return env("TEST_DB_URL", DEFAULT_URL);
    }

    public static String username()
    {
        return env("TEST_DB_USERNAME", DEFAULT_USERNAME);
    }

    public static String password()
    {
        return env("TEST_DB_PASSWORD", DEFAULT_PASSWORD);
    }

    private static String env(String key, String dft)
    {
        String v = System.getenv(key);
        return (v == null || v.isEmpty()) ? dft : v;
    }

    /**
     * 数据库是否可连接（带 2 秒超时，结果缓存）。
     *
     * @return true 表示可以跑依赖真库的测试
     */
    public static boolean available()
    {
        if (available != null)
        {
            return available;
        }
        synchronized (TestDb.class)
        {
            if (available == null)
            {
                available = probe();
            }
        }
        return available;
    }

    private static boolean probe()
    {
        int oldTimeout = DriverManager.getLoginTimeout();
        try
        {
            DriverManager.setLoginTimeout(2);
            try (Connection c = DriverManager.getConnection(url(), username(), password()))
            {
                return c != null && !c.isClosed();
            }
        }
        catch (Throwable e)
        {
            // 连不上就是不可用；不区分「没装 / 没起 / 密码错」，测试一律跳过
            return false;
        }
        finally
        {
            DriverManager.setLoginTimeout(oldTimeout);
        }
    }

    /** 供 Assumptions 用的跳过原因 */
    public static String skipReason()
    {
        return "跳过：需要真实 MySQL（" + url() + "）。"
             + "本地起库后会自动跑；CI 无库时跳过而非失败。"
             + "可用 TEST_DB_URL / TEST_DB_USERNAME / TEST_DB_PASSWORD 覆盖。";
    }
}
