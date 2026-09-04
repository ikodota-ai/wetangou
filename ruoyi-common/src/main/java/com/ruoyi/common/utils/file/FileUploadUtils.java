package com.ruoyi.common.utils.file;

import java.io.File;
import java.io.IOException;
import java.nio.file.Paths;
import java.util.Objects;
import org.apache.commons.io.FilenameUtils;
import org.springframework.web.multipart.MultipartFile;
import com.ruoyi.common.config.RuoYiConfig;
import com.ruoyi.common.constant.Constants;
import com.ruoyi.common.exception.file.FileNameLengthLimitExceededException;
import com.ruoyi.common.exception.file.FileSizeLimitExceededException;
import com.ruoyi.common.exception.file.InvalidExtensionException;
import com.ruoyi.common.utils.DateUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.common.utils.uuid.IdUtils;
import com.ruoyi.common.utils.uuid.Seq;

/**
 * 文件上传工具类
 * 
 * @author ruoyi
 */
public class FileUploadUtils
{
    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(FileUploadUtils.class);

    /**
     * 默认大小 50M
     */
    public static final long DEFAULT_MAX_SIZE = 50 * 1024 * 1024L;

    /**
     * 默认的文件名最大长度 100
     */
    public static final int DEFAULT_FILE_NAME_LENGTH = 100;

    /**
     * 默认上传的地址
     */
    private static String defaultBaseDir = RuoYiConfig.getProfile();

    public static void setDefaultBaseDir(String defaultBaseDir)
    {
        FileUploadUtils.defaultBaseDir = defaultBaseDir;
    }

    public static String getDefaultBaseDir()
    {
        return defaultBaseDir;
    }

    /**
     * 以默认配置进行文件上传
     *
     * @param file 上传的文件
     * @return 文件名称
     * @throws Exception
     */
    public static final String upload(MultipartFile file) throws IOException
    {
        try
        {
            return upload(getDefaultBaseDir(), file, MimeTypeUtils.DEFAULT_ALLOWED_EXTENSION);
        }
        catch (Exception e)
        {
            throw new IOException(e.getMessage(), e);
        }
    }

    /**
     * 根据文件路径上传
     *
     * @param baseDir 相对应用的基目录
     * @param file 上传的文件
     * @return 文件名称
     * @throws IOException
     */
    public static final String upload(String baseDir, MultipartFile file) throws IOException
    {
        try
        {
            return upload(baseDir, file, MimeTypeUtils.DEFAULT_ALLOWED_EXTENSION);
        }
        catch (Exception e)
        {
            throw new IOException(e.getMessage(), e);
        }
    }

    /**
     * 文件上传
     *
     * @param baseDir 相对应用的基目录
     * @param file 上传的文件
     * @param allowedExtension 上传文件类型
     * @return 返回上传成功的文件名
     * @throws FileSizeLimitExceededException 如果超出最大大小
     * @throws FileNameLengthLimitExceededException 文件名太长
     * @throws IOException 比如读写文件出错时
     * @throws InvalidExtensionException 文件校验异常
     */
    public static final String upload(String baseDir, MultipartFile file, String[] allowedExtension)
            throws FileSizeLimitExceededException, IOException, FileNameLengthLimitExceededException,
            InvalidExtensionException
    {
        return upload(baseDir, file, allowedExtension, false);
    }
    
    /**
     * 文件上传
     *
     * @param baseDir 相对应用的基目录
     * @param file 上传的文件
     * @param useCustomNaming 系统自定义文件名
     * @param allowedExtension 上传文件类型
     * @return 返回上传成功的文件名
     * @throws FileSizeLimitExceededException 如果超出最大大小
     * @throws FileNameLengthLimitExceededException 文件名太长
     * @throws IOException 比如读写文件出错时
     * @throws InvalidExtensionException 文件校验异常
     */
    public static final String upload(String baseDir, MultipartFile file, String[] allowedExtension, boolean useCustomNaming)
            throws FileSizeLimitExceededException, IOException, FileNameLengthLimitExceededException,
            InvalidExtensionException
    {
        int fileNameLength = Objects.requireNonNull(file.getOriginalFilename()).length();
        if (fileNameLength > FileUploadUtils.DEFAULT_FILE_NAME_LENGTH)
        {
            throw new FileNameLengthLimitExceededException(FileUploadUtils.DEFAULT_FILE_NAME_LENGTH);
        }

        assertAllowed(file, allowedExtension);

        String fileName = useCustomNaming ? uuidFilename(file) : extractFilename(file);

        String absPath = getAbsoluteFile(baseDir, fileName).getAbsolutePath();
        file.transferTo(Paths.get(absPath));
        return getPathFileName(baseDir, fileName);
    }

