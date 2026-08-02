package com.ruoyi.common.storage;

import java.io.InputStream;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import io.minio.GetPresignedObjectUrlArgs;
import io.minio.MinioClient;
import io.minio.PutObjectArgs;
import io.minio.RemoveObjectArgs;
import io.minio.http.Method;
import com.ruoyi.common.config.StorageProperties;

/**
 * S3 协议统一适配器（基于 MinIO SDK）
 *
 * <p>通过修改 application.yml 的 ruoyi.storage.s3.endpoint，可对接：
 * <ul>
 *   <li>MinIO（自建对象存储）</li>
 *   <li>阿里云 OSS（用 oss-cn-shanghai.aliyuncs.com 即可）</li>
 *   <li>七牛云 S3 兼容接口（s3-cn-east-1.qiniucs.com）</li>
 *   <li>腾讯云 COS</li>
 *   <li>AWS S3</li>
 * </ul>
 *
 * <p>URL 返回 public-domain + key（公开读 bucket）或 presigned URL（私有读）。</p>
 *
 * @author dytuangou
 */
public class S3StorageAdapter implements StorageAdapter
{
    private static final Logger log = LoggerFactory.getLogger(S3StorageAdapter.class);

    private final StorageProperties.S3 props;
    private final MinioClient client;

    public S3StorageAdapter(StorageProperties.S3 props)
    {
        this.props = props;
        this.client = MinioClient.builder()
                .endpoint(props.getEndpoint())
                .credentials(props.getAccessKey(), props.getSecretKey())
                .region(props.getRegion() == null ? "us-east-1" : props.getRegion())
                .build();
        log.info("[S3Storage] init endpoint={} bucket={}", props.getEndpoint(), props.getBucket());
    }

    @Override
    public String upload(String key, InputStream input, String contentType, Long size)
    {
        try
        {
            PutObjectArgs args = PutObjectArgs.builder()
                    .bucket(props.getBucket())
                    .object(key)
                    .stream(input, size == null ? -1 : size, -1)
                    .contentType(contentType == null ? "application/octet-stream" : contentType)
                    .build();
            client.putObject(args);
            log.info("[S3Storage] upload {} ({} bytes)", key, size);
            return getPublicUrl(key);
        }
        catch (Exception e)
        {
            throw new RuntimeException("S3 上传失败: " + key, e);
        }
    }

    @Override
    public void delete(String key)
    {
        try
        {
            client.removeObject(RemoveObjectArgs.builder()
                    .bucket(props.getBucket())
                    .object(key)
                    .build());
        }
        catch (Exception e)
        {
            log.warn("[S3Storage] delete 失败 {}", key, e);
        }
    }

    @Override
    public String getPublicUrl(String key)
    {
        // 公开读 bucket：直接拼 endpoint/bucket/key
        if (props.getPublicDomain() != null && !props.getPublicDomain().isEmpty())
        {
            String d = props.getPublicDomain();
            return (d.endsWith("/") ? d.substring(0, d.length()-1) : d) + "/" + key;
        }
        // 否则用 endpoint/bucket/key
        String endpoint = stripSlash(props.getEndpoint());
        return endpoint + "/" + props.getBucket() + "/" + key;
    }

    @Override
    public String generatePresignedUrl(String key, int expireSeconds)
    {
        try
        {
            return client.getPresignedObjectUrl(GetPresignedObjectUrlArgs.builder()
                    .bucket(props.getBucket())
                    .object(key)
                    .method(Method.GET)
                    .expiry(expireSeconds, TimeUnit.SECONDS)
                    .build());
        }
        catch (Exception e)
        {
            throw new RuntimeException("生成签名 URL 失败: " + key, e);
        }
    }

    @Override
    public String getType()
    {
        return "s3";  // 兼容 MinIO / OSS / 七牛 / COS / S3
    }

    private static String stripSlash(String s)
    {
        if (s == null) return null;
        return s.endsWith("/") ? s.substring(0, s.length() - 1) : s;
    }
}
