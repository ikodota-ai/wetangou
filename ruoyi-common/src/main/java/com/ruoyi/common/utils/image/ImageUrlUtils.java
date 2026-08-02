package com.ruoyi.common.utils.image;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.BeansException;
import org.springframework.context.ApplicationContext;
import org.springframework.context.ApplicationContextAware;
import org.springframework.stereotype.Component;
import com.ruoyi.common.utils.ServletUtils;

/**
 * 图片 URL 工具
 *
 * <p>把数据库中存储的相对路径（例如 {@code /profile/upload/demo/banner1.jpg}）拼成
 * 完整的可访问 URL（{@code http://127.0.0.1:8080/profile/upload/demo/banner1.jpg}）。</p>
 *
 * <p>前端 &lt;el-image :src&gt; / &lt;img src&gt; 在浏览器原生加载图片时，
 * 不会走 webpack-dev-server 的 proxy（只在 XHR / fetch 层面代理）。
 * 因此在 dev / prod / 小程序 webview 环境下，统一返回绝对 URL 是最稳的方案。</p>
 *
 * <p>本工具放在 ruoyi-common，使用 {@link ApplicationContextAware} 在运行时通过 bean 名称查找
 * {@code serverConfig}（位于 ruoyi-framework）。这样既避免 ruoyi-common → ruoyi-framework
 * 的循环依赖，也保持业务代码（ruoyi-system / ruoyi-admin）调用方式简单。</p>
 */
@Component
public class ImageUrlUtils implements ApplicationContextAware
{
    /** ruoyi-framework 中 ServerConfig 的 bean 名称（小写首字母）。 */
    private static final String SERVER_CONFIG_BEAN = "serverConfig";

    private static ApplicationContext applicationContext;

    @Override
    public void setApplicationContext(ApplicationContext applicationContext) throws BeansException
    {
        ImageUrlUtils.applicationContext = applicationContext;
    }

    /**
     * 把相对路径补全为绝对 URL。
     * 已经是 http(s):// 开头的直接返回；null / 空串原样返回。
     */
    public static String toAbsolute(String path)
    {
        if (path == null || path.isEmpty())
        {
            return path;
        }
        if (path.startsWith("http://") || path.startsWith("https://"))
        {
            return path;
        }
        if (path.startsWith("/profile/") || path.startsWith("/dev-api/"))
        {
            String base = resolveBaseUrl();
            if (base == null)
            {
                return path;
            }
            return base + path;
        }
        return path;
    }

    /**
     * 通过当前请求的 Host/Port 拼接 baseURL（不依赖 ruoyi-framework 中的 ServerConfig，
     * 避免 ruoyi-common → ruoyi-framework 的循环依赖）。
     */
    private static String resolveBaseUrl()
    {
        try
        {
            HttpServletRequest request = ServletUtils.getRequest();
            if (request == null)
            {
                return null;
            }
            StringBuffer url = request.getRequestURL();
            String contextPath = request.getServletContext().getContextPath();
            int uriLen = request.getRequestURI().length();
            return url.delete(url.length() - uriLen, url.length()).append(contextPath).toString();
        }
        catch (Exception e)
        {
            return null;
        }
    }
}