    /**
     * 编码文件名(日期格式目录 + 原文件名 + 序列值 + 后缀)
     */
    public static final String extractFilename(MultipartFile file)
    {
        return StringUtils.format("{}/{}_{}.{}", DateUtils.datePath(), FilenameUtils.getBaseName(file.getOriginalFilename()), Seq.getId(Seq.uploadSeqType), getExtension(file));
    }

    /**
     * 编编码文件名(日期格式目录 + UUID + 后缀)
     */
    public static final String uuidFilename(MultipartFile file)
    {
        return StringUtils.format("{}/{}.{}", DateUtils.datePath(), IdUtils.fastSimpleUUID(), getExtension(file));
    }

    public static final File getAbsoluteFile(String uploadDir, String fileName) throws IOException
    {
        File desc = new File(uploadDir + File.separator + fileName);

        if (!desc.exists())
        {
            if (!desc.getParentFile().exists())
            {
                desc.getParentFile().mkdirs();
            }
        }
        return desc;
    }

    public static final String getPathFileName(String uploadDir, String fileName) throws IOException
    {
        int dirLastIndex = RuoYiConfig.getProfile().length() + 1;
        String currentDir = StringUtils.substring(uploadDir, dirLastIndex);
        return Constants.RESOURCE_PREFIX + "/" + currentDir + "/" + fileName;
    }

    /**
     * 文件大小校验
     *
     * @param file 上传的文件
     * @return
     * @throws FileSizeLimitExceededException 如果超出最大大小
     * @throws InvalidExtensionException
     */
    public static final void assertAllowed(MultipartFile file, String[] allowedExtension)
            throws FileSizeLimitExceededException, InvalidExtensionException
    {
        long size = file.getSize();
        if (size > DEFAULT_MAX_SIZE)
        {
            throw new FileSizeLimitExceededException(DEFAULT_MAX_SIZE / 1024 / 1024);
        }

        String fileName = file.getOriginalFilename();
        String extension = getExtension(file);
        if (allowedExtension != null && !isAllowedExtension(extension, allowedExtension))
        {
            if (allowedExtension == MimeTypeUtils.IMAGE_EXTENSION)
            {
                throw new InvalidExtensionException.InvalidImageExtensionException(allowedExtension, extension,
                        fileName);
            }
            else if (allowedExtension == MimeTypeUtils.FLASH_EXTENSION)
            {
                throw new InvalidExtensionException.InvalidFlashExtensionException(allowedExtension, extension,
                        fileName);
            }
            else if (allowedExtension == MimeTypeUtils.MEDIA_EXTENSION)
            {
                throw new InvalidExtensionException.InvalidMediaExtensionException(allowedExtension, extension,
                        fileName);
            }
            else if (allowedExtension == MimeTypeUtils.VIDEO_EXTENSION)
            {
                throw new InvalidExtensionException.InvalidVideoExtensionException(allowedExtension, extension,
                        fileName);
            }
            else
            {
                throw new InvalidExtensionException(allowedExtension, extension, fileName);
            }
        }
    }

    /**
     * 判断MIME类型是否是允许的MIME类型
     *
     * @param extension
     * @param allowedExtension
     * @return
     */
    public static final boolean isAllowedExtension(String extension, String[] allowedExtension)
    {
        for (String str : allowedExtension)
        {
            if (str.equalsIgnoreCase(extension))
            {
                return true;
            }
        }
        return false;
    }

    /**
     * 获取文件名的后缀
     * 
     * @param file 表单文件
     * @return 后缀名
     */
    public static final String getExtension(MultipartFile file)
    {
        String extension = FilenameUtils.getExtension(file.getOriginalFilename());
        if (StringUtils.isEmpty(extension))
        {
            extension = MimeTypeUtils.getExtension(Objects.requireNonNull(file.getContentType()));
        }
        return extension;
    }

