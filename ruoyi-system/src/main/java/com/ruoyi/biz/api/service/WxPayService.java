package com.ruoyi.biz.api.service;

import java.io.IOException;
import java.io.OutputStream;
import java.math.BigDecimal;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.SecureRandom;
import java.security.Signature;
import java.security.spec.PKCS8EncodedKeySpec;
import java.util.Base64;

import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.alibaba.fastjson2.JSONObject;
import com.ruoyi.biz.api.config.WxPayConfig;
import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.biz.service.IMerchantService;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;

/**
 * 微信支付V3 JSAPI 服务：统一下单、签名、回调解密。
 *
 * <p>未配置真实商户凭证时走 mock（直接返回可用于本地联调的假支付参数）。
 * 使用 JDK 自带加解密（RSA-SHA256 签名、AES-GCM 解密），不引入额外SDK。</p>
 *
 * @author dytuangou
 */
@Service
public class WxPayService
{
    private static final Logger log = LoggerFactory.getLogger(WxPayService.class);

    private static final String JSAPI_URL = "https://api.mch.weixin.qq.com/v3/pay/transactions/jsapi";

    @Autowired
    private WxPayConfig wxPayConfig;

    @Autowired
    private IMerchantService merchantService;

    /**
     * 根据订单/买单所属 merchantId 取对应的支付凭证（appId/mchId/证书/密钥/回调地址）。
     * 商户未配置时回退到全局 sys_config。
     */
    private MerchantPayCredential resolveCredential(Long merchantId)
    {
        Merchant merchant = merchantId == null ? null : merchantService.selectMerchantByMerchantId(merchantId);
        MerchantPayCredential c = new MerchantPayCredential();
        if (merchant != null) {
            c.appId = StringUtils.defaultIfEmpty(merchant.getPayAppid(), wxPayConfig.getAppId());
            c.mchId = StringUtils.defaultIfEmpty(merchant.getPayMchId(), wxPayConfig.getMchId());
            c.certSerialNo = StringUtils.defaultIfEmpty(merchant.getPayCertSerial(), wxPayConfig.getCertSerialNo());
            // 私钥文件路径允许商户独立配置；为空时回退到全局
            String kp = StringUtils.isNotEmpty(merchant.getPayKeyPath()) ? merchant.getPayKeyPath() : wxPayConfig.getPrivateKeyPath();
            c.privateKeyPath = kp;
            c.apiV3Key = StringUtils.defaultIfEmpty(merchant.getPayApiV3Key(), wxPayConfig.getApiV3Key());
            // 回调地址按商户隔离，避免多商户回调冲突
            c.notifyUrl = StringUtils.isNotEmpty(merchant.getPayNotifyUrl()) ? merchant.getPayNotifyUrl() : wxPayConfig.getNotifyUrl();
        } else {
            c.appId = wxPayConfig.getAppId();
            c.mchId = wxPayConfig.getMchId();
            c.certSerialNo = wxPayConfig.getCertSerialNo();
            c.privateKeyPath = wxPayConfig.getPrivateKeyPath();
            c.apiV3Key = wxPayConfig.getApiV3Key();
            c.notifyUrl = wxPayConfig.getNotifyUrl();
        }
        return c;
    }

    /**
     * 是否走mock支付（未配齐凭证且开启mock）
     */
    public boolean isMock()
    {
        return !wxPayConfig.isConfigured() && wxPayConfig.isMockEnabled();
    }

