package com.ruoyi.framework.security.handle;

import java.io.IOException;
import java.io.Serializable;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;
import com.alibaba.fastjson2.JSON;
import com.ruoyi.common.constant.HttpStatus;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.utils.StringUtils;

/**
 * 认证失败处理类 返回未授权
 *
 * <p>改造：直接用 response.getOutputStream() 写字节，绕过 Tomcat 11 nested fat-jar
 * 下偶发触发的 C2BConverter / ApplicationContext$DispatchData ClassNotFoundException。
 * 旧实现通过 ServletUtils.renderString -> response.getWriter() 在容器错误页
 * (ErrorPage[errorCode=0, location=/error]) 重新走过滤器链时偶发崩溃，导致 401 路径退化成 500。</p>
 *
 * @author ruoyi
 */
@Component
public class AuthenticationEntryPointImpl implements AuthenticationEntryPoint, Serializable
{
    private static final long serialVersionUID = -8970718410437077606L;

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response, AuthenticationException e)
            throws IOException
    {
        int code = HttpStatus.UNAUTHORIZED;
        String msg = StringUtils.format("请求访问：{}，认证失败，无法访问系统资源", request.getRequestURI());
        String body = JSON.toJSONString(AjaxResult.error(code, msg));
        String charset = response.getCharacterEncoding();
        if (charset == null || charset.isEmpty())
        {
            charset = "UTF-8";
        }
        try
        {
            byte[] bytes = body.getBytes(charset);
            response.setStatus(401);
            response.setContentType("application/json;charset=" + charset);
            response.setContentLength(bytes.length);
            response.getOutputStream().write(bytes);
            response.getOutputStream().flush();
        }
        catch (Throwable t)
        {
            // 容器异常路径上再次失败时，放弃写 body，框架/反代会兜底
        }
    }
}
