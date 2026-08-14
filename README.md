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
> 每个商户可挂多门店、跑推客分销、配置独立微信支付与小程序代发布。

核心差异化：**多租户隔离（MyBatis 拦截器自动注入 merchant_id）、微信第三方平台代发布、推客冷静期佣金自动结算、首页 banner 后端化、全链路手机号脱敏。**

---

## 一、角色与租户模型

```
            ┌──────────────────────────────────────────┐
            │            平台账号 (admin)              │  sys_user.user_type=0
            │  - 维护全平台代理商 / 商户 / 微信参数      │
            │  - 财务报表 / 全局统计                     │
            └─────────────────┬────────────────────────┘
                              ▼
            ┌──────────────────────────────────────────┐
            │   代理商 (Agent)                          │  sys_user.user_type=1
            │  - 向平台缴费换取「商户开通额度」            │  biz_agent / biz_agent_fee
            │  - 自主发展商户、自行收费、查看名下商户数据   │
            └─────────────────┬────────────────────────┘
                              ▼
            ┌──────────────────────────────────────────┐
            │   商户 (Merchant)                         │  sys_user.user_type=2
            │  - 一户一 appid、配置微信支付 / 小程序代发布 │  biz_merchant / biz_merchant_fee
            │  - 多门店、多商品、多会员、多推客             │
            └─────────────────┬────────────────────────┘
                              ▼
            ┌──────────────────────────────────────────┐
            │   门店 (Store) · 会员 · 推客 (C 端)       │  biz_store / biz_member
            │  - 顾客扫码买单 / 预约 / 核销 / 推广       │  biz_distributor
            └──────────────────────────────────────────┘
```

| 角色 | 登录入口 | 看到的数据 |
|---|---|---|
| 平台 | `/login`（全平台 admin） | 全部代理商/商户/订单/财务 |
| 代理商 | 同上，但 `userType=1` | 仅**名下商户**的订单/会员/财务 |
| 商户 | 同上，但 `userType=2` | 仅**本商户**的门店/订单/会员/推客 |
| 顾客 | **微信小程序** | 当前商户 appid 下的门店/商品/预约/订单 |

数据隔离由 `TenantSqlInterceptor`（MyBatis 拦截器）按 `LoginUser.tenantContext` 自动追加 `merchant_id` 条件，**业务代码无需感知**。

---

## 二、小程序端业务（C 端，miniprogram7）

> 5 个 TabBar：首页 / 贴图 / 预约 / 我的 / 商城

### 2.1 登录与会话

```
wx.login → code → POST /api/auth/login
                    ├─ 后端 code2Session 拿 openid
                    ├─ 按当前 appid → biz_merchant 拿 merchantId
                    ├─ (openid, merchantId) upsert biz_member
                    └─ 返回 JWT，载荷含 memberId / merchantId / openid
```

请求头**统一带 `X-App-Id`**，拦截器据此落租户上下文；登录 token 由 `MemberAuthInterceptor` 还原到 `TenantContextHolder`。

### 2.2 首页（`pages/home/index`）

- **Banner 轮播**：优先 `GET /api/banner/list?position=home&merchantId=...`，门店没配时回退到 `biz_store_album` 兜底图
- **门店头部信息**：`app.pickNearestStore()` 按距离/缓存取最近门店，展示地址、电话、距离
- **商品瀑布流**：`GET /api/product/list` 拉本商户上架商品，按分类分组
- **快捷入口**：买单 / 预约 / 门店位置 / 客服电话
- **Tab 切换**：pickup（到店自提）/ delivery（配送，参数预留）

### 2.3 团购下单流程

```
商品详情 (pages/goods/detail)
    └─→ 提交订单 (pages/order/submit)
            ├─ 选门店（默认当前最近门店）
            ├─ 选数量 → 实时计算金额
            ├─ 填姓名/手机
            └─ POST /api/order  创建订单（status=0 待支付）
                    └─→ 支付 (复用 /pages/pay)
                            ├─ 调起微信支付（V3，按 merchantId 取支付参数）
                            └─ 成功 → 跳订单详情
                                    └─→ 核销码（到店扫码 / 店员输码）
                                            └─ POST /api/order/verify
                                                    └─ status 0→1→2
```

订单状态机：`0待支付 → 1待使用 → 2已核销`，`3已取消`，`4已退款`。`/pages/order/list` 5 个 tab 对应这 5 个状态。

