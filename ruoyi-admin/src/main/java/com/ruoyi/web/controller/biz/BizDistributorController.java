package com.ruoyi.web.controller.biz;

import java.io.File;
import java.io.FileOutputStream;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.biz.api.service.WxMaService;
import com.ruoyi.biz.domain.Distributor;
import com.ruoyi.biz.service.IDistributorService;
import com.ruoyi.common.config.RuoYiConfig;
import com.ruoyi.framework.config.ServerConfig;
import com.ruoyi.common.constant.Constants;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;

/**
 * 推客管理（admin 端）— 扩展端点
 * 对应 doc 下一轮迭代清单 E4：admin 端查看推客二维码
 *
 * <p>列表 / 详情 / 增删改 在 ruoyi-system 的
 * {@code com.ruoyi.biz.controller.DistributorController}（路径同 /biz/distributor/*），
 * 这里只放新增的 qrcode 端点（/biz/distributor/qrcode?distributorId=），避开 /{distributorId} 冲突。</p>
 *
 * <p>复用 E10 文件层缓存：按 qr_<memberId>_*.png 命中文件直接返 URL，miss 才调 wxacode。
 * 与小程序端 ApiDistributorController.qrcode() 走同一组文件。</p>
 */
@RestController
@RequestMapping("/biz/distributor")
public class BizDistributorController extends BaseController
{
    @Autowired
    private IDistributorService distributorService;

    @Autowired
    private WxMaService wxMaService;

    @Autowired
    private ServerConfig serverConfig;

    /**
     * E4: 推客太阳码（admin 端预览）。
     * URL: GET /biz/distributor/qrcode?distributorId=123
     * 用 query string 而非 path 变量，避免与 /{distributorId} 冲突。
     */
    @PreAuthorize("@ss.hasPermi('biz:distributor:query')")
    @GetMapping("/qrcode")
    public AjaxResult qrcode(Long distributorId) throws Exception
    {
        if (distributorId == null) return error("缺少 distributorId");
        Distributor d = distributorService.selectDistributorByDistributorId(distributorId);
        if (d == null) return error("推客不存在");
        Long memberId = d.getMemberId();
        Long merchantId = d.getMerchantId() == null ? 1L : d.getMerchantId();
        String scene = "distributor:" + merchantId + ":" + memberId;

        String dir = RuoYiConfig.getProfile() + "/distributor";
        File dirFile = new File(dir);
        if (!dirFile.exists() && !dirFile.mkdirs()) return error("无法创建太阳码目录");
        String baseName = "qr_" + memberId;
        File[] existing = dirFile.listFiles(new java.io.FilenameFilter()
        {
            @Override
            public boolean accept(File dir, String name)
            {
                return name.startsWith(baseName + "_") && name.endsWith(".png");
            }
        });
        if (existing != null && existing.length > 0)
        {
            File latest = existing[0];
            for (File f : existing)
            {
                if (f.lastModified() > latest.lastModified()) latest = f;
            }
            String relativePath = "/distributor/" + latest.getName();
            String url = serverConfig.getUrl() + Constants.RESOURCE_PREFIX + relativePath;
            return success().put("url", url).put("scene", scene).put("fileName", latest.getName()).put("cached", true);
        }

        byte[] bytes = wxMaService.getWxaCodeUnlimited(scene, "pages/index/index", merchantId);
        if (bytes == null || bytes.length == 0) return error("生成太阳码失败");
        String fileName = baseName + "_" + System.currentTimeMillis() + ".png";
        File target = new File(dir, fileName);
        try (FileOutputStream fos = new FileOutputStream(target))
        {
            fos.write(bytes);
        }
        String relativePath = "/distributor/" + fileName;
        String url = serverConfig.getUrl() + Constants.RESOURCE_PREFIX + relativePath;
        return success().put("url", url).put("scene", scene).put("fileName", fileName).put("cached", false);
    }
}
