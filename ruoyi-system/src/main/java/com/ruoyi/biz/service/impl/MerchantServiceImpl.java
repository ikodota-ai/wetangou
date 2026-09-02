package com.ruoyi.biz.service.impl;

import java.util.Date;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.biz.domain.Agent;
import com.ruoyi.biz.domain.Merchant;
import com.ruoyi.biz.domain.MerchantStaff;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.biz.mapper.AgentMapper;
import com.ruoyi.biz.mapper.MerchantMapper;
import com.ruoyi.biz.service.IMerchantService;
import com.ruoyi.biz.service.ITenantService;
import com.ruoyi.common.core.domain.model.TenantContext;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.common.utils.TenantContextHolder;

/**
 * 商户Service业务层处理
 *
 * @author dytuangou
 */
@Service
public class MerchantServiceImpl implements IMerchantService
{
    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(MerchantServiceImpl.class);

    /** PC 后台「商户管理员」角色的 role_key（role_id 各环境不一致，只认 key） */
    private static final String OWNER_PC_ROLE_KEY = "merchant";

    @Autowired
    private MerchantMapper merchantMapper;

    @Autowired
    private com.ruoyi.system.mapper.SysRoleMapper roleMapper;

    @Autowired
    private AgentMapper agentMapper;

    @Autowired
    private ITenantService tenantService;

    /**
     * 用 @Lazy 注入：SysUserServiceImpl 本身依赖 IMerchantService（同步租户身份用），
     * 直接注入会构成 merchantServiceImpl ↔ sysUserServiceImpl 循环依赖导致启动失败。
     * 这里只在「新增商户自动开通老板账号」时用到，延迟到首次调用再解析即可。
     */
    @Autowired
    @org.springframework.context.annotation.Lazy
    private com.ruoyi.system.service.ISysUserService userService;

    @Autowired
    private com.ruoyi.biz.service.IMerchantStaffService merchantStaffService;

    /**
     * 查询商户
     */
    @Override
    public Merchant selectMerchantByMerchantId(Long merchantId)
    {
        return merchantMapper.selectMerchantByMerchantId(merchantId);
    }

    /**
     * 查询商户列表：代理商仅可见名下商户，商户账号仅可见自己
     */
    @Override
    public List<Merchant> selectMerchantList(Merchant merchant)
    {
        TenantContext context = TenantContextHolder.get();
        if (context != null && context.isAgent())
        {
            merchant.setAgentId(context.getAgentId());
        }
        else if (context != null && context.isMerchant())
        {
            merchant.getParams().put("merchantIds", String.valueOf(context.getMerchantId()));
        }
        return merchantMapper.selectMerchantList(merchant);
    }

    /**
     * 新增商户
     *
     * <p>代理商开通商户时校验剩余额度与代理资格有效期，成功后占用一个额度。</p>
     */
    @Override
    public int insertMerchant(Merchant merchant)
    {
        normalizeAppid(merchant);
        if (!checkAppidUnique(merchant))
        {
            throw new ServiceException("新增商户失败，小程序AppId已被占用：" + merchant.getAppid());
        }
        TenantContext context = TenantContextHolder.get();
        if (context != null && context.isAgent())
        {
            // 代理商只能把商户开在自己名下
            merchant.setAgentId(context.getAgentId());
            checkAgentQuota(context.getAgentId());
        }
        if (merchant.getAgentId() == null)
        {
            merchant.setAgentId(0L);
        }
        if (StringUtils.isEmpty(merchant.getMerchantNo()))
        {
            merchant.setMerchantNo(generateMerchantNo());
        }
        if (StringUtils.isEmpty(merchant.getStatus()))
        {
            merchant.setStatus("0");
        }
        merchant.setCreateBy(SecurityUtils.getUsername());
        int rows = merchantMapper.insertMerchant(merchant);
        if (rows > 0 && merchant.getAgentId() != null && merchant.getAgentId() > 0L)
        {
            agentMapper.increaseUsedQuota(merchant.getAgentId());
        }
        if (rows > 0)
        {
            createOwnerAccount(merchant);
        }
        return rows;
    }

