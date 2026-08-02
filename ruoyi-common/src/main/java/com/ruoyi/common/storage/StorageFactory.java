package com.ruoyi.common.storage;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import com.ruoyi.common.config.StorageProperties;
import jakarta.annotation.PostConstruct;

/**
 * 存储适配器工厂：按 application.yml 的 ruoyi.storage.type 选择实现
 *
 * <p>整个应用共用一个 StorageAdapter 单例，存于 {@link #adapter}。</p>
 *
 * <p>支持的 type：
 * <ul>
 *   <li>local   — {@link LocalStorageAdapter}</li>
 *   <li>minio   — {@link S3StorageAdapter} 配 MinIO endpoint</li>
 *   <li>oss     — {@link S3StorageAdapter} 配阿里云 OSS endpoint</li>
 *   <li>qiniu   — {@link S3StorageAdapter} 配七牛 S3 endpoint</li>
 *   <li>fastdfs — {@link FastDfsStorageAdapter}（需额外引入 fastdfs-client-java）</li>
 * </ul>
 *
 * @author dytuangou
 */
@Component
public class StorageFactory
{
    private static final Logger log = LoggerFactory.getLogger(StorageFactory.class);

    @Autowired
    private StorageProperties props;

    private static volatile StorageAdapter adapter;

    public static StorageAdapter get()
    {
        StorageAdapter a = adapter;
        if (a == null)
        {
            throw new IllegalStateException("StorageFactory 未初始化，请确认 Spring 容器已启动");
        }
        return a;
    }

    @PostConstruct
    public void init()
    {
        String type = props.getType() == null ? "local" : props.getType().toLowerCase();
        switch (type)
        {
            case "minio":
            case "oss":
            case "qiniu":
            case "s3":
            case "cos":
                adapter = new S3StorageAdapter(props.getS3());
                log.info("[StorageFactory] 使用 S3 协议：endpoint={} bucket={}",
                        props.getS3().getEndpoint(), props.getS3().getBucket());
                break;
            case "fastdfs":
                adapter = new FastDfsStorageAdapter(props.getFastdfs());
                log.info("[StorageFactory] 使用 FastDFS：tracker={}", props.getFastdfs().getTrackerServer());
                break;
            case "local":
            default:
                adapter = new LocalStorageAdapter();
                log.info("[StorageFactory] 使用本地磁盘存储");
                break;
        }
    }
}
