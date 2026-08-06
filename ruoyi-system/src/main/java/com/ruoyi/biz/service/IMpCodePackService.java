package com.ruoyi.biz.service;

import com.ruoyi.biz.domain.Merchant;

/**
 * 小程序代码包生成服务
 *
 * <p>为商家生成可直接导入微信开发者工具的 zip 包，仅限「传统发布流程」使用：
 * 不接入微信第三方平台时，商家必须自己在微信公众平台扫码、上传代码、提交审核。</p>
 *
 * <p>生成逻辑：</p>
 * <ol>
 *   <li>读取 ruoyi-admin classpath 下的 template/miniprogram7/ 目录</li>
 *   <li>改写 project.config.json 的 appid 为商家 appid</li>
 *   <li>改写 utils/config.js 的 BASE_URL 为调用方传入的 API 地址</li>
 *   <li>压缩成 zip 返回字节流</li>
 * </ol>
 *
 * @author dytuangou
 */
public interface IMpCodePackService
{
    /**
     * 生成小程序代码包
     *
     * @param merchant 商家（含 appid、merchant_no、merchant_name）
     * @param baseUrl  API 地址（生产 https://api.wetangou.com / 测试 http://192.168.1.10:8080）
     * @return zip 字节流
     */
    byte[] buildCodePack(Merchant merchant, String baseUrl);

    /**
     * 生成默认代码包文件名
     * @param merchant 商家
     * @return 类似 dytuangou-mini-MC000001-20260806.zip
     */
    String defaultFileName(Merchant merchant);
}