    /**
     * 建商户时自动开通老板账号（商家版 OWNER 入口）。
     *
     * <p>为什么必须自动建：biz_merchant 上没有 owner_user_id，商户与老板账号之间
     * 没有任何关联字段；而商家版登录（{@code /api/merchant/staff/login|wxLogin}）
     * 强制要求 biz_merchant_staff 里存在在职关联，否则抛「该账号未关联商家」。
     * 所以平台新建商户后，老板此前根本没有任何可登录的凭证 —— 只能靠人工往
     * biz_merchant_staff 插一条 OWNER 才能进商家版。</p>
     *
     * <p>store_id=0 表示「全商户所有门店」，这样后续加门店不必再补员工关联。</p>
     *
     * <p>初始密码明文只在返回值里带回一次（{@link Merchant#getOwnerInitPassword()}），
     * 不落库；遗失后由平台/店长在后台重置。</p>
     *
     * <p>失败不阻断建商户：账号建不出来可以事后补建或重置，但商户主记录不该因此回滚。</p>
     */
    private void createOwnerAccount(Merchant merchant)
    {
        try
        {
            String userName = buildOwnerUserName(merchant);
            if (userName == null)
            {
                return;
            }
            String rawPwd = randomPassword();
            SysUser u = new SysUser();
            u.setUserName(userName);
            u.setNickName(StringUtils.isEmpty(merchant.getMerchantName()) ? "商家老板" : merchant.getMerchantName());
            u.setPassword(SecurityUtils.encryptPassword(rawPwd));
            u.setPhonenumber(merchant.getPhone());
            u.setStatus("0");
            u.setDelFlag("0");
            // 必须是 02（商户侧）：00 会在 StaffLoginMemberBuilder 里被判为 PLATFORM 角色
            u.setUserType("02");
            u.setMerchantId(merchant.getMerchantId());
            // 同步 biz_merchant_user，否则 PC 端 TenantContext 会兜底成平台身份
            u.setTenantUserType("2");
            u.setTenantMerchantId(merchant.getMerchantId());
            // PC 后台「商户管理员」角色，让老板也能登录后台
            Long pcRoleId = resolveOwnerPcRoleId();
            if (pcRoleId != null)
            {
                u.setRoleIds(new Long[] { pcRoleId });
            }
            u.setCreateBy(SecurityUtils.getUsername());
            u.setCreateTime(new Date());
            userService.insertUser(u);

            MerchantStaff ms = new MerchantStaff();
            ms.setMerchantId(merchant.getMerchantId());
            // 0 = 全商户所有门店（老板不绑定到具体门店）
            ms.setStoreId(0L);
            ms.setUserId(u.getUserId());
            ms.setRole("OWNER");
            ms.setRealName(u.getNickName());
            ms.setPhone(merchant.getPhone());
            // 平台开通的老板无需审核，直接在职
            ms.setStatus("0");
            ms.setCreateBy(SecurityUtils.getUsername());
            ms.setCreateTime(new Date());
            merchantStaffService.insert(ms);

            merchant.setOwnerUserName(userName);
            merchant.setOwnerInitPassword(rawPwd);
        }
        catch (Exception e)
        {
            log.error("[Merchant] 自动开通老板账号失败 merchantId={}", merchant.getMerchantId(), e);
        }
    }

    /**
     * 查 PC 后台「商户管理员」角色 id；查不到返 null（只记警告，不阻断建商户）。
     *
     * <p>为什么不能写死 5L：role_id 由建库时的插入顺序决定，各环境不一致。
     * sql/biz_tenant_menu.sql 插这条角色时用的是
     * {@code WHERE NOT EXISTS (SELECT 1 FROM sys_role WHERE role_key='merchant')} ——
     * 也就是「已存在同 key 就跳过」，那么在一个先有别的角色、后跑该脚本的库里，
     * role_key='merchant' 完全可能落在 6/7/8。此时写死 5L 会把新建商户的老板
     * 绑到 role_id=5 那个「另一个角色」上：轻则老板进后台看不到商品/门店菜单，
     * 重则误绑到高权角色（本地库 role_id=5 恰好就是 merchant，所以一直没暴露）。</p>
     *
     * <p>必须走 mapper 而不是 ISysRoleService.selectRoleList：后者带 @DataScope 切面，
     * 会去 SecurityContext 取当前登录用户拼数据范围，而本方法也被
     * resetOwnerAccount 的补建分支调用，链路里不一定有完整上下文。
     * 与 ApiMerchantStaffController.resolvePcRoleId 保持同一口径。</p>
     */
    private Long resolveOwnerPcRoleId()
    {
        try
        {
            com.ruoyi.common.core.domain.entity.SysRole role = roleMapper.checkRoleKeyUnique(OWNER_PC_ROLE_KEY);
            if (role != null && role.getRoleId() != null)
            {
                return role.getRoleId();
            }
        }
        catch (Exception e)
        {
            log.error("[Merchant] 查询 role_key={} 失败，老板账号将没有后台权限", OWNER_PC_ROLE_KEY, e);
            return null;
        }
        log.warn("[Merchant] 未找到 role_key={} 的 PC 角色，老板账号将没有后台权限（请先执行 sql/biz_tenant_menu.sql）",
                OWNER_PC_ROLE_KEY);
        return null;
    }

