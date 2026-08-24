package com.ruoyi.web.controller.biz;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.attribute.PosixFilePermission;
import java.security.KeyFactory;
import java.security.spec.PKCS8EncodedKeySpec;
import java.util.Base64;
import java.util.HashSet;
import java.util.Set;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.config.RuoYiConfig;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.framework.config.ServerConfig;

/**
 * 商户支付证书 / 回调地址辅助接口
 *
 * <p>为什么单独一个 controller 放在 ruoyi-admin：
 * {@link ServerConfig} 在 ruoyi-framework 模块，ruoyi-system 里的
 * MerchantController 跨模块引不到，所以带域名推断的端点只能落在 admin 层。</p>
 *
 * @author dytuangou
 */
@RestController
@RequestMapping("/biz/merchant/cert")
public class BizMerchantCertController extends BaseController
{
    private static final Logger log = LoggerFactory.getLogger(BizMerchantCertController.class);

    /** 私钥落盘目录名 */
    private static final String CERT_DIR = "cert";

    /** 微信支付私钥固定 1~2KB，超过 32KB 一定不是 pem */
    private static final long MAX_PEM_SIZE = 32 * 1024L;

    @Autowired
    private ServerConfig serverConfig;

    /**
     * 上传微信支付私钥 apiclient_key.pem
     *
     * <p>只落盘并返回绝对路径，不直接写库 —— 商户还要在弹窗里点确定才保存，
     * 避免上传即生效导致误覆盖线上可用配置。</p>
     *
     * <p>校验顺序刻意是「先解析、后落盘」：私钥格式不对时立即拒绝，
     * 不留垃圾文件。PKCS#1（BEGIN RSA PRIVATE KEY）会被拒，
     * 因为 WxPayService 用 PKCS8EncodedKeySpec 解不了，
     * 与其上传成功、支付时才失败，不如在这里就说清楚怎么转换。</p>
     *
     * @param file       pem 文件
     * @param merchantId 商户ID，用于文件名隔离，避免多商户互相覆盖
     * @return payKeyPath 绝对路径
     */
    @PreAuthorize("@ss.hasPermi('biz:merchant:wxconfig')")
    @Log(title = "商户支付私钥", businessType = BusinessType.UPDATE)
    @PostMapping("/uploadKey")
    public AjaxResult uploadKey(@RequestParam("file") MultipartFile file,
                                @RequestParam("merchantId") Long merchantId)
    {
        if (file == null || file.isEmpty())
        {
            return AjaxResult.error("请选择 apiclient_key.pem 文件");
        }
        if (merchantId == null)
        {
            return AjaxResult.error("缺少商户ID，无法隔离存放私钥");
        }
        String original = StringUtils.defaultIfEmpty(file.getOriginalFilename(), "");
        if (!original.toLowerCase().endsWith(".pem"))
        {
            return AjaxResult.error("只允许上传 .pem 文件，当前为：" + original);
        }
        if (file.getSize() > MAX_PEM_SIZE)
        {
            return AjaxResult.error("文件超过 32KB，不像是微信支付私钥，请确认上传的是 apiclient_key.pem");
        }

        String content;
        try
        {
            content = new String(file.getBytes(), StandardCharsets.UTF_8);
        }
        catch (IOException e)
        {
            log.error("[merchantCert] 读取上传私钥失败 merchantId={}", merchantId, e);
            return AjaxResult.error("读取上传文件失败");
        }

        if (content.contains("BEGIN RSA PRIVATE KEY"))
        {
            return AjaxResult.error("该文件是 PKCS#1 格式，系统需要 PKCS#8。请先转换："
                    + "openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt "
                    + "-in apiclient_key.pem -out apiclient_key_pkcs8.pem");
        }
        if (!content.contains("BEGIN PRIVATE KEY"))
        {
            return AjaxResult.error("文件内容不含 -----BEGIN PRIVATE KEY-----，请确认上传的是微信支付 API 私钥");
        }
        // 真正解析一次：与 WxPayService.loadPrivateKey 同逻辑，确保支付时不会再失败
        try
        {
            String body = content.replace("-----BEGIN PRIVATE KEY-----", "")
                    .replace("-----END PRIVATE KEY-----", "")
                    .replaceAll("\\s", "");
            byte[] keyBytes = Base64.getDecoder().decode(body);
            KeyFactory.getInstance("RSA").generatePrivate(new PKCS8EncodedKeySpec(keyBytes));
        }
        catch (Exception e)
        {
            log.warn("[merchantCert] 私钥解析失败 merchantId={} err={}", merchantId, e.getMessage());
            return AjaxResult.error("私钥解析失败，文件可能已损坏或不是有效的 RSA 私钥");
        }

        try
        {
            Path dir = resolveCertDir();
            Files.createDirectories(dir);
            // 目录 700：同机其他账号不可读，私钥等同收款权限
            trySetPosix(dir, PosixFilePermission.OWNER_READ, PosixFilePermission.OWNER_WRITE,
                    PosixFilePermission.OWNER_EXECUTE);

            // 文件名带 merchantId，多商户不互相覆盖；固定名便于重复上传时覆盖旧的
            Path target = dir.resolve("merchant_" + merchantId + "_apiclient_key.pem");
            Files.write(target, content.getBytes(StandardCharsets.UTF_8));
            // 文件 600
            trySetPosix(target, PosixFilePermission.OWNER_READ, PosixFilePermission.OWNER_WRITE);

            String abs = target.toAbsolutePath().toString();
            log.info("[merchantCert] 私钥已保存 merchantId={} path={}", merchantId, abs);

            AjaxResult r = AjaxResult.success("上传成功");
            r.put("payKeyPath", abs);
            r.put("fileName", target.getFileName().toString());
            return r;
        }
        catch (IOException e)
        {
            log.error("[merchantCert] 私钥落盘失败 merchantId={}", merchantId, e);
            return AjaxResult.error("保存私钥失败：" + e.getMessage());
        }
    }