### 2.4 买单流程（`pages/pay`）

门店现场买单，比团购订单多一个**店员确认金额**环节：

```
1. 选门店 → 计算金额
2. 选代金券（POST /api/voucher/available，按 merchantId+memberId 过滤）
3. 提交买单（POST /api/bill）→ 拿到 billId
4. 轮询 /api/bill/{id}：店员在后台「买单记录」点确认
5. 确认后调起微信支付 → 支付完成
```

轮询间隔 2s、上限 60 次；超时后用户可手动重试。

### 2.5 预约流程（`pages/booking`）

```
创建预约 (pages/booking/create)
   ├─ 选门店 / 选日期（未来 7 天）
   ├─ 选时段（day/night，biz_booking_slot_config 配置）
   ├─ 填联系人 / 人数 / 备注
   └─ POST /api/booking  status=0 待确认

后台确认 → status=1 已确认 → 顾客到店 → 核销 → status=2 已完成
                                              ↘ 后台取消 → status=3
```

`/pages/booking/list` 3 tab：待确认 / 已确认 / 已取消+已完成。

### 2.6 推客分销（`pages/promoter`）

```
顾客点「成为推客」→ 阅读并同意协议 → 申请
   └─ POST /api/promoter/join  → biz_distributor 落库

推客中心（pages/promoter/index）
   ├─ 账户面板：
   │     累计佣金 / 累计提现 / 可提现 / 提现中 / 冻结
   │     ├─ 可提现 (available) ← 冷静期到期的 commission
   │     ├─ 提现中 (withdrawing) ← 提现申请待审核
   │     └─ 冻结 (frozen) ← 冷静期内的 commission
   ├─ 订单 tab：推客带来的订单 + 佣金明细
   └─ 粉丝 tab：邀请的粉丝（含直接/间接），按 invite_by 递归

邀请海报（pages/promoter/poster）
   └─ GET /api/promoter/qrcode → 后端生成小程序码（scene=memberId）
         └─ 用户长按识别 → 落地页带 invite_by=memberId

提现（pages/promoter/withdraw）
   ├─ 三种类型：微信零钱 / 支付宝 / 银行卡
   ├─ 申请扣减 available，提现到 withdrawing
   └─ 后台审核：驳回退回 available，通过则人工转账并改 status=1

记录（pages/promoter/records）：提现 + 佣金历史
```

**冷静期结算**：佣金产生时 `commission.status=0` + 推客 `frozenAmount += amount`；
每天 03:00 Quartz Job 扫描 `create_time + settle_days <= NOW` 的 commission，
批量 `status=1` 并扣减 `frozenAmount`、加到 `availableAmount`。

### 2.7 个人中心（`pages/mine`）

- 头像昵称（首次登录授权获取）
- 手机号（`getPhoneNumber` → 后端 code2phone）
- 我的订单 / 预约 / 代金券
- 邀请成为推客入口
- 协议查看（用户协议 / 隐私政策）

### 2.8 协议页（`pages/agreement`）

`/user` 用户协议、`/privacy` 隐私政策，由后台 `biz_agreement` 维护（平台级共享表 `merchant_id=0`，商户可另建自己的）。

---

## 三、后台管理业务（B 端，ruoyi-ui）

> 7 大菜单分组：团购运营 / 租户管理 / 系统管理 / 监控管理 / 工具管理 / ……

### 3.1 团购运营（5 大组）

#### ① 门店商品

| 菜单 | 主要功能 | 关键字段 |
|---|---|---|
| 门店管理 | 增删改、批量导入、地图标注 | name/lat/lng/address/servicePhone/businessHours |
| 商品分类 | 树形分类、排序、图标 | parent_id / icon / sort |
| 商品管理 | 多门店 SKU、价格、库存、上下架 | price/stock/cover/storeIds[] |
| 相册管理 | 门店相册（环境/菜品/门面），首页兜底图 | storeId / albumType / imageUrl / sort |
| 协议管理 | 用户协议/隐私政策的版本与生效时间 | type / version / activeFrom / activeTo |

#### ② 交易订单

| 菜单 | 主要功能 |
|---|---|
| 团购订单 | 订单全生命周期：查/改/核销/退款 |
| 买单记录 | 顾客现场买单流水，店员点确认才可支付 |
| 预约管理 | 预约场次模板、确认/取消/完成 |
| 预约明细 | 多人预约的成员行 |