    /**
     * 重置商户老板账号密码；若该商户还没有老板账号则先补建。
     *
     * <p>为什么要「必要时补建」：自动开通老板账号是本次才加的，之前建的商户
     * biz_merchant_staff 里一条 OWNER 都没有，这些老板至今没有任何可登录商家版的凭证。
     * 如果这个接口只做「重置」，历史商户就永远补不上账号，只能手工插库。</p>
     *
     * <p>新密码明文只在返回值里带回一次，不落库、不写日志。</p>
     */
    @Override
    public Merchant resetOwnerAccount(Long merchantId)
    {
        checkMerchantDataScope(merchantId);
        Merchant merchant = merchantMapper.selectMerchantByMerchantId(merchantId);
        if (merchant == null)
        {
            throw new ServiceException("商户不存在");
        }

        MerchantStaff query = new MerchantStaff();
        query.setMerchantId(merchantId);
        query.setRole("OWNER");
        List<MerchantStaff> owners = merchantStaffService.selectList(query);
        Long ownerUserId = null;
        for (MerchantStaff ms : owners)
        {
            if (ms.getUserId() != null && userService.selectUserByUserId(ms.getUserId()) != null)
            {
                ownerUserId = ms.getUserId();
                break;
            }
        }

        Merchant result = new Merchant();
        if (ownerUserId == null)
        {
            // 历史商户没有老板账号：走一次自动开通，账号名/密码由 createOwnerAccount 回带
            createOwnerAccount(merchant);
            if (StringUtils.isEmpty(merchant.getOwnerUserName()))
            {
                throw new ServiceException("补建老板账号失败，请检查该商户号是否重复");
            }
            result.setOwnerUserName(merchant.getOwnerUserName());
            result.setOwnerInitPassword(merchant.getOwnerInitPassword());
            return result;
        }

        SysUser exist = userService.selectUserByUserId(ownerUserId);
        String rawPwd = randomPassword();
        SysUser upd = new SysUser();
        upd.setUserId(ownerUserId);
        upd.setPassword(SecurityUtils.encryptPassword(rawPwd));
        upd.setUpdateBy(SecurityUtils.getUsername());
        if (userService.resetPwd(upd) <= 0)
        {
            throw new ServiceException("重置老板密码失败");
        }
        result.setOwnerUserName(exist.getUserName());
        result.setOwnerInitPassword(rawPwd);
        return result;
    }

    /**
     * 老板登录账号：优先 {@code 商户号_boss}，重名则追加随机后缀。
     */
    private String buildOwnerUserName(Merchant merchant)
    {
        String base = StringUtils.isEmpty(merchant.getMerchantNo())
                ? ("m" + merchant.getMerchantId())
                : merchant.getMerchantNo();
        String candidate = base + "_boss";
        for (int i = 0; i < 6; i++)
        {
            SysUser probe = new SysUser();
            probe.setUserName(candidate);
            if (userService.checkUserNameUnique(probe))
            {
                return candidate;
            }
            candidate = base + "_boss" + randomDigits(3);
        }
        return null;
    }

    /** 初始密码：8 位大小写+数字，避开易混字符（0/O/1/l/I） */
    private String randomPassword()
    {
        String pool = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789";
        StringBuilder sb = new StringBuilder();
        java.security.SecureRandom rnd = new java.security.SecureRandom();
        for (int i = 0; i < 8; i++)
        {
            sb.append(pool.charAt(rnd.nextInt(pool.length())));
        }
        return sb.toString();
    }

