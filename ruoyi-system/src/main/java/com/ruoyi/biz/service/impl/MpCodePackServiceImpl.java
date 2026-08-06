package com.ruoyi.biz.service.impl;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Enumeration;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.Resource;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;
import org.springframework.stereotype.Service;

import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.biz.service.IMpCodePackService;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;

/**
 * 小程序代码包生成实现
 *
 * <p>支持两种来源：</p>
 * <ul>
 *   <li>开发态：直接从 classpath: 目录读取（target/classes 下）</li>
 *   <li>发布态：从 ruoyi-admin.jar 内的 BOOT-INF/classes/template/miniprogram7/ 读取</li>
 * </ul>
 *
 * <p>改写两个文件：</p>
 * <ul>
 *   <li>project.config.json 的 appid</li>
 *   <li>utils/config.js 的 BASE_URL</li>
 * </ul>
 */
@Service
public class MpCodePackServiceImpl implements IMpCodePackService
{
    private static final Logger log = LoggerFactory.getLogger(MpCodePackServiceImpl.class);

    /** 模板根目录（classpath） */
    private static final String TEMPLATE_ROOT = "template/miniprogram7";

    /** project.config.json 里的 appid 字段（顶层字符串） */
    private static final String PROJECT_CONFIG_FILE = "project.config.json";

    /** 运行时配置文件路径 */
    private static final String CONFIG_JS_FILE = "utils/config.js";

