package com.ruoyi.web.api;

import java.util.ArrayList;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.service.ISysDictDataService;
import com.ruoyi.biz.domain.Store;
import com.ruoyi.biz.domain.StoreAlbum;
import com.ruoyi.biz.service.IStoreService;
import com.ruoyi.biz.service.IStoreAlbumService;

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
     * 门店列表（仅正常状态）
     */
    @GetMapping("/list")
    public AjaxResult list(Store query)
    {
        query.setStatus("0");
        List<Store> list = storeService.selectStoreList(query);
        return AjaxResult.success(list);
    }

    /**
     * 门店详情
     */
    @GetMapping("/{storeId}")
    public AjaxResult detail(@PathVariable Long storeId)
    {
        return AjaxResult.success(storeService.selectStoreByStoreId(storeId));
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
        return AjaxResult.success(list);
    }
}