    private String randomDigits(int len)
    {
        java.security.SecureRandom rnd = new java.security.SecureRandom();
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < len; i++)
        {
            sb.append(rnd.nextInt(10));
        }
        return sb.toString();
    }

    /**
     * 修改商户
     */
    @Override
    public int updateMerchant(Merchant merchant)
    {
        checkMerchantDataScope(merchant.getMerchantId());
        normalizeAppid(merchant);
        if (!checkAppidUnique(merchant))
        {
            throw new ServiceException("修改商户失败，小程序AppId已被占用：" + merchant.getAppid());
        }
        TenantContext context = TenantContextHolder.get();
        if (context != null && !context.isPlatform())
        {
            // 非平台账号不允许改变商户归属
            merchant.setAgentId(null);
        }
        merchant.setUpdateBy(SecurityUtils.getUsername());
        int rows = merchantMapper.updateMerchant(merchant);
        // 只有「显式提交空 appid」才清，不能凭 getAppid()==null 判断 ——
        // 编辑商户名时 JSON 不带 appid 字段也是 null，那种情况绝不能把已配好的 appid 抹掉。
        // 动态 set 里 <if appid != null> 不会生成置空语句，所以要走专用 clearAppid。
        if (merchant.isAppidCleared() && merchant.getMerchantId() != null)
        {
            merchantMapper.clearAppid(merchant.getMerchantId());
        }
        tenantService.clearMerchantCache(merchant.getMerchantId());
        return rows;
    }

    /**
     * 批量删除商户（逻辑删除）
     */
    @Override
    public int deleteMerchantByMerchantIds(Long[] merchantIds)
    {
        if (merchantIds == null)
        {
            return 0;
        }
        for (Long merchantId : merchantIds)
        {
            checkMerchantDataScope(merchantId);
        }
        int rows = merchantMapper.deleteMerchantByMerchantIds(merchantIds);
        for (Long merchantId : merchantIds)
        {
            tenantService.clearMerchantCache(merchantId);
        }
        return rows;
    }

    /**
     * 校验appid唯一性
     */
    /**
     * 未填 appid 时必须落 NULL，不能落空串。
     *
     * <p>根因：biz_merchant.appid 是 UNIQUE KEY 且默认值 ''。MySQL 唯一索引允许多个 NULL，
     * 但不允许多个 ''。于是「第一个不填 appid 的商户」能建，第二个必然报
     * Duplicate entry '' for key 'uk_appid' —— 平台开通新商户时如果没同时填小程序 appid
     * （很常见：先建商户，等商家提供小程序资质后再回来配），第二家起就永远建不出来。
     * 实测：商户 203 落了 ''，再建 zzt7 直接 500。</p>
     *
     * <p>顺带 trim：前端粘贴 appid 常带首尾空格，带空格的 appid 匹配不上任何请求。</p>
     */
    private void normalizeAppid(Merchant merchant)
    {
        if (merchant.getAppid() != null)
        {
            String v = merchant.getAppid().trim();
            if (v.isEmpty())
            {
                // 显式提交了空 appid = 要求解绑小程序，记标记让 update 走 clearAppid
                merchant.setAppid(null);
                merchant.setAppidCleared(true);
            }
            else
            {
                merchant.setAppid(v);
            }
        }
        if (merchant.getPayAppid() != null)
        {
            merchant.setPayAppid(merchant.getPayAppid().trim());
        }
    }

    @Override
    public boolean checkAppidUnique(Merchant merchant)
    {
        if (StringUtils.isEmpty(merchant.getAppid()))
        {
            return true;
        }
        Merchant exists = merchantMapper.selectMerchantByAppid(merchant.getAppid());
        if (exists == null)
        {
            return true;
        }
        return merchant.getMerchantId() != null && merchant.getMerchantId().equals(exists.getMerchantId());
    }

    /**
     * 校验当前账号是否有权操作该商户
     */
    @Override
    public void checkMerchantDataScope(Long merchantId)
    {
        TenantContext context = TenantContextHolder.get();
        if (context == null || context.isPlatform() || merchantId == null)
        {
            return;
        }
        if (context.isAgent())
        {
            if (!context.getMerchantIds().contains(merchantId))
            {
                throw new ServiceException("没有权限访问该商户数据");
            }
            return;
        }
        if (!merchantId.equals(context.getMerchantId()))
        {
            throw new ServiceException("没有权限访问该商户数据");
        }
    }

    /**
     * 校验代理商开户额度与资格有效期
     */
    private void checkAgentQuota(Long agentId)
    {
        Agent agent = agentMapper.selectAgentByAgentId(agentId);
        if (agent == null)
        {
            throw new ServiceException("代理商信息不存在");
        }
        if (!"0".equals(agent.getStatus()))
        {
            throw new ServiceException("代理商已停用，无法开通商户");
        }
        if (agent.getExpireTime() != null && agent.getExpireTime().before(new Date()))
        {
            throw new ServiceException("代理资格已到期，请先向平台续费");
        }
        int quota = agent.getMerchantQuota() == null ? 0 : agent.getMerchantQuota();
        int used = agent.getUsedQuota() == null ? 0 : agent.getUsedQuota();
        if (used >= quota)
        {
            throw new ServiceException("商户开通额度已用尽（" + used + "/" + quota + "），请先向平台购买额度");
        }
    }

    /**
     * 生成商户编号
     */
    private String generateMerchantNo()
    {
        return "MC" + System.currentTimeMillis();
    }
}
