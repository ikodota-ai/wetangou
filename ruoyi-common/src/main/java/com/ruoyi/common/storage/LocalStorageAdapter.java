package com.ruoyi.common.storage;

import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import com.ruoyi.common.config.RuoYiConfig;

/**
 * 本地磁盘存储适配器（默认实现）
 *
 * <p>key 形如 "upload/2026/08/02/abc.jpg" → 写入 {@code RuoYiConfig.getProfile() + "/" + key}，
 * 返回的 URL 形如 "/profile/upload/2026/08/02/abc.jpg"，由前端通过 nginx 代理
 * （参见 vue.config.js 的 /profile 代理 + 操作手册第 13 节 nginx 配置）访问。</p>
 *
 * @author dytuangou
 */
public class LocalStorageAdapter implements StorageAdapter
{
    private static final Logger log = LoggerFactory.getLogger(LocalStorageAdapter.class);

    @Override
    public String upload(String key, InputStream input, String contentType, Long size)
    {
        try
        {
            Path target = Paths.get(RuoYiConfig.getProfile(), key);
            Files.createDirectories(target.getParent());
            Files.copy(input, target, java.nio.file.StandardCopyOption.REPLACE_EXISTING);
            log.info("[LocalStorage] upload {} ({} bytes)", target, size);
            return "/profile/" + key;
        }
        catch (Exception e)
        {
            throw new RuntimeException("本地存储上传失败: " + key, e);
        }
    }

    @Override
    public void delete(String key)
    {
        try
        {
            Path target = Paths.get(RuoYiConfig.getProfile(), key);
            Files.deleteIfExists(target);
        }
        catch (Exception e)
        {
            log.warn("[LocalStorage] delete 失败 {}", key, e);
        }
    }

    @Override
    public String getPublicUrl(String key)
    {
        return "/profile/" + key;
    }

    @Override
    public String getType()
    {
        return "local";
    }
}