**核销（订单）**：订单详情 → 输入/扫码核销码 → 状态 0/1 → 2。
**核销（买单）**：买单详情 → 店员点「确认」 → 触发小程序端轮询结果 → 顾客发起支付。

#### ③ 会员体系

| 菜单 | 主要功能 |
|---|---|
| 会员管理 | C 端会员列表、来源、订单汇总 |
| 会员用户 | 后台账号-会员绑定关系（@Sensitive 脱敏手机号） |
| 代金券管理 | 满减/折扣券、发放/核销/过期 |
| 会员账户 | 会员钱包余额、积分 |

#### ④ 推客分销

| 菜单 | 主要功能 |
|---|---|
| 推客管理 | 推客列表、邀请关系树、佣金总额 |
| 佣金规则 | 按门店/分类/商品/推客等级配佣金率 + 冷静期天数 |
| 佣金记录 | 推客带来的订单佣金明细（status 0/1/2） |
| 提现申请 | 待审核的提现（审核通过/驳回） |
| 提现记录 | 已完成的提现流水 |

#### ⑤ 平台配置

| 菜单 | 主要功能 |
|---|---|
| 微信配置 | 平台默认商户的 appid/secret 兜底 |
| 小程序平台配置 | `wx.open.*` 7 个第三方平台参数 |
| 首页 Banner | 后台 CRUD banner，merchantId=0 全平台、>0 指定商户 |

### 3.2 租户管理（核心差异化）

| 菜单 | 主要功能 |
|---|---|
| 代理商管理 | 新增/编辑/续费/禁用代理商；额度用量进度条、到期高亮 |
| 代理商缴费 | 登记缴费单（待确认 → 确认），自动累计金额 + 延到期 |
| 商户管理 | 基础信息 + 独立「微信配置」弹窗（appid/secret/支付方式） |
| 商户收费 | 平台向商户开服务费单 + 确认收款（自动同步 service_expire） |
| 小程序代发布 | 选商户 → 提版本 → commit → 体验版 → 提审 → 发布/回退 |

**小程序代发布流程**：

```
1. 商户先扫码授权（authorize URL 由后端按 componentAppId + preauthcode 拼）
2. 平台选商户 + 选版本 → 自动生成 ext.json（注入 appid / baseUrl / merchantId）
3. 提交体验版：POST 微信 → 返回体验码
4. 提审：上传版本号 + 备注 → 微信返回 auditid
5. 撤回：未审核前可撤回
6. 发布：审核通过后调用 release → 全网生效
7. 回退：已发布版本可回退到上一个线上版

全流程留痕 biz_mp_release，状态机：draft → committed → trial → audit → released / rollback
```

### 3.3 19 个业务页统一加「商户」筛选

`BizSelect` 组件封装 8 类下拉，列表页用 `v-if="showMerchantFilter"` 控制可见性：

```vue
<el-form-item label="商户" prop="merchantId" v-if="showMerchantFilter">
  <biz-select v-model="queryParams.merchantId" type="merchant" />
</el-form-item>
```

`isShowMerchantFilter()` 按 `TenantContext.getUserType()=='2'` 自动隐藏，避免商户账号看见自己以外的数据。
Mapper 同步加 `merchant_id = #{merchantId}`，写操作由 `TenantInsertInterceptor` 强制覆盖。

---

## 四、核心功能技术细节

### 4.1 多租户隔离（MyBatis 拦截器自动追加）

```java
// 平台账号不加条件；代理商 in (名下商户)；商户 = ?
// 平台级共享表用 in (0, merchantId)
public class TenantSqlInterceptor implements Interceptor {
    Object intercept(Invocation inv) {
        MappedStatement ms = (MappedStatement) inv.getArgs()[0];
        // 解析 SQL，识别 biz_* 强隔离表 + 共享表
        // 改写 SQL 追加 WHERE merchant_id ...
        return inv.proceed();
    }
}
```

写侧 `TenantInsertInterceptor`：**强制覆盖** `merchantId`（防前端伪造参数向他人租户写数据）。

### 4.2 微信支付 V3 按商户路由

```java
public interface WxPayService {
    UnifiedOrderResponse createOrder(Long merchantId, OrderRequest req);
    PayNotify parseNotify(Long merchantId, String body, String signature);
}
```

