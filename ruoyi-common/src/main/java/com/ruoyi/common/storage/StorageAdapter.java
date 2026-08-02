package com.ruoyi.common.storage;

import java.io.InputStream;

/**
 * 对象存储适配器：抽象出「上传 / 下载 / 删除 / 签名 URL」四个动作，
 * 让业务代码（FileUploadUtils / ImageUpload.vue 等）与具体云厂商解耦。
 *
 * <p>支持实现：
 * <ul>
 *   <li>{@link LocalStorageAdapter}  本地磁盘（默认）</li>
 *   <li>{@link AliyunOssAdapter}     阿里云 OSS</li>
 *   <li>{@link QiniuStorageAdapter}  七牛云对象存储</li>
 * </ul>
 *
 * <p>由 {@link StorageFactory} 根据 application.yml 配置自动选择实现。</p>
 *
 * @author dytuangou
 */
public interface StorageAdapter
{
    /**
     * 上传文件
     *
     * @param key        远端 key（含子路径，如 upload/2026/08/abc.jpg）
     * @param input      文件流
     * @param contentType MIME 类型，可为 null
     * @param size       字节数，可为 null（部分实现必填）
     * @return 公开访问的 URL（前端可直接 <img src=...>）
     */
    String upload(String key, InputStream input, String contentType, Long size);

    /**
     * 删除文件（不存在时不抛异常）
     */
    void delete(String key);

    /**
     * 生成临时访问 URL（私有 bucket 场景）
     *
     * @param key  远端 key
     * @param expireSeconds 有效期（秒）
     * @return 带签名的 URL
     */
    default String generatePresignedUrl(String key, int expireSeconds)
    {
        // 默认实现：直接返回公开 URL（适用于公开读 bucket / 本地存储）
        return getPublicUrl(key);
    }

    /**
     * 获取公开访问 URL（不签名）
     */
    String getPublicUrl(String key);

    /**
     * 适配器类型
     */
    default String getType() {
        return "unknown";
    }
}
