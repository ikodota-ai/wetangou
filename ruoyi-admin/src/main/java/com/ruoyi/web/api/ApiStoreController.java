package com.ruoyi.web.api;

import java.util.ArrayList;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestParam;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.service.ISysDictDataService;
import com.ruoyi.biz.domain.Store;
import com.ruoyi.biz.domain.StoreAlbum;
import com.ruoyi.biz.service.IStoreService;
import com.ruoyi.biz.service.IStoreAlbumService;
import com.ruoyi.common.utils.image.ImageUrlUtils;

/**
 * 小程序-门店
 *
 * @author dytuangou
 */
@Anonymous
@RestController
@RequestMapping("/api/store")
public class ApiStoreController
{
    @Autowired
    private IStoreService storeService;

    @Autowired
    private IStoreAlbumService storeAlbumService;

    @Autowired
    private ISysDictDataService dictDataService;

    /** 门店设施服务字典类型 */
    private static final String DICT_STORE_SERVICE = "biz_store_service";

    /**
     * 距离用户最近的 N 个门店（默认 10 个，最多 50）
     *
     * <p>小程序首页进入时由前端用 wx.getLocation 拿经纬度，传入 longitude/latitude。
     * 后端用 Haversine 公式按球面距离排序，返回当前 X-App-Id 解析到的商户下
     * status=0 / del_flag=0 / 经纬度非空的门店。</p>
     *
     * <p>不带经纬度时退化为按 store_id 倒序取前 N 个，确保至少有一个默认门店可显示。</p>
     */
    @GetMapping("/nearest")
    public AjaxResult nearest(
            @RequestParam(value = "longitude", required = false) Double longitude,
            @RequestParam(value = "latitude", required = false) Double latitude,
            @RequestParam(value = "limit", required = false, defaultValue = "10") int limit)
    {
        List<Store> list = storeService.selectNearestStoreList(longitude, latitude, limit);
        return AjaxResult.success(fillImageUrls(list));
    }

    /**
     * 门店列表（仅正常状态）
     */
    @GetMapping("/list")
    public AjaxResult list(Store query)
    {
        query.setStatus("0");
        query.setDelFlag("0");
        List<Store> list = storeService.selectStoreList(query);
        return AjaxResult.success(fillImageUrls(list));
    }

    /**
     * 门店详情
     */
    @GetMapping("/{storeId}")
    public AjaxResult detail(@PathVariable Long storeId)
    {
        Store s = storeService.selectStoreByStoreId(storeId);
        if (s != null)
        {
            s.setLogo(ImageUrlUtils.toAbsolute(s.getLogo()));
        }
        return AjaxResult.success(s);
    }

    /**
     * 门店设施与服务标签
     *
     * <p>门店表的 services 存的是字典码值（如 dine_in），此处翻译为中文标签，
     * 避免小程序端硬编码一份映射表导致后台加了新码值前端不显示。</p>
     */
    @GetMapping("/{storeId}/services")
    public AjaxResult services(@PathVariable Long storeId)
    {
        Store store = storeService.selectStoreByStoreId(storeId);
        List<String> labels = new ArrayList<String>();
        if (store != null && StringUtils.isNotEmpty(store.getServices()))
        {
            for (String code : store.getServices().split(","))
            {
                String label = dictDataService.selectDictLabel(DICT_STORE_SERVICE, code.trim());
                labels.add(StringUtils.isEmpty(label) ? code.trim() : label);
            }
        }
        return AjaxResult.success(labels);
    }

    /**
     * 门店相册
     */
    @GetMapping("/{storeId}/album")
    public AjaxResult album(@PathVariable Long storeId)
    {
        StoreAlbum query = new StoreAlbum();
        query.setStoreId(storeId);
        List<StoreAlbum> list = storeAlbumService.selectStoreAlbumList(query);
        // 同门店列表/详情的 logo：库里存的是相对路径（实测 4 条
        // /profile/upload/demo/*.jpg），不补成绝对 URL 的话，小程序 <image src>
        // 走原生加载不经过任何代理，直接 404。这个端点原先是三个图片出口里
        // 唯一漏做绝对化的。
        if (list != null)
        {
            for (StoreAlbum a : list)
            {
                a.setImageUrl(ImageUrlUtils.toAbsolute(a.getImageUrl()));
            }
        }
        return AjaxResult.success(list);
    }

    /**
     * 把门店列表的 logo 转成绝对 URL，
     * 避免小程序 webview / &lt;image src&gt; 走原生加载时 404。
     */
    private List<Store> fillImageUrls(List<Store> list)
    {
        if (list == null)
        {
            return null;
        }
        for (Store s : list)
        {
            s.setLogo(ImageUrlUtils.toAbsolute(s.getLogo()));
        }
        return list;
    }
}