`/api/wxpay/notify` 收到回调时：
1. 验签（按**回调时路由到的 merchantId** 取证书）
2. `out_trade_no` → 查订单 → 取 `merchantId`（兼容 `attach` 字段直接传）
3. 二次验签（按**真实商户**再验一次）
4. 改订单状态、发核销码

### 4.3 佣金冷静期自动结算

```sql
-- biz_commission.status: 0待结算 1已结算 2已失效
-- biz_commission_rule.settle_days: 冷静期（默认 7）
```

Quartz Job 每天 03:00：
```sql
UPDATE biz_commission
SET status='1', settle_time=NOW()
WHERE status='0'
  AND create_time + settle_days <= NOW();
```

同步：推客 `frozenAmount -= SUM(amount)`、`availableAmount += SUM(amount)`（`TODO：当前未联动 Distributor 余额，下一轮补`）。

### 4.4 首页 banner 后端化

```
小程序：
  GET /api/banner/list?position=home&merchantId=0
  → 优先返回本商户的 + 平台级（merchant_id=0）的 banner，按 sort 升序
  → 空时回退 storeAlbum
  → 点击跳 linkUrl（小程序路径或外链）

后台：
  GET  /biz/banner/list    分页
  POST /biz/banner         新增（含生效/失效时间窗）
  PUT  /biz/banner         修改
  DEL  /biz/banner/{ids}   删除
```

### 4.5 全链路手机号脱敏

`@Sensitive(desensitization=SensitiveEnum.PHONE)` 注解在 domain 字段上，
Jackson 3 序列化时按当前用户角色判断：
- 管理员（userType=0）看明文
- 其他角色看 `138****1234`

已覆盖：Member / MerchantUser / StoreUser / Distributor / MpRelease + 客服/门店电话展示字段。

---

### 4.10 小程序商家公开信息接口（`/api/merchant/info`）

C 端小程序登录页 / 我的页 / 联系客服页需要展示商家名、Logo、客服电话、客服二维码、营业时间、简介。
匿名接口由 `ApiMerchantController` 提供：

- 请求头 `X-App-Id` 携带小程序 appid → `TenantService.getMerchantByAppid` 找到对应商户
- 缺 `X-App-Id` 或未匹配到商家**直接返回 400 "未匹配到商家"**，不静默兜底
  （多租户契约：一个 appid 对应唯一商户，忘带 header 应当立刻暴露 bug，而不是拿到别人家数据）
- 所有图片字段都过 `ImageUrlUtils.toAbsolute`，包 try/catch 防御
- `servicePhone` / `serviceQrcode` / `businessHours` / `intro` 由商家级兜底（门店未配时使用商家级）

### 4.11 Spring Boot 3.4 + Tomcat 11 错误恢复路径 ClassNotFound 修复

Spring Boot 3.4 + Tomcat 11 nested fat-jar + Java 25 在错误恢复路径上会触发
`ClassNotFoundException: org.apache.tomcat.util.buf.C2BConverter` 和
`org.apache.catalina.core.ApplicationContext$DispatchData`，导致原本 401 的请求退化为 500。
修复方式：`AuthenticationEntryPointImpl` 直接 `response.getOutputStream().write(bytes)` 写字节，
绕过 `response.getWriter()` 的 C2BConverter 转换。

---

## 五、模块结构

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

---

## 六、技术栈

| 层 | 选型 |
|---|---|
| 后端 | Spring Boot **4.0.6** / Spring Security / MyBatis / Redis / Quartz / JDK 17 |
| 数据库 | MySQL 8 + utf8mb4 |
| 工具 | tools.jackson 3.x（替代 jackson-databind）/ fastjson2 / Hutool / Lombok |
| 前端 | Vue **2.7** + Element UI + Vuex + Vue Router 3 + Axios |
| 小程序 | 微信原生（**miniprogram7** 主版本） |
| 支付 | 微信支付 V3（按 merchantId 取商户号/证书） |
| 小程序代发布 | 微信开放平台第三方平台（`component_verify_ticket` + `ext.json` 注入） |

---

## 七、快速开始

### 1. 初始化数据库（按顺序执行，全部幂等）