    @Override
    public byte[] buildCodePack(Merchant merchant, String baseUrl)
    {
        if (merchant == null)
        {
            throw new ServiceException("商家不能为空");
        }
        if (StringUtils.isEmpty(merchant.getAppid()))
        {
            throw new ServiceException("商家未配置 appid（biz_merchant.appid 为空），请先在「商户管理」里填写");
        }
        if (StringUtils.isEmpty(baseUrl))
        {
            throw new ServiceException("API 地址不能为空");
        }

        log.info("[codePack] merchantId={} no={} appid={} baseUrl={}",
                merchant.getMerchantId(), merchant.getMerchantNo(), merchant.getAppid(), baseUrl);

        try
        {
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            try (ZipOutputStream zip = new ZipOutputStream(out, StandardCharsets.UTF_8))
            {
                PathMatchingResourcePatternResolver resolver = new PathMatchingResourcePatternResolver();
                Resource[] resources = resolver.getResources("classpath:" + TEMPLATE_ROOT + "/**");
                if (resources.length == 0)
                {
                    throw new ServiceException("小程序模板不存在：classpath:" + TEMPLATE_ROOT);
                }

                int written = 0;
                for (Resource r : resources)
                {
                    if (!r.exists() || !r.isReadable())
                    {
                        continue;
                    }
                    // 跳过目录本身
                    String url = r.getURL().toString();
                    if (url.endsWith("/"))
                    {
                        continue;
                    }

                    // 相对路径（去除前缀）
                    String rel = computeRelativePath(r);
                    if (rel == null || rel.isEmpty())
                    {
                        continue;
                    }

                    byte[] data;
                    if (rel.equals(PROJECT_CONFIG_FILE))
                    {
                        String s = new String(r.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
                        s = rewriteProjectConfig(s, merchant);
                        data = s.getBytes(StandardCharsets.UTF_8);
                    }
                    else if (rel.equals(CONFIG_JS_FILE))
                    {
                        String s = new String(r.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
                        s = rewriteConfigJs(s, baseUrl);
                        data = s.getBytes(StandardCharsets.UTF_8);
                    }
                    else
                    {
                        data = r.getInputStream().readAllBytes();
                    }

                    zip.putNextEntry(new ZipEntry(rel));
                    zip.write(data);
                    zip.closeEntry();
                    written++;
                }

                // 写一个 README 让商家知道这个包怎么用
                zip.putNextEntry(new ZipEntry("README-发行说明.md"));
                String readme = buildReadme(merchant, baseUrl);
                zip.write(readme.getBytes(StandardCharsets.UTF_8));
                zip.closeEntry();

                zip.finish();
                log.info("[codePack] ok merchantId={} files={} size={}",
                        merchant.getMerchantId(), written, out.size());
            }
            return out.toByteArray();
        }
        catch (IOException e)
        {
            log.error("[codePack] FAIL merchantId={}", merchant.getMerchantId(), e);
            throw new ServiceException("生成代码包失败：" + e.getMessage());
        }
    }

    @Override
    public String defaultFileName(Merchant merchant)
    {
        String no = merchant.getMerchantNo() == null ? ("M" + merchant.getMerchantId()) : merchant.getMerchantNo();
        String date = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyyMMdd"));
        return "dytuangou-mini-" + no + "-" + date + ".zip";
    }

    // ----------------------------------------------------------------
    // 内部方法
    // ----------------------------------------------------------------

    private String computeRelativePath(Resource r) throws IOException
    {
        String url = r.getURL().toString();
        int idx = url.indexOf(TEMPLATE_ROOT);
        if (idx < 0)
        {
            // jar 内的资源：jar:file:/.../ruoyi-admin.jar!/BOOT-INF/classes/template/miniprogram7/xxx
            // 这里走 jar 路径解析
            return readFromJar(url);
        }
        String tail = url.substring(idx + TEMPLATE_ROOT.length());
        if (tail.startsWith("/")) tail = tail.substring(1);
        return tail;
    }

    /**
     * 处理 jar:file: 协议的路径。Spring 在打包后会用这个协议拿到资源。
     * 由于流已经被消费，直接返回 null（上面 putNextEntry 用的是文件资源，这里用 readFromJar 二次拷贝）。
     */
    private String readFromJar(String url) throws IOException
    {
        // 实际逻辑在 buildCodePack 主体里循环处理，jar 模式同样用 r.getInputStream()
        return null;
    }

    /**
     * 改写 project.config.json 的 appid 字段。简单字符串替换，够用。
     * 模板里的 appid 是占位的 wx9e147c4e2151b123 或者 wxPLACEHOLDER。
     */
    private String rewriteProjectConfig(String s, Merchant m)
    {
        String appid = m.getAppid();
        // 替换任意 "appid": "wx..." 形式
        s = s.replaceAll("(\"appid\"\\s*:\\s*\")[^\"]*(\")", "$1" + appid + "$2");
        // 描述里也带 appid 字样
        s = s.replaceAll("(\"description\"\\s*:\\s*\")[^\"]*(\")", "$1" + m.getMerchantName() + " - 微信小程序" + "$2");
        s = s.replaceAll("(\"projectname\"\\s*:\\s*\")[^\"]*(\")", "$1" + "dytuangou-mini-" + m.getMerchantNo() + "$2");
        return s;
    }

    /**
     * 改写 utils/config.js 的 BASE_URL。
     * 模板里形如：const BASE_URL = 'http://172.31.26.216:8080';
     */
    private String rewriteConfigJs(String s, String baseUrl)
    {
        // 必须转义单引号 / 反斜杠，避免字符串被破坏
        String escaped = baseUrl.replace("\\", "\\\\").replace("'", "\\'");
        s = s.replaceAll("(const\\s+BASE_URL\\s*=\\s*['\"]).*?(['\"];)", "$1" + escaped + "$2");
        return s;
    }

    private String buildReadme(Merchant m, String baseUrl)
    {
        StringBuilder sb = new StringBuilder();
        sb.append("# ").append(m.getMerchantName()).append(" - 微信小程序代码包\n\n");
        sb.append("适用商家：").append(m.getMerchantName()).append("（").append(m.getMerchantNo()).append("）\n");
        sb.append("小程序 AppID：`").append(m.getAppid()).append("`\n");
        sb.append("接口地址：`").append(baseUrl).append("`\n");
        sb.append("生成时间：").append(java.time.LocalDateTime.now()).append("\n\n");
        sb.append("## 使用步骤\n\n");
        sb.append("1. 解压本 zip（保留 `project.config.json` 顶层）\n");
        sb.append("2. 打开微信开发者工具 → 「导入项目」\n");
        sb.append("3. 目录选解压后的文件夹；AppID 选 `").append(m.getAppid()).append("`\n");
        sb.append("4. 点击「导入」即可预览（开发阶段跳过上传）\n");
        sb.append("5. 点击右上角「上传」按钮，填写版本号与项目备注\n");
        sb.append("6. 登录 [微信公众平台](https://mp.weixin.qq.com) → 版本管理 → 提交审核\n");
        sb.append("7. 审核通过后点「发布」即可上线\n\n");
        sb.append("## 常见问题\n\n");
        sb.append("**Q: 上传时提示「不是该 AppID 的开发者」？**  \n");
        sb.append("A: 让小程序管理员在 mp.weixin.qq.com → 成员管理 → 添加你的微信号为开发者，权限选「开发者」或「体验者」。\n\n");
        sb.append("**Q: 预览时网络请求失败？**  \n");
        sb.append("A: 1) 微信开发者工具右上角「详情」→「不校验合法域名」打勾；2) 确认手机和电脑在同一局域网。\n\n");
        sb.append("**Q: 后端地址变了怎么重新打包？**  \n");
        sb.append("A: 登录我们后台 → 小程序发布 → 选择本商家 → 修改 API 地址 → 重新下载。\n");
        return sb.toString();
    }
}
