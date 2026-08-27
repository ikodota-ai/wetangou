package com.ruoyi.web.controller.biz;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.biz.domain.SaleChannel;
import com.ruoyi.biz.service.ISaleChannelService;

/**
 * 投放渠道字典 biz_sale_channel
 *
 * <p>平台级保底配置：渠道是全平台统一的分发位，商户只能在建品时勾选、不能增删渠道本身，
 * 所以 SQL 里只给 role_id=1（平台管理员）授权。</p>
 *
 * <p>{@code /enabled} 单独开一个端点给「建品页读渠道列表」用，并加 {@code @Anonymous}：
 * 后台商品编辑页（商户账号也会打开）和小程序商家端建品页都要读它。
 * 小程序带的是 staff/member token 而不是 admin JWT，SecurityConfig 里只有
 * {@code /api/**} 是 permitAll，所以不加 @Anonymous 小程序一定 401 ——
 * 同目录的 {@code /biz/productType/appCreatable} 出于同样原因也是 @Anonymous。
 * 渠道字典只有渠道名和投放说明，不含任何租户数据，公开可读没有泄漏风险。</p>
 */
@RestController
@RequestMapping("/biz/saleChannel")
public class BizSaleChannelController extends BaseController
{
    @Autowired
    private ISaleChannelService channelService;

    @PreAuthorize("@ss.hasPermi('biz:saleChannel:list')")
    @GetMapping("/list")
    public TableDataInfo list(SaleChannel query)
    {
        startPage();
        return getDataTable(channelService.selectSaleChannelList(query));
    }

    /**
     * 启用中的渠道 + 默认勾选项，供后台/小程序两端的建品页渲染。
     * 不挂字典管理权限（商户账号也要用），见类注释里 @Anonymous 的原因。
     */
    @Anonymous
    @GetMapping("/enabled")
    public AjaxResult enabled()
    {
        List<SaleChannel> list = channelService.selectEnabled();
        AjaxResult r = AjaxResult.success();
        r.put("data", list);
        r.put("defaultCodes", channelService.defaultChannelCodes());
        return r;
    }

    @PreAuthorize("@ss.hasPermi('biz:saleChannel:query')")
    @GetMapping("/{channelCode}")
    public AjaxResult getInfo(@PathVariable String channelCode)
    {
        return success(channelService.selectByCode(channelCode));
    }

    @PreAuthorize("@ss.hasPermi('biz:saleChannel:add')")
    @Log(title = "投放渠道", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody SaleChannel channel)
    {
        if (channel == null || channel.getChannelCode() == null || channel.getChannelCode().trim().isEmpty())
        {
            throw new ServiceException("渠道代码不能为空");
        }
        if (channel.getChannelName() == null || channel.getChannelName().trim().isEmpty())
        {
            throw new ServiceException("渠道名称不能为空");
        }
        if (channelService.selectByCode(channel.getChannelCode().trim()) != null)
        {
            throw new ServiceException("渠道代码已存在：" + channel.getChannelCode());
        }
        channel.setChannelCode(channel.getChannelCode().trim());
        return toAjax(channelService.insertSaleChannel(channel));
    }

    @PreAuthorize("@ss.hasPermi('biz:saleChannel:edit')")
    @Log(title = "投放渠道", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody SaleChannel channel)
    {
        if (channel == null || channel.getChannelCode() == null || channel.getChannelCode().trim().isEmpty())
        {
            throw new ServiceException("渠道代码不能为空");
        }
        if (channelService.selectByCode(channel.getChannelCode()) == null)
        {
            throw new ServiceException("渠道不存在：" + channel.getChannelCode());
        }
        return toAjax(channelService.updateSaleChannel(channel));
    }

    /**
     * 删除渠道。DELETE 按 RESTful 语义做幂等：代码不存在时返 success 而不是 500。
     * （E6 修过同型 bug：toAjax(rows) 在 rows=0 时返 error，客户端拿到 500。）
     */
    @PreAuthorize("@ss.hasPermi('biz:saleChannel:remove')")
    @Log(title = "投放渠道", businessType = BusinessType.DELETE)
    @DeleteMapping("/{channelCodes}")
    public AjaxResult remove(@PathVariable String[] channelCodes)
    {
        channelService.deleteByCodes(channelCodes);
        return success();
    }
}