```bash
mysql -uroot -p ry-vue < sql/ry_20260417.sql          # RuoYi 基础
mysql -uroot -p ry-vue < sql/biz_tables.sql           # 业务表
mysql -uroot -p ry-vue < sql/biz_menu_reorganization.sql  # 菜单重组
mysql -uroot -p ry-vue < sql/biz_tenant_tables.sql    # 租户表
mysql -uroot -p ry-vue < sql/biz_tenant_upgrade.sql   # 存量表加 merchant_id
mysql -uroot -p ry-vue < sql/biz_tenant_menu.sql      # 租户管理菜单
mysql -uroot -p ry-vue < sql/biz_mpconfig_menu.sql    # 小程序平台配置菜单
mysql -uroot -p ry-vue < sql/biz_distributor_invite.sql    # 推客邀请
mysql -uroot -p ry-vue < sql/biz_booking_upgrade.sql  # 预约升级
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

### 5. JDK / 字节码版本

| 项目 | 要求 |
|---|---|
| **编译 JDK** | 17 或 25 都行（Maven 用 `--release 17` 严格按 Java 17 编译） |
| **运行 JDK** | 17 / 21 / 25 都行（产物字节码主版本号 = 61 = Java 17） |
| **本机开发** | Apple Silicon Mac 自带 Temurin 17/25 任选其一 |
| **服务器部署** | 推荐 Temurin 17 LTS（最少要 17+，但 17 是验证过的最小版本） |

**关键配置**（`pom.xml`）：

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-compiler-plugin</artifactId>
    <configuration>
        <release>17</release>   <!-- 不是 -source/-target，是 --release -->
    </configuration>
</plugin>
```

用 `--release 17` 而不是 `-source 17 -target 17` 的原因：
- `-source 17`：只允许 Java 17 语法，**API 仍按编译时 JDK 解析**
- `-target 17`：只生成 Java 17 字节码
- **`--release 17`**：三者同时约束，API 也按 Java 17 解析，避免在 JDK 25 上编译时意外引用 Java 21/25 才有的 API，部署到 JDK 17 服务器 ClassNotFound

**验证**（已跑过）：

```bash
# 1) 解压 jar 后检查所有 class 的字节码主版本号
unzip -p ruoyi-admin/target/ruoyi-admin.jar BOOT-INF/classes/com/ruoyi/RuoYiApplication.class | od -A n -t x1 -N 8 | head -1
# 期望输出包含：ca fe ba be 00 00 00 3d
# 主版本号 0x3d = 61 = Java 17

# 2) 嵌套依赖的版本抽查
# - spring-boot-4.0.6.jar: 主版本 61 ✅
# - tomcat-embed-core-11.0.21.jar: 主版本 61 ✅
# - jackson-datatype-jsr310: 主版本 52（Java 8，向下兼容）✅
```

---

## 八、已交付（plan 11/11 ✅ + 增量 5 项）

| # | 模块 | 状态 | 关键 commit |
|---|---|---|---|
| 1 | 门店端操作鉴权（order/verify、bill/confirm、booking/cancel） | ✅ | — |
| 2 | 关闭 mock 兜底（生产环境） | ✅ | — |
| 3 | datetime 字段序列化精度修复（后端 Jackson + 前端展示） | ✅ | — |
| 4 | 推客粉丝邀请机制（invite_by + scene 解析 + 海报页） | ✅ | `8639bb2d` |
| 5 | 19 个业务页加「商户」筛选列（BizSelect 公共组件） | ✅ | — |
| 6 | 手机号解密（`/biz/phone/decrypt` + 会员页「查看完整」+ 审计） | ✅ | `f0e55e76` |
| 7 | WxPayService 按商户取支付凭证（`createJsapiOrderByMerchant` + 双入口回调路由） | ✅ | `c9e515f5` |
| 8 | 微信第三方平台真实接入（ticket 回调 + preauthcode + ext_json + commit + token 轮换） | ✅ | `2226ab92` |
| 9 | sys_user ↔ 业务用户表身份回填（`biz_merchant_user` 路由 + `TenantIdentityResolver` + `getInfo` 回传） | ✅ | — |
| 10 | 佣金冷静期 Quartz（`SettleCommissionTask` + 推客 frozenAmount/availableAmount 联动 + `settled_to_distributor` 防重） | ✅ | `80674a87` |
| 11 | 首页 banner 后端化（CRUD UI + `/api/banner/list` + 小程序首页接入） | ✅ | — |
| 12 | pom 改用 `--release 17`（产物字节码 100% Java 17 兼容，JDK 17/21/25 都能跑） | ✅ | `0416420f` |
| 13 | `/api/merchant/info` 强制 X-App-Id（缺 header 400，移除静默兜底） | ✅ | `c1f33805` |
| 14 | Spring Boot 3.4 + Tomcat 11 nested fat-jar ClassNotFound 修复（EntryPoint 改字节流） | ✅ | `49805ff5` |
| 15 | 小程序「我的」登录态从真实会员资料回填 + 推客海报页 + 商家客服兜底 | ✅ | `4209e256` |

