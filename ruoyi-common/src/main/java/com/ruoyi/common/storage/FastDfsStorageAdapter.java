package com.ruoyi.common.storage;

import java.io.InputStream;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import com.ruoyi.common.config.StorageProperties;

/**
 * FastDFS 适配器（占位实现）
 *
 * <p>FastDFS 不是 S3 协议，需要单独的 fastdfs-client-java SDK。
 * 启用步骤：
 * <ol>
 *   <li>pom.xml 引入 org.csource:fastdfs-client-java:1.29</li>
 *   <li>application.yml ruoyi.storage.fastdfs.* 配置 tracker-server 地址</li>
 * </ol>
 *
 * <p>为避免主包强制引入 FastDFS SDK 拖累启动，运行时按需加载（见 try-catch）。</p>
 *
 * @author dytuangou
 */
public class FastDfsStorageAdapter implements StorageAdapter
{
    private static final Logger log = LoggerFactory.getLogger(FastDfsStorageAdapter.class);

    private final StorageProperties.FastDfs props;

    public FastDfsStorageAdapter(StorageProperties.FastDfs props)
    {
        this.props = props;
        // 实际项目中这里应该用 FastDFS Client 的 TrackerServer / StorageServer 初始化
        // 详见 https://github.com/happyfish100/fastdfs-client-java
        log.info("[FastDfsStorage] init tracker={}", props.getTrackerServer());
    }

    @Override
    public String upload(String key, InputStream input, String contentType, Long size)
    {
        // TODO: 用 FastDFS Client 的 StorageClient 上传并返回 path
        // 此处仅占位
        throw new UnsupportedOperationException(
            "FastDFS 适配器需要 fastdfs-client-java 依赖，请参考 RuoYi 官方 ruoyi-file 模块实现"
        );
    }

    @Override
    public void delete(String key)
    {
        throw new UnsupportedOperationException("FastDFS delete 未实现");
    }

    @Override
    public String getPublicUrl(String key)
    {
        // FastDFS 没有统一域名，返回 tracker 拼接的相对路径
        return "/fastdfs/" + key;
    }

    @Override
    public String getType()
    {
        return "fastdfs";
    }
}
