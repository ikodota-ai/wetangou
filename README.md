<p align="center">
  <img alt="logo" src="miniprogram7/assets/img/RestaurantImg.png" width="120">
</p>
<h1 align="center" style="margin: 24px 0 8px; font-weight: 700;">Wetangou（多商户团购）</h1>
<h4 align="center">平台 · 代理商 · 商户 · 门店 四级体系 · 一码多店 · 推客分销</h4>
<p align="center">
  <a href="https://github.com/ikodota-ai/wetangou"><img src="https://img.shields.io/badge/github-ikodota--ai%2Fwetangou-181717?logo=github"></a>
  <img src="https://img.shields.io/badge/Spring%20Boot-4.0.6-6DB33F?logo=springboot">
  <img src="https://img.shields.io/badge/Vue-2.7-4FC08D?logo=vue.js">
  <img src="https://img.shields.io/badge/Java-17-ED8B00?logo=openjdk">
  <img src="https://img.shields.io/badge/license-MIT-blue">
</p>

## 一句话介绍

> **Wetangou（"我探购"）** —— 基于 RuoYi-Vue 改造的**多商户 + 代理商 + 推客**社区团购/餐饮 SaaS。
> 一个平台账号可发展多个代理商；每个代理商向平台缴费后能开通多个**独立 appid 商户**；
> 每个商户可挂多门店、跑推客分销、配置独立微信支付与小程发布。

核心差异化：**多租户隔离（MyBatis 拦截器 + 租户上下文自动注入）、微信第三方平台代发布、推客冷静期佣金自动结算、首页 banner 后端化。**

## 架构总览

```
                  平台账号 (sys_user, userType=0)
                          │
                          ▼
                ┌──────────────────┐
                │   代理商管理     │   biz_agent / biz_agent_fee
                │  (缴费·额度)    │
                └────────┬─────────┘
                         ▼
                ┌──────────────────┐
                │   商户管理       │   biz_merchant (一户一 appid)
                │  (微信·支付)    │
                └────────┬─────────┘
                         ▼
                ┌──────────────────┐
                │   门店 · 商品    │   biz_store / biz_product
                │   订单 · 预约    │   biz_order / biz_booking
                └────────┬─────────┘
                         ▼
                ┌──────────────────┐
                │   会员 · 推客    │   biz_member / biz_distributor
                │   佣金 · 提现    │   biz_commission / biz_withdraw
                └──────────────────┘
```

**租户隔离**两层叠加：
- **组织权限**：`sys_dept` 三层（平台 → 代理商部门 → 商户部门），复用 RuoYi 部门数据权限
- **业务隔离**：业务表 `merchant_id` 字段 + MyBatis 拦截器自动追加条件（**无需逐个 Mapper 改 XML**）

## 技术栈

| 层 | 选型 |
|---|---|
| 后端 | Spring Boot **4.0.6** / Spring Security / MyBatis / Redis / Quartz / JDK 17 |
| 数据库 | MySQL 8 + utf8mb4 |
| 工具 | tools.jackson 3.x（替代 jackson-databind）/ fastjson2 / Hutool / Lombok |
| 前端 | Vue **2.7** + Element UI + Vuex + Vue Router 3 + Axios |
| 小程序 | 微信原生（**miniprogram7** 主版本，miniprogram6 已废弃） |
| 支付 | 微信支付 V3（按 merchantId 取商户号/证书） |
| 小程序代发布 | 微信开放平台第三方平台（`component_verify_ticket` + `ext.json` 注入） |

## 核心特性

### 1. 多租户隔离（MyBatis 拦截器自动追加 `merchant_id`）
- 平台账号不加条件；代理商 `in (名下商户)`；商户 `= ?`；平台共享表 `in (0, ?)`
- 写侧 `TenantInsertInterceptor` 强制覆盖 merchantId，防越权写入
- `sys_*` / `biz_agent*` / `biz_merchant*` 等登记表自动跳过（`@IgnoreTenant`）
- 后台 + 小程序两套上下文：`LoginUser.tenantContext` / `MemberToken.merchantId`
- 小程序匿名接口靠 `X-App-Id` 头 → `biz_merchant` 反查落地

### 2. 微信第三方平台代发布
- 平台统一收 `component_verify_ticket`，10 分钟缓存
- 商户扫码授权拿 `authorizer_refresh_token`（加密存储）
- 全流程留痕 `biz_mp_release`：commit → 体验版 → 提审 → 发布 → 回退
- `ext.json` 后端按商户自动生成（注入 appid / baseUrl / merchantId / merchantName）
- 平台参数集中在「小程序平台配置」页维护（`wx.open.*` 7 个 key）

### 3. 微信支付 V3 按商户路由
- `WxPayService` 由单例改为按 `merchantId` 取 `mchId / apiV3Key / certPath`
- 回调 `/api/wxpay/notify` 通过 `attach` 或 `out_trade_no→merchant_id` 回查路由
- 商户可选 `pay_mode`：0 自有商户号（无二清）/ 1 平台统收（待资质评估）

### 4. 推客分销 + 冷静期佣金自动结算
- 推客 `frozenAmount` / `availableAmount` 双账户
- 佣金产生后入冻结，冷静期（默认 7 天，规则可配）到期 Quartz 自动结算
- `SettleCommissionTask.ryNoParams()`，每天 03:00 触发，结算 `status 0→1` 并写 `settle_time`