详见 `doc/多商户与代理商改造方案.md` 与 `git log --oneline`。

---

## 九、已知边界（下一轮迭代）

- Quartz 任务失败未配置告警（仅写 `sys_job_log`，未接邮件/钉钉）
- Banner 未做 VIP 等级加权排序缓存（当前按 `sort, create_time` 排序）
- 登录入口按 `userType` 路由分流（代理商/商户/平台三入口） — 后端 `LoginUser.userType` 字段已加，前端 store + router 分流待下一轮完成（见 AGENTS.md Pending 1）
- 微信支付模式 1（平台统收分账）待资质评估后接入
- 商品配送（delivery tab）参数已预留，运力/范围规则待补
- mp release 流程 UI 已就绪（`biz/mprelease`），但真实 release 调用 `wxa/release` 依赖第三方平台授权（`biz_mp_auth.refresh_token` 落库轮换已实现）
- 小程序「员工登录」入口 + **多门店权限** 已实现：
  - 员工可关联多个门店（`biz_store_user` 多对多），登录时全部写入 token `storeIds` 集合
  - 当前激活门店写入 `LoginMember.storeId`，员工可在「我的」页一键切换
  - `MemberAuthInterceptor` 拦截所有 `@StoreStaffRequired` 端点，校验请求 storeId **属于** token storeIds 集合，否则 403
  - 切换端点 `POST /api/store/staff/switch-store` 后端 `refreshToken` 写 redis 缓存；前端调 `me` 拿到新 storeName
  - 已端到端实测：staff001 绑 100/101/200 三门店，切换 200→100 成功，跨店访问 999 拒绝

---

## 十、文档索引

- `doc/多商户与代理商改造方案.md` —— 架构 + 改造细节 + 验证记录
- `doc/PRD.md` —— 产品需求
- `doc/小程序API文档.md` —— 小程序 `/api/**` 接口契约
- `doc/页面-文件-路由映射.md` —— 后台菜单 ↔ 视图 ↔ 接口 三方映射
- `AGENTS.md` —— 仓库开发规约 + 上下文交接

---

## Smoke Test

本地手跑 C1 端点跨租户回归测试：

```bash
# 前置：后端 jar 已 build 且在 8080 跑，MySQL 有 biz_agent / biz_merchant / biz_commission 真实数据
bash .github/scripts/smoke-c1.sh
```

期望输出（3/3 通过）：

```
[A] OK: total=62.8, byMerchant=1 row
[B] OK: total=0.0, byMerchant=0 row (no cross-tenant leak)
[C] OK: no auth -> 401
C1 smoke test PASSED
```

**测试覆盖**：
- A: agentId=1（有 1 个下属商户）→ total=62.80, byMerchant 1 行
- B: agentId=999（无下属商户）→ total=0, byMerchant 0 行（**防跨租户泄漏**，对应 commit `7a0299d4`）
- C: 无 token → 401（鉴权必须）

**回归触发场景**：
- 改了 `CommissionMapper.xml` 漏掉 `merchantIdsEmpty` guard
- 改了 `BizAgentCommissionController` 漏掉 `.get('total_amount')` 驼峰对齐
- 改了 `CommissionServiceImpl` 漏 IFNULL 兜底

CI 流水线只做 `bash -n` 静态语法校验（避免 macos-14 runner 缺 docker/mysql-client 的环境问题）；**端到端 smoke 留给开发者本地手跑**。

---

## License

基于 [RuoYi-Vue](https://gitee.com/y_project/RuoYi-Vue) v3.9.2 改造，二次开发用于多商户团购 SaaS。
原 RuoYi 遵循 MIT 协议；本仓库同样以 MIT 开源。
