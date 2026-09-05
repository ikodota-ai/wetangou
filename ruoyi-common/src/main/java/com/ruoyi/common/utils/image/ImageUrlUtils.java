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
     * 逗号串版的 {@link #toAbsolute(String)}。
     *
     * <p>biz_product.cover 存的是「商品头图」逗号串（PC 建品页 image-upload
     * :limit=5），不是单张 URL。直接丢给 toAbsolute 只会在整串头上拼一个
     * base，得出 {@code http://host/profile/a.jpg,/profile/b.jpg} —— 第二张以后
     * 全部还是相对路径，小程序端拆串后那几张必然加载不出来。</p>
     *
     * <p>库里当下 cover 含逗号的是 0 条，所以这个问题还没被触发；
     * 它是定时炸弹，不是已发生故障。</p>
     */
    public static String toAbsoluteCsv(String csv)
    {
        if (csv == null || csv.isEmpty() || csv.indexOf(',') < 0)
        {
            return toAbsolute(csv);
        }
        String[] parts = csv.split(",");
        StringBuilder sb = new StringBuilder();
        for (String part : parts)
        {
            String one = part.trim();
            if (one.isEmpty())
            {
                continue;
            }
            if (sb.length() > 0)
            {
                sb.append(',');
            }
            sb.append(toAbsolute(one));
        }
        return sb.toString();
    }

    /**
     * 头图首张（给只能存一张图的字段用，比如下单时快照到
     * biz_order.product_cover，那列只有 varchar(255)）。
     */
    public static String firstImage(String csv)
    {
        if (csv == null || csv.isEmpty())
        {
            return csv;
        }
        for (String part : csv.split(","))
        {
            String one = part.trim();
            if (!one.isEmpty())
            {
                return one;
            }
        }
        return "";
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