    /**
     * 走对象存储适配器上传（OSS / 七牛 / 本地，由 application.yml ruoyi.storage.type 决定）
     *
     * <p>此方法取代传统的本地磁盘 upload()，业务代码（CommonController / 业务上传）切换到本方法后，
     * 切换云存储只需改 application.yml，无需改代码。</p>
     *
     * <p>返回值为对外可访问的完整 URL（OSS / 七牛返回 https 域名 + key，本地返回 /profile + key）。</p>
     *
     * @param file 上传的文件
     * @return 公开访问 URL
     */
    public static final String uploadByStorage(MultipartFile file)
    {
        return uploadByStorage(null, file, MimeTypeUtils.DEFAULT_ALLOWED_EXTENSION, false);
    }

    /**
     * 走对象存储适配器上传（带 key 前缀 / 扩展名白名单 / 自定义命名）
     *
     * <p>头像等按业务分目录的场景用这个重载：keyPrefix 传 "avatar" 得到
     * key = {@code avatar/2026/09/04/xxx.jpg}，与旧的本地磁盘布局
     * （{@code RuoYiConfig.getAvatarPath()} = profile/avatar）保持一致，
     * 这样 local 适配器返回的 {@code /profile/avatar/...} 与历史入库数据同形，
     * 存量记录不会因为切换实现而失效。</p>
     *
     * @param keyPrefix        key 前缀（如 avatar），null / 空则不加前缀
     * @param file             上传的文件
     * @param allowedExtension 允许的扩展名
     * @param useCustomNaming  true 用 UUID 命名（避免中文原名 / 重名），false 用「原名_序号」
     * @return 公开访问 URL（OSS 返回 https 绝对地址，local 返回 /profile/... 相对路径）
     */
    public static final String uploadByStorage(String keyPrefix, MultipartFile file, String[] allowedExtension,
            boolean useCustomNaming)
    {
        try
        {
            int fileNameLength = Objects.requireNonNull(file.getOriginalFilename()).length();
            if (fileNameLength > FileUploadUtils.DEFAULT_FILE_NAME_LENGTH)
            {
                throw new FileNameLengthLimitExceededException(FileUploadUtils.DEFAULT_FILE_NAME_LENGTH);
            }
            // 复用旧的 allow / size 校验
            assertAllowed(file, allowedExtension);
            // key 形如 2026/09/04/原文件名_序号.jpg（带前缀时为 avatar/2026/09/04/uuid.jpg）
            String key = useCustomNaming ? uuidFilename(file) : extractFilename(file);
            if (StringUtils.isNotEmpty(keyPrefix))
            {
                key = StringUtils.trim(keyPrefix).replaceAll("^/+|/+$", "") + "/" + key;
            }
            return com.ruoyi.common.storage.StorageFactory.get().upload(
                    key, file.getInputStream(), file.getContentType(), file.getSize());
        }
        catch (Exception e)
        {
            throw new RuntimeException("对象存储上传失败", e);
        }
    }

    /**
     * 按公开 URL 反查 key 并删除（替代原先直接删本地磁盘文件的写法）
     *
     * <p>切到 OSS 后 {@code FileUtils.deleteFile(RuoYiConfig.getProfile() + url)} 必然删不到东西
     * （文件根本不在本机磁盘上），所以旧头像清理必须走适配器。</p>
     *
     * <p>无法识别前缀的（例如库里遗留的 {@code http://127.0.0.1:8080/profile/...} 绝对地址，
     * 而当前已切到 OSS）直接跳过：这类文件不在当前存储里，删不掉也不该报错。</p>
     */
    public static final void deleteByStorage(String url)
    {
        if (StringUtils.isEmpty(url))
        {
            return;
        }
        try
        {
            com.ruoyi.common.storage.StorageAdapter adapter = com.ruoyi.common.storage.StorageFactory.get();
            // local → "/profile/"；s3 → "https://<domain>/"
            String prefix = adapter.getPublicUrl("");
            if (StringUtils.isNotEmpty(prefix) && url.startsWith(prefix))
            {
                adapter.delete(url.substring(prefix.length()));
            }
            else
            {
                log.debug("[deleteByStorage] 前缀不匹配当前存储，跳过删除: {}", url);
            }
        }
        catch (Exception e)
        {
            // 删旧文件失败不能影响「换头像成功」这件事
            log.warn("[deleteByStorage] 删除失败 {}", url, e);
        }
    }

}