    /**
     * JSAPI 统一下单，返回小程序 wx.requestPayment 所需参数。
     *
     * @param outTradeNo 商户订单号（订单/买单编号）
     * @param description 商品描述
     * @param totalFen 金额（分）
     * @param openid 支付用户openid
     * @return 含 timeStamp/nonceStr/package/signType/paySign 的参数，mock时 mock=true
     */
    /**
     * 多商户版 JSAPI 统一下单
     *
     * @param merchantId 业务所属商户ID，决定走哪套支付凭证
     */
    public JSONObject createJsapiOrderByMerchant(Long merchantId, String outTradeNo, String description, int totalFen, String openid)
    {
        MerchantPayCredential c = resolveCredential(merchantId);
        // 商户级 mock 判断：未配置齐全时仍走 mock，避免本地缺凭证时整体失败
        boolean mock = StringUtils.isEmpty(c.mchId) || StringUtils.isEmpty(c.apiV3Key) || wxPayConfig.isMockEnabled();
        if (mock)
        {
            log.info("[WxPayService] mock支付(merchantId={}), outTradeNo={}, totalFen={}", merchantId, outTradeNo, totalFen);
            JSONObject mockJson = new JSONObject();
            mockJson.put("mock", true);
            mockJson.put("outTradeNo", outTradeNo);
            mockJson.put("merchantId", merchantId);
            return mockJson;
        }
        if (StringUtils.isEmpty(openid))
        {
            throw new ServiceException("支付用户openid为空，无法发起支付");
        }

        JSONObject body = new JSONObject();
        body.put("appid", c.appId);
        body.put("mchid", c.mchId);
        body.put("description", description);
        body.put("out_trade_no", outTradeNo);
        body.put("notify_url", c.notifyUrl);
        JSONObject amount = new JSONObject();
        amount.put("total", totalFen);
        amount.put("currency", "CNY");
        body.put("amount", amount);
        JSONObject payer = new JSONObject();
        payer.put("openid", openid);
        body.put("payer", payer);

        String bodyStr = body.toJSONString();
        String prepayId;
        try
        {
            String authorization = buildAuthorizationWithCredential("POST", "/v3/pay/transactions/jsapi", bodyStr, c);
            // 与单例版 createJsapiOrder 共享 postJson / buildPaySignParams；
            // 这里只把 mchId/appId 换成商户级，HTTP/签名逻辑复用。
            String resp = postJson(JSAPI_URL, bodyStr, authorization);
            JSONObject respJson = JSONObject.parseObject(resp);
            prepayId = respJson == null ? null : respJson.getString("prepay_id");
        }
        catch (Exception e)
        {
            log.error("[WxPayService] JSAPI 下单失败", e);
            throw new ServiceException("支付下单失败：" + e.getMessage());
        }
        return buildJsapiSign(prepayId, c);
    }

    /**
     * 单商户版 JSAPI 下单（保持向后兼容）
     */
    public JSONObject createJsapiOrder(String outTradeNo, String description, int totalFen, String openid)
    {
        if (isMock())
        {
            log.info("[WxPayService] mock支付，outTradeNo={}, totalFen={}", outTradeNo, totalFen);
            JSONObject mock = new JSONObject();
            mock.put("mock", true);
            mock.put("outTradeNo", outTradeNo);
            return mock;
        }
        if (StringUtils.isEmpty(openid))
        {
            throw new ServiceException("支付用户openid为空，无法发起支付");
        }

        JSONObject body = new JSONObject();
        body.put("appid", wxPayConfig.getAppId());
        body.put("mchid", wxPayConfig.getMchId());
        body.put("description", description);
        body.put("out_trade_no", outTradeNo);
        body.put("notify_url", wxPayConfig.getNotifyUrl());
        JSONObject amount = new JSONObject();
        amount.put("total", totalFen);
        amount.put("currency", "CNY");
        body.put("amount", amount);
        JSONObject payer = new JSONObject();
        payer.put("openid", openid);
        body.put("payer", payer);

        String bodyStr = body.toJSONString();
        String prepayId;
        try
        {
            String authorization = buildAuthorization("POST", "/v3/pay/transactions/jsapi", bodyStr);
            String resp = postJson(JSAPI_URL, bodyStr, authorization);
            JSONObject json = JSONObject.parseObject(resp);
            prepayId = json == null ? null : json.getString("prepay_id");
            if (StringUtils.isEmpty(prepayId))
            {
                throw new ServiceException("微信统一下单失败：" + resp);
            }
        }
        catch (ServiceException e)
        {
            throw e;
        }
        catch (Exception e)
        {
            log.error("微信统一下单异常", e);
            throw new ServiceException("微信统一下单异常：" + e.getMessage());
        }

        return buildPaySignParams(prepayId);
    }