    /**
     * 生成支付回调地址（含 merchantId）
     *
     * <p>推荐带 merchantId：ApiPayNotifyController 可直接用该商户的 APIv3 密钥解密，
     * 不必先解出 out_trade_no 再反查订单（订单不存在时那条路会失败）。</p>
     *
     * <p>域名取自当前请求，所以后台是 https 访问时生成的就是 https。
     * 微信支付要求回调必须 https，故这里显式提示。</p>
     */
    @PreAuthorize("@ss.hasPermi('biz:merchant:wxconfig')")
    @GetMapping("/notifyUrl")
    public AjaxResult notifyUrl(@RequestParam("merchantId") Long merchantId)
    {
        if (merchantId == null)
        {
            return AjaxResult.error("缺少商户ID");
        }
        String base = serverConfig.getUrl();
        String url = stripTrailingSlash(base) + "/api/pay/notify/" + merchantId;

        AjaxResult r = AjaxResult.success();
        r.put("notifyUrl", url);
        r.put("https", url.startsWith("https://"));
        return r;
    }

    /**
     * 私钥存放目录：ruoyi.profile 的<b>同级</b> cert/，而不是 profile 里面。
     *
     * <p>ResourcesConfig 把 /profile/** 整个映射到 ruoyi.profile 目录，
     * 且 SecurityConfig 对 /profile/** 是 permitAll —— 私钥一旦落在 profile 之内，
     * 任何人都能用 /profile/cert/merchant_1_apiclient_key.pem 直接下载。
     * 放同级目录后不在任何静态映射范围内，只能由服务端进程读取。</p>
     */
    private static Path resolveCertDir()
    {
        Path profile = Paths.get(RuoYiConfig.getProfile()).toAbsolutePath().normalize();
        Path parent = profile.getParent();
        return (parent != null ? parent : profile).resolve(CERT_DIR);
    }

    private static String stripTrailingSlash(String s)
    {
        if (s == null)
        {
            return "";
        }
        return s.endsWith("/") ? s.substring(0, s.length() - 1) : s;
    }

    /**
     * 尽力收紧权限。Windows 等非 POSIX 文件系统会抛 UnsupportedOperationException，
     * 此时忽略即可，不该因为设不了权限就让上传整体失败。
     */
    private static void trySetPosix(Path path, PosixFilePermission... perms)
    {
        try
        {
            Set<PosixFilePermission> set = new HashSet<>();
            for (PosixFilePermission p : perms)
            {
                set.add(p);
            }
            Files.setPosixFilePermissions(path, set);
        }
        catch (Exception ignore)
        {
            log.debug("[merchantCert] 跳过权限设置（非 POSIX 文件系统）path={}", path);
        }
    }
}
