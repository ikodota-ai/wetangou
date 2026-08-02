package com.ruoyi.common.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * 对象存储配置：application.yml 的 ruoyi.storage.* 段
 *
 * <p>type 可选：
 * <ul>
 *   <li>local    本地磁盘（默认，零配置）</li>
 *   <li>minio    自建 MinIO（用 S3StorageAdapter）</li>
 *   <li>oss      阿里云 OSS（用 S3StorageAdapter，OSS 提供 S3 兼容 endpoint）</li>
 *   <li>qiniu    七牛云（用 S3StorageAdapter，七牛 S3 兼容）</li>
 *   <li>fastdfs  FastDFS（用 FastDfsStorageAdapter，需额外引入 fastdfs-client）</li>
 * </ul>
 *
 * <p>对标 RuoYi 官方 ruoyi-file 模块（参见 https://doc.ruoyi.vip/ruoyi-cloud/cloud/file.html）。</p>
 *
 * @author dytuangou
 */
@Component
@ConfigurationProperties(prefix = "ruoyi.storage")
public class StorageProperties
{
    private String type = "local";
    private S3 s3 = new S3();
    private FastDfs fastdfs = new FastDfs();

    public String getType() { return type; }
    public void setType(String type) { this.type = type; }
    public S3 getS3() { return s3; }
    public void setS3(S3 s3) { this.s3 = s3; }
    public FastDfs getFastdfs() { return fastdfs; }
    public void setFastdfs(FastDfs fastdfs) { this.fastdfs = fastdfs; }

    /**
     * 通用 S3 协议配置：MinIO / 阿里云 OSS / 七牛 S3 / 腾讯云 COS / AWS S3
     */
    public static class S3
    {
        private String endpoint;        // S3 endpoint，如 http://127.0.0.1:9000 或 https://oss-cn-shanghai.aliyuncs.com
        private String region = "us-east-1";
        private String bucket;
        private String accessKey;
        private String secretKey;
        private String publicDomain;   // 可选：CDN 域名，配置后 URL 用它替代 endpoint

        public String getEndpoint() { return endpoint; }
        public void setEndpoint(String endpoint) { this.endpoint = endpoint; }
        public String getRegion() { return region; }
        public void setRegion(String region) { this.region = region; }
        public String getBucket() { return bucket; }
        public void setBucket(String bucket) { this.bucket = bucket; }
        public String getAccessKey() { return accessKey; }
        public void setAccessKey(String accessKey) { this.accessKey = accessKey; }
        public String getSecretKey() { return secretKey; }
        public void setSecretKey(String secretKey) { this.secretKey = secretKey; }
        public String getPublicDomain() { return publicDomain; }
        public void setPublicDomain(String publicDomain) { this.publicDomain = publicDomain; }
    }

    /**
     * FastDFS 专用配置
     */
    public static class FastDfs
    {
        private String trackerServer;   // 如 192.168.1.10:22122
        private String downloadServer;  // 客户端访问 Storage 的 HTTP 地址，如 http://192.168.1.10/

        public String getTrackerServer() { return trackerServer; }
        public void setTrackerServer(String trackerServer) { this.trackerServer = trackerServer; }
        public String getDownloadServer() { return downloadServer; }
        public void setDownloadServer(String downloadServer) { this.downloadServer = downloadServer; }
    }
}