    /**
     * 组装并签名 wx.requestPayment 参数
     */
    private JSONObject buildJsapiSign(String prepayId, MerchantPayCredential c)
    {
        return buildPaySignParamsWithCredential(prepayId, c);
    }

    private JSONObject buildPaySignParams(String prepayId)
    {
        return buildPaySignParamsWithCredential(prepayId, resolveCredential(null));
    }

    private JSONObject buildPaySignParamsWithCredential(String prepayId, MerchantPayCredential c)
    {
        try
        {
            String timeStamp = String.valueOf(System.currentTimeMillis() / 1000);
            String nonceStr = randomStr();
            String pkg = "prepay_id=" + prepayId;
            // paySign 签名前缀以「调用 JSAPI 的 appId」为准
            String signStr = c.appId + "\n" + timeStamp + "\n" + nonceStr + "\n" + pkg + "\n";
            String paySign = signWithCredential(signStr, c);

            JSONObject result = new JSONObject();
            result.put("mock", false);
            result.put("appId", c.appId);
            result.put("timeStamp", timeStamp);
            result.put("nonceStr", nonceStr);
            result.put("package", pkg);
            result.put("signType", "RSA");
            result.put("paySign", paySign);
            return result;
        }
        catch (Exception e)
        {
            throw new ServiceException("支付签名失败：" + e.getMessage());
        }
    }

    /**
     * 构造 Authorization 头（V3 签名）— 单例入口，转调 WithCredential
     */
    private String buildAuthorization(String method, String urlPath, String body) throws Exception
    {
        return buildAuthorizationWithCredential(method, urlPath, body, resolveCredential(null));
    }

    private String buildAuthorizationWithCredential(String method, String urlPath, String body, MerchantPayCredential c) throws Exception
    {
        String nonceStr = randomStr();
        long timestamp = System.currentTimeMillis() / 1000;
        String message = method + "\n" + urlPath + "\n" + timestamp + "\n" + nonceStr + "\n" + body + "\n";
        String signature = signWithCredential(message, c);
        return String.format(
                "WECHATPAY2-SHA256-RSA2048 mchid=\"%s\",nonce_str=\"%s\",timestamp=\"%d\",serial_no=\"%s\",signature=\"%s\"",
                c.mchId, nonceStr, timestamp, c.certSerialNo, signature);
    }

    /**
     * RSA-SHA256 使用商户私钥签名，返回Base64 — 单例入口，转调 WithCredential
     */
    private String sign(String message) throws Exception
    {
        return signWithCredential(message, resolveCredential(null));
    }

    private String signWithCredential(String message, MerchantPayCredential c) throws Exception
    {
        Signature signer = Signature.getInstance("SHA256withRSA");
        signer.initSign(loadPrivateKeyWithCredential(c));
        signer.update(message.getBytes(StandardCharsets.UTF_8));
        return Base64.getEncoder().encodeToString(signer.sign());
    }

    private PrivateKey loadPrivateKey() throws Exception
    {
        return loadPrivateKeyWithCredential(resolveCredential(null));
    }

    private PrivateKey loadPrivateKeyWithCredential(MerchantPayCredential c) throws Exception
    {
        if (StringUtils.isEmpty(c.privateKeyPath))
        {
            throw new ServiceException("商户私钥路径未配置");
        }
        String content = new String(Files.readAllBytes(Paths.get(c.privateKeyPath)), StandardCharsets.UTF_8);
        content = content.replace("-----BEGIN PRIVATE KEY-----", "")
                .replace("-----END PRIVATE KEY-----", "")
                .replaceAll("\\s", "");
        byte[] keyBytes = Base64.getDecoder().decode(content);
        KeyFactory kf = KeyFactory.getInstance("RSA");
        return kf.generatePrivate(new PKCS8EncodedKeySpec(keyBytes));
    }

    private String randomStr()
    {
        byte[] bytes = new byte[16];
        new SecureRandom().nextBytes(bytes);
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes)
        {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }

    private String postJson(String urlStr, String body, String authorization) throws IOException
    {
        HttpURLConnection conn = (HttpURLConnection) new URL(urlStr).openConnection();
        try
        {
            conn.setRequestMethod("POST");
            conn.setDoOutput(true);
            conn.setConnectTimeout(10000);
            conn.setReadTimeout(15000);
            conn.setRequestProperty("Content-Type", "application/json");
            conn.setRequestProperty("Accept", "application/json");
            conn.setRequestProperty("User-Agent", "dytuangou-wxpay");
            conn.setRequestProperty("Authorization", authorization);
            try (OutputStream os = conn.getOutputStream())
            {
                os.write(body.getBytes(StandardCharsets.UTF_8));
            }
            int code = conn.getResponseCode();
            java.io.InputStream is = (code >= 200 && code < 300) ? conn.getInputStream() : conn.getErrorStream();
            String resp = is == null ? "" : new String(is.readAllBytes(), StandardCharsets.UTF_8);
            if (code < 200 || code >= 300)
            {
                throw new ServiceException("微信支付接口返回错误(" + code + ")：" + resp);
            }
            return resp;
        }
        finally
        {
            conn.disconnect();
        }
    }

    /**
     * 解密回调通知中的 resource（AES-256-GCM）
     *
     * @param associatedData resource.associated_data
     * @param nonce resource.nonce
     * @param ciphertext resource.ciphertext（Base64）
     * @return 解密后的明文JSON
     */
    /**
     * 多商户版回调解密：根据商户ID 取对应 APIv3 密钥
     */
    public String decryptNotifyByMerchant(Long merchantId, String associatedData, String nonce, String ciphertext)
    {
        MerchantPayCredential c = resolveCredential(merchantId);
        if (StringUtils.isEmpty(c.apiV3Key))
        {
            throw new ServiceException("未配置 APIv3 密钥，无法解密回调");
        }
        try
        {
            byte[] key = c.apiV3Key.getBytes(StandardCharsets.UTF_8);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            SecretKeySpec keySpec = new SecretKeySpec(key, "AES");
            GCMParameterSpec spec = new GCMParameterSpec(128, nonce.getBytes(StandardCharsets.UTF_8));
            cipher.init(Cipher.DECRYPT_MODE, keySpec, spec);
            if (StringUtils.isNotEmpty(associatedData))
            {
                cipher.updateAAD(associatedData.getBytes(StandardCharsets.UTF_8));
            }
            byte[] plain = cipher.doFinal(Base64.getDecoder().decode(ciphertext));
            return new String(plain, StandardCharsets.UTF_8);
        }
        catch (Exception e)
        {
            throw new ServiceException("回调解密失败：" + e.getMessage());
        }
    }

    /**
     * 单商户版回调解密（保持向后兼容）
     */
    public String decryptNotify(String associatedData, String nonce, String ciphertext)
    {
        try
        {
            byte[] key = wxPayConfig.getApiV3Key().getBytes(StandardCharsets.UTF_8);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            SecretKeySpec keySpec = new SecretKeySpec(key, "AES");
            GCMParameterSpec spec = new GCMParameterSpec(128, nonce.getBytes(StandardCharsets.UTF_8));
            cipher.init(Cipher.DECRYPT_MODE, keySpec, spec);
            if (StringUtils.isNotEmpty(associatedData))
            {
                cipher.updateAAD(associatedData.getBytes(StandardCharsets.UTF_8));
            }
            byte[] plain = cipher.doFinal(Base64.getDecoder().decode(ciphertext));
            return new String(plain, StandardCharsets.UTF_8);
        }
        catch (Exception e)
        {
            throw new ServiceException("回调解密失败：" + e.getMessage());
        }
    }

    /**
     * 元转分
     */
    public static int yuanToFen(BigDecimal yuan)
    {
        return yuan.multiply(new BigDecimal(100)).setScale(0, BigDecimal.ROUND_HALF_UP).intValue();
    }


    /**
     * 商户支付凭证：从 biz_merchant.pay_* 字段或 sys_config 拉取的运行时参数。
     * 内部类避免污染外部 API。
     */
    private static class MerchantPayCredential
    {
        String appId;
        String mchId;
        String certSerialNo;
        String privateKeyPath;
        String apiV3Key;
        String notifyUrl;
    }
}