### 5. 首页 banner 后端化
- 平台/商户双层配置：`merchant_id=0` 全平台可见，`merchant_id=N` 指定商户可见
- 后台管理页 `biz/banner`（CRUD + 上下线时间窗）
- 小程序匿名接口 `GET /api/banner/list?position=home&merchantId=...`
- 接入：优先后端 banner，门店没配时回退到 `storeAlbum`

### 6. 全链路数据脱敏
- `tools.jackson` 3.x `@Sensitive` 注解替代手写 `***` 脱敏
- 5 个核心 domain（Member / MerchantUser / StoreUser / Distributor / MpRelease）phone 字段激活
- 客服/门店电话等展示字段同样脱敏
- 管理员看明文（`@Sensitive(desensitization=SensitiveEnum.ADMIN)`）

### 7. 19 个业务页统一加「商户」筛选
- `BizSelect` 组件封装 8 类下拉（merchant / agent / store / distributor / member ...），`pageSize=100` 避免截断
- 列表页用 `v-if="showMerchantFilter"` 自动隐藏（商户账号免筛）
- Mapper 自动追加 `merchant_id = #{merchantId}`（含平台共享表的 `in` 条件）

## 模块结构

```
dytuangou/
├── ruoyi-admin/         # 启动入口 + 静态资源
├── ruoyi-framework/     # 安全、租户拦截器、Token 过滤器、WebMvc
├── ruoyi-system/        # 业务核心：biz_* domain / service / mapper / controller
├── ruoyi-quartz/        # 定时任务（佣金冷静期结算 + 通用 Job）
├── ruoyi-common/        # 通用工具 + TenantContext + 注解
├── ruoyi-generator/     # 代码生成器
├── ruoyi-ui/            # Vue 2 后台 (ruoyi-ui/src/views/biz/*)
├── miniprogram7/        # 微信小程序主版本（miniprogram6 已废弃）
├── sql/                 # 建表脚本（按顺序执行，幂等）
└── doc/                 # 设计方案 + 验证记录 + API 文档
```

## 快速开始

### 1. 初始化数据库

```bash
mysql -uroot -p ry-vue < sql/ry_20260417.sql          # RuoYi 基础
mysql -uroot -p ry-vue < sql/biz_tables.sql           # 业务表
mysql -uroot -p ry-vue < sql/biz_tenant_tables.sql    # 租户表
mysql -uroot -p ry-vue < sql/biz_tenant_upgrade.sql   # 存量表加 merchant_id
mysql -uroot -p ry-vue < sql/biz_tenant_menu.sql      # 租户管理菜单
mysql -uroot -p ry-vue < sql/quartz.sql               # 定时任务
mysql -uroot -p ry-vue < sql/biz_banner.sql           # 首页 banner
mysql -uroot -p ry-vue < sql/biz_commission_settle_job.sql  # 佣金冷静期 Job
```

### 2. 启动后端

```bash
mvn clean package -DskipTests
java -jar ruoyi-admin/target/ruoyi-admin.jar
# 默认端口 8080，账号 admin/admin123
```

### 3. 启动后台

```bash
cd ruoyi-ui && npm install && npm run dev
# 访问 http://localhost:80
```

### 4. 跑小程序

用微信开发者工具导入 `miniprogram7/`，appid 在 `utils/config.js` 自取。

## 已交付（plan 11/11 ✅）

| # | 模块 | 状态 |
|---|---|---|
| 1 | 门店端操作鉴权（order/verify、bill/confirm、booking/cancel） | ✅ |
| 2 | 关闭 mock 兜底（生产环境） | ✅ |
| 3 | datetime 字段序列化精度修复（后端+前端） | ✅ |
| 4 | 推客粉丝邀请机制（invite_by + 海报页） | ✅ |
| 5 | 19 个业务页加「商户」筛选列 | ✅ |
| 6 | 手机号加密数据后端解密（@Sensitive 全链路脱敏） | ✅ |
| 7 | WxPayService 按商户取支付凭证 + 回调路由 | ✅ |
| 8 | 微信第三方平台代发布真实接入 | ✅ |
| 9 | sys_user ↔ 业务用户表身份回填 | ✅ |
| 10 | 佣金冷静期自动结算定时任务 | ✅ |
| 11 | 首页 banner 后端化 + 文档同步 | ✅ |

详见 `doc/多商户与代理商改造方案.md`。

## 已知边界（下一轮迭代）

- 佣金结算未联动推客 `frozenAmount` ↔ `availableAmount`（commission.status 0→1 时未扣减冻结额）
- Quartz 任务失败未配置告警（仅写 `sys_job_log`）
- Banner 未做 `vip` 等级加权排序缓存
- 登录入口按 `userType` 路由分流未做（代理商/商户/平台三入口）
- 微信支付模式 1（平台统收分账）待资质评估后接入

## 文档索引

- `doc/多商户与代理商改造方案.md` —— 架构 + 改造细节 + 验证记录
- `doc/PRD.md` —— 产品需求
- `doc/小程序API文档.md` —— 小程序 `/api/**` 接口契约
- `doc/页面-文件-路由映射.md` —— 后台菜单 ↔ 视图 ↔ 接口 三方映射
- `AGENTS.md` —— 仓库开发规约 + 上下文交接

## License

基于 [RuoYi-Vue](https://gitee.com/y_project/RuoYi-Vue) v3.9.2 改造，二次开发用于多商户团购 SaaS。
原 RuoYi 遵循 MIT 协议；本仓库同样以 MIT 开源。
