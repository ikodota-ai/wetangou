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

### 1. 初始化数据库（3 个 SQL 文件，2026-08-22 实测通过）

```bash
mysql -uroot -p -e "CREATE DATABASE \`ry-vue\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"

mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/ry_20260417.sql        # RuoYi 基础表
mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/quartz.sql             # 定时任务表
mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/deploy/wetuangou.sql   # 全部业务内容
```

第 3 个文件包含：业务建表 + v2 商品模型 + 代理商/会员/预约/门店 + **260 个菜单** + 字典种子。
导完最后一句会打印统计，其中 `bad_parent_should_be_0` 必须为 0。默认管理员 `admin / admin123`。

生产环境再补配置模板；演示数据仅测试环境用：

```bash
mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/deploy/sys_config_production.sql
mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/deploy/wetuangou-demo.sql   # 生产不要跑
```

> 用 Navicat 等 GUI 时：右键库 → 运行 SQL 文件，**编码选 utf-8**（选错中文乱码）。
> 顺序不能换；3 个文件都幂等（可重复跑）；**只对空库/新库执行**（脚本含 `drop table`）。
>
> `wetuangou.sql` 由 `sql/deploy/build-merged.py` 自动合并生成，**不要手改**；
> 改源脚本后重新跑生成器。等价的 shell 版本 `sql/deploy/init-all.sh` 保留备用
> （逐文件打印 OK/FAIL，排错更方便）。细节见 `sql/deploy/README.md`。

### 2. 启动后端

两种方式任选其一：

**A. 打包后跑 jar（推荐，接近生产）**

```bash
mvn clean package -DskipTests
java -jar ruoyi-admin/target/ruoyi-admin.jar
# 默认端口 8080，账号 admin/admin123
# 第一次 install 可能 BOOT-INF/lib 缺包，再跑一次 mvn install 即可
```

**B. spring-boot:run（开发态，IDE 友好，自动热加载 classes）**

```bash
mvn spring-boot:run -pl ruoyi-admin -am
# 或显式指定 profile（项目主用 druid）：
mvn spring-boot:run -pl ruoyi-admin -am -Dspring-boot.run.profiles=druid
```

> macOS 后台守护写法（PTY 关闭时 SIGHUP 不会杀进程）：
> ```bash
> nohup java -jar ruoyi-admin/target/ruoyi-admin.jar > /tmp/ruoyi.log 2>&1 &|
> disown
> ```

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

## 八、已交付

> 完整逐条记录在 `AGENTS.md`（按 session 归档）与 `git log --oneline`；本章按**版本里程碑**归纳，
> 每行末尾标注可在 AGENTS.md / `doc/` 中检索的关键词。

### v2.0 ~ v2.4 基础平台（多租户 + 微信 + 分销）

| # | 模块 | 关键 commit |
|---|---|---|
| 1 | 多租户隔离：MyBatis 拦截器自动注入 `merchant_id` + `TenantFilterHelper` 12 个 Service 切片 | `5f17bd5a` 起 |
| 2 | sys_user ↔ 业务用户表身份回填（`biz_merchant_user` + `TenantIdentityResolver` + `getInfo` 回传） | `530c5a3b` |
| 3 | 登录入口按 userType 分流（平台 / 代理商 / 商户三 tab + 路由与菜单过滤） | `fade76ff` |
| 4 | 微信支付 V3 按商户路由（`createJsapiOrderByMerchant` + 双入口回调路由） | `c9e515f5` |
| 5 | 微信第三方平台接入（ticket 回调 + preauthcode + ext_json + commit + token 轮换） | `2226ab92` |
| 6 | 推客分销：邀请（`invite_by` + scene 解析）+ 海报页 + 太阳码文件缓存 | `8639bb2d` `27e4a0b5` |
| 7 | 佣金冷静期 Quartz（`SettleCommissionTask` + frozen/available 联动 + 防重结算） | `80674a87` `2701f1e7` |
| 8 | 代理商佣金概览（C1，含跨租户空集 guard `and 1=0`） | `7a0299d4` |
| 9 | 首页 banner 后端化（CRUD + `/api/banner/list` + 小程序接入） | — |
| 10 | 全链路手机号脱敏 + `/biz/phone/decrypt` 审计解密 | `f0e55e76` |
| 11 | 19 个业务页统一「商户」筛选（`BizSelect` 公共组件 + require.context 自动注册） | `11cca693` |
| 12 | pom 改 `--release 17`（产物字节码 100% Java 17，JDK 17/21/25 均可运行） | `0416420f` |
| 13 | Spring Boot 3.4 + Tomcat 11 nested fat-jar ClassNotFound 修复 | `49805ff5` |
| 14 | `/api/merchant/info` 强制 `X-App-Id`（缺 header 400，移除静默兜底） | `c1f33805` |
| 15 | v2 抖音来客商品模型：`biz_product_type` 11 种字典 + 子品 / 子品组 + 商户员工邀请 | `4e071924` 起 13 commit |

### v2.5 角色权限模型（2026-08-15）

- **5 角色**：`PLATFORM / AGENT / OWNER / MANAGER / STAFF`，`@RequireRole(includeHigher=true)` + `RoleAuthInterceptor`（`cb7b1a8c`）
- **三层身份叠加**：同一 openid 可同时是会员 / 推客 / 员工，`@MemberRequired` `@DistributorRequired` 分别拦截（`243a8c1c` `e172ef7c`）
- **平台 dashboard**：`ApiPlatformController` 跨店订单流水 + 员工总览（`6524f6d3` `73eb1a4c`）
- **代理商 dashboard**：`ApiAgentController` 4 端点 + `biz_agent.user_id` 绑定（`928f3123`）
- **小程序 UI 角色化**：`utils/role.js` + 商家端首页卡片/入口按角色显隐（`410cd9a4`）
- 决策记录：**不实装** `sys_biz_role_menu`——5 角色只管小程序 API 鉴权，PC 后台继续用 RuoYi 原生 `sys_role_menu`（V6-5）

### v2.6 商品类型化 + 代发布 + 存储（2026-08-16 ~ 08-17）

- **商品表瘦身**：主表 + `biz_product_ext` 1:1 扩展表（13 列类型差异 + 公共 2 列）（`f99942c0`）
- **类型必填校验**：`ProductValidator` 按 `typeCode` 校验必填字段；`ApiOrderServiceImpl.placeOrder` 按类型限制下单（`9a7b1c22`）
- **C 端详情页重构**：去 notice 富文本依赖，购买须知按创建字段结构化渲染 + 划线价/折扣/门店动态化（`7fe6e6cc` `69c36746`）
- **PC 抖音来客风格创建页** + 小程序商家端商品列表 / 搭配子页（`83bf4493` `34b41bad`）
- **核销直达**：`GET /api/order/{orderId}/scheme` 微信扫一扫直达核销（`8773f8cf` `9008ea19`）
- **储值卡 STORED_CARD 闭环**：表 + service + 核销扣减（`3be1235d`）；核销成功订阅消息（`a8b41b95`）
- **员工工作流（V6）**：邀请 scene 免扫直达 + `getPhoneNumberByCode` 回填手机号 + 待审核 `status=3` + PC 审核端点（`848cb6a4`）
- **多商户代发布**：`ext.json` 注入 `baseUrl / merchantId / appid`（`a1961ec7`）
- **附件存储 5 云适配**：`StorageFactory` → local / oss / minio / qiniu / cos / s3（`2bee05a6`）

### v2.6.1 / v2.6.2 登录与核销闭环（2026-08-17）

- **v2.6.1**：合并登录入口 + 订单太阳码 + 员工扫码核销端到端闭环（`72d2789a`）
- **v2.6.2**：登录改 **openid 优先身份识别**（一次授权自动判定会员/推客/员工），其他方式折叠（`d5956bdf`）

### 上线收口（2026-08-20）

- **3 个真实上线阻断缺陷**（`3b8cc0ca`）：顾客端 14 处 `@RequireRole` 误伤 / `ProductMapper.updateProduct` 引用已迁出字段导致支付扣库存必崩 / `/api/distributor/agent/summary` 恒 403 dead-end
- **配置参数化**（`6f087df8`）：`aliyun-oss` 等 profile 也强制关 mock 支付、JWT/数据源/Druid 口令走环境变量
- **smoke 基线 40/62 → 62/62**（`a4245638`）：新增 `.github/scripts/lib/smoke-fixture.sh` 共享 fixture 库，27 个脚本接入前置
- **部署自检**（`42747abe`）：`doc/上线配置清单-2026-08-20.md` + `.github/scripts/preflight-prod.sh` 8 项只读检查

### 全新库初始化收口（2026-08-21）

用一个空库把 `sql/` 全部脚本重跑一遍，暴露并修掉 **11 个部署期缺陷**（详见 `AGENTS.md` 同名章节）：

- **2 个上线阻断**：`biz_product_ext` 表**从来没有建表脚本**（`f99942c0` 漏交），商品列表页必 500；
  `biz_merchant` 建表缺 `business_hours / service_hours / service_phone / service_qrcode / intro` 5 列，
  但 `MerchantMapper` 在查它们 → 商户管理页必 500
- **3 个 `USE ry-vue;` 硬编码**：`use` 是客户端指令，会无视命令行指定的库直接切到 `ry-vue`
  —— 对着测试库执行却写进生产库
- **6 个非幂等 / 语法问题**：MySQL 5.7 的 `ERROR 1093`（DELETE 子查询引用目标表）、
  `LIMIT 1 LIMIT 1`、`INSERT` 列数与 `SELECT` 值数不符、漏分号被行尾注释吞掉、
  裸 `ALTER ADD COLUMN` 重复跑报 1060、`biz_booking_upgrade` 会 `drop` 掉真实报名数据表
- **产出** `sql/deploy/init-all.sh`：固化实测顺序，全新库 → 全绿 `FAILED=0`，第二遍重跑仍全绿

同库端到端复验（后端指向新库，8081 端口）：后台 20 个列表接口 + `/getInfo` 全 200，
小程序端登录 / 商品 / 门店 / 订单 / 会员全 200，**下单 → prepay → 生成核销码链路跑通**。

---

## 九、已知边界（下一轮迭代）

> 登录分流、员工多门店、mp release UI 等曾列在本章的项目**均已实装**（见第八章）。
> 本章只保留**当前真实未做**的部分。

**功能未做**

- Quartz 任务失败未配置告警（仅写 `sys_job_log`，未接邮件/钉钉）
- Banner 未做 VIP 等级加权排序缓存（当前按 `sort, create_time` 排序）
- 微信支付模式 1（平台统收分账）待资质评估后接入
- 商品配送（delivery tab）参数已预留，运力/范围规则待补
- **订单退款**：`biz_order` status 0~4 无 refund 端点，佣金退款联动（`commission.status=2` +
  已结算则 `available -= amount`）随之未实装
- 小程序商家端「创建商品」页缺图片上传控件（需新增 `ApiCommonController` 绕过 PC 端 `@PreAuthorize`）
- `FastDfsStorageAdapter` 是占位实现（pom 未引依赖，方法体直接抛异常）；用 OSS/S3 即可，不影响

**依赖外部条件**

- mp release 流程 UI + 后端 11 端点已就绪，但真实 `wxa/release` 调用依赖微信第三方平台授权
  （`biz_mp_auth.refresh_token` 落库轮换已实现，缺的是平台资质与 7 项 `wx.open.*` 配置）
- 太阳码（`getWxaCodeUnlimited`）需小程序**已发布**，未发布时返回 `errcode 40066`；
  本地联调走 `wx.miniapp.mockEnabled=true`

**测试与工程**

- CI 用 `runs-on: macos-14`，端到端 smoke 只做 `bash -n` 静态校验（runner 缺 docker/mysql-client）；
  真实 62 个 smoke 需本地手跑，建议后续迁到 `ubuntu-latest` + service container
- `sql/` 下有 60+ 脚本，其中 `biz_merchant_v2` / `biz_merchant_v2_simple` / `biz_merchant_v2_step1`、
  `biz_product_model_v2` / `_safe` / `_step2a`、`biz_agent_store_quota` / `_hotfix` 属于同一改造的多个变体
  （当时为绕开 Navicat 不支持 `DELIMITER` 等问题拆出来的）。`sql/deploy/init-all.sh` 已固化实测可用的那一组，
  其余变体保留备查，但**不要**混着跑

---

## 十、文档索引

**必读**

- `AGENTS.md` —— 仓库开发规约 + 逐 session 交付记录（**最权威的实现细节来源**）
- `doc/上线配置清单-2026-08-20.md` —— 上线前必改项清单（配合 `preflight-prod.sh`）
- `doc/上线数据迁移方案-2026-08-22.md` —— 本地库 → 服务器的两种迁移方案 + 清洗 SQL
- `sql/deploy/README.md` —— 部署 SQL 导入指南（3 个文件 + Navicat 操作 + 生成方式）
- `doc/部署上线指南.md` —— 服务器部署步骤
- `doc/多商户与代理商改造方案.md` —— 架构 + 改造细节 + 验证记录

**产品与接口**

- `doc/PRD.md` —— 产品需求
- `doc/PRD-抖音来客商品模型.md` —— 11 种商品类型模型（v2 商品改造依据）
- `doc/小程序API文档.md` —— 小程序 `/api/**` 接口契约
- `doc/页面-文件-路由映射.md` —— 后台菜单 ↔ 视图 ↔ 接口 三方映射
- `doc/不同身份权限与菜单评估.md` —— 5 角色 / 3 角色权限边界

**运维与专题**

- `doc/存储适配指南.md` —— local / oss / minio / qiniu / cos / s3 切换
- `doc/小程序发布-商家自助操作手册.md` —— 第三方平台代发布流程
- `doc/操作手册.md` / `doc/操作手册-提现审核.md` —— 运营侧操作说明
- `doc/手机热点调试指南.md` / `doc/真机验证-2026-08-14.md` —— 真机联调
- `doc/` 下另有 40+ 份 `C*/E*/V*` smoke 与审计记录，按编号对应 `.github/scripts/smoke-*.sh`

---

## 测试与回归基线

当前基线（2026-08-20 实跑，全绿）：

| 层次 | 数量 | 命令 |
|---|---|---|
| 端到端 smoke（bash + curl + MySQL 断言） | **62 / 62** | `for f in .github/scripts/smoke-*.sh; do bash "$f"; done` |
| 后端 JUnit（真 MyBatis + 真 MySQL，0 mock） | **10 / 10** | `mvn test -pl ruoyi-system` |
| 小程序 vitest（纯函数单测） | **66 / 66** | `cd miniprogram7 && npx vitest run` |
| MyBatis XML 静态检查（52 个 xml） | 0 err | `bash .github/scripts/lint-mybatis.sh` |
| smoke 脚本静态检查（62 个脚本） | 0 fail | `bash .github/scripts/lint-smoke.sh` |
| SQL 种子幂等检查（21 个脚本） | 0 fail | `bash .github/scripts/lint-sql-seed.sh` |

### 跑 smoke 的前置条件

1. 后端 jar 在 `127.0.0.1:8080` 运行（profile 建议 `druid`，mock 支付开着更好联调）
2. MySQL 可连：脚本默认用 `/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue`，
   可用环境变量覆盖：`FX_MYSQL` / `FX_DB` / `FX_H` / `FX_APPID`
3. 已执行 `sql/` 下种子脚本（全部幂等，可重复跑）

```bash
# 单个
bash .github/scripts/smoke-c1.sh

# 全量串行（约 2~4 分钟）
: > /tmp/smoke-all.txt
for f in .github/scripts/smoke-*.sh; do
  k=$(basename "$f" .sh)
  if bash "$f" > "/tmp/sm-$k.log" 2>&1; then echo "$k PASS"; else echo "$k FAIL"; fi
done | tee /tmp/smoke-all.txt
grep -c PASS /tmp/smoke-all.txt
```

> macOS 上**没有 `timeout` 命令**，不要给 smoke 外面套 `timeout`，否则全部假 FAIL。

### 共享 fixture 库（`.github/scripts/lib/smoke-fixture.sh`）

62 个 smoke 串行跑时曾有 22 个 FAIL，逐个定位后**全部是 fixture 漂移**（前序脚本改了共享数据），
0 个产品缺陷。因此抽出共享前置库，写新 smoke 时优先 `source` 复用：

```bash
source "$(dirname "$0")/lib/smoke-fixture.sh"

fx_reset_staff_pwd            # 把 staff001 密码重置回 admin123（历史脚本会改密码）
fx_fix_staff_user_type        # staff001 的 user_type 修回 '02'（商户员工）
fx_ensure_product_stock 1000  # 商品库存兜底补足（历史下单会耗尽）
fx_pin_member_openid          # 固定测试会员 openid（c53 会改它）
fx_clear_member_openid        # 腾空 openid 占用者（uk_merchant_openid 唯一键）
fx_ensure_mock_on             # 确保 mock 支付/微信开关为 true

TOK=$(fx_login_owner)         # OWNER 角色 token（owner_c43）
TOK=$(fx_login_admin)         # 平台 admin token
TOK=$(fx_login_member)        # C 端会员 token
```

写 smoke 时踩过的坑（避免重复）：

- `biz_member.openid` 是 **NOT NULL + 唯一键** `uk_merchant_openid(merchant_id, openid)`：
  置 NULL 报 1048，统一置 `''` 报 1062，必须先腾空占用者（用 `fx_clear_member_openid`）
- `set -e` 下 `X=$(grep -c ... || echo 0)` 会**直接中断脚本**（grep 无匹配 rc=1 传给赋值），
  正确写法是 `X=$(grep -c ...) || X=0`
- RuoYi 的 DELETE 端点接收 `/{ids}` 批量路径，单个 id 也建议传 `id,id`；`sys_user` 删除是**逻辑删除**（`del_flag=2`）

### CI（`.github/workflows/build.yml`）

CI 只做**静态校验 + 构建**：`lint-mybatis` → `mvn clean package` → `npm run build:prod`。
端到端 smoke 需要真 MySQL 与真数据，留给开发者本地手跑。

> 待办：runner 目前是 `macos-14`（计费 10x、与生产不一致），建议迁到 `ubuntu-latest` + MySQL service container，
> 那时可把 62 个 smoke 接进 CI。

---

## 部署上线

完整清单见 **`doc/上线配置清单-2026-08-20.md`**，部署步骤见 **`doc/部署上线指南.md`**。以下是最容易踩的三件事。

### 1. profile 必须包含 `prod`（最高危）

`WxPayConfig` / `WxMaConfig` 只在「生产 profile」下**强制关闭 mock 支付与 mock 微信登录**；
非生产 profile 会退回读 `sys_config`，而库里的 mock 开关默认是 `true` —— 一旦漏配，**线上会走假支付**。

当前被识别为生产的 profile：`prod` / `production` / `aliyun-oss` / `oss` / `minio` / `cos` / `qiniu`。

```bash
# 推荐写法：显式带 prod，再叠加存储 profile
java -jar ruoyi-admin.jar --spring.profiles.active=prod,druid,aliyun-oss
```

### 2. 必需环境变量（不要写进 yml 提交）

| 变量 | 默认值（仓库内） | 用途 |
|---|---|---|
| `JWT_SECRET` | `abcdefghijklmnopqrstuvwxyz` | `token.secret`，**必须换**：`openssl rand -base64 48` |
| `DB_HOST` / `DB_PORT` / `DB_NAME` | `localhost` / `3306` / `ry-vue` | 主数据源地址 |
| `DB_USER` / `DB_PASSWORD` | `root` / `133301` | **必须换**成最小权限账号 |
| `REDIS_HOST` / `REDIS_PORT` / `REDIS_PASSWORD` | `localhost` / `6379` / 空 | 会话与缓存 |
| `DRUID_STAT_ENABLED` | `false` | Druid 监控页开关，排查完务必关回 |
| `DRUID_STAT_USER` / `DRUID_STAT_PASSWORD` | `ruoyi` / `123456` | 开启监控页时必须换 |
| `RUOYI_PROFILE_PATH` | 开发机 Mac 路径 | 本地附件目录（`storage.type=oss` 时基本用不到） |
| `OSS_BUCKET` / `OSS_ACCESS_KEY` / `OSS_SECRET_KEY` / `OSS_ENDPOINT` | — | 见 `doc/存储适配指南.md` |

`sys_config` 侧还需在后台改：`wx.miniapp.mockEnabled` / `wx.pay.mockEnabled` 改 `false`（prod profile 会代码层强制关，
但仍建议数据层一并改），以及 `wx.pay.appId / mchId / apiV3Key / certSerialNo / privateKeyPath / notifyUrl`（notifyUrl 必须 HTTPS）。

### 3. 上线前自检

```bash
bash .github/scripts/preflight-prod.sh
```

8 项只读检查（不写库、不改文件）：

1. `SPRING_PROFILES_ACTIVE` 是否含 `prod`
2. `JWT_SECRET` 是否仍是仓库默认值 / 是否够长
3. `DB_HOST` 是否还指向本机、`DB_USER` 是否 root、`DB_PASSWORD` 是否开发密码
4. Druid 监控页是否被打开、口令是否默认
5. `sys_config` 里两个 mock 开关的实际取值
6. 微信支付 5 项凭证是否非空 + `notifyUrl` 是否 HTTPS 且非占位
7. 小程序 `config.js` 默认 `BASE_URL` 是否还是内网地址
8. OSS bucket / accessKey 是否配置

**目标是 FAIL=0 再发布。** 检查 5/6 需要 mysql 客户端与 `DB_NAME`，否则该项跳过并给 WARN。

### 4. 数据迁移（本地库 → 服务器）

**不要**整库 `mysqldump` 直导：本地库有 21 个默认密码账号、878 个 mock 会员、232 笔假订单、
42168 行 job 日志和 2 处字符集损坏。推荐「结构走脚本 + 手工录真实商户/商品」，
详细两种方案与清洗 SQL 见 `doc/上线数据迁移方案-2026-08-22.md`。

> 上线后请登录后台确认侧边栏「团购运营」下有 6 个分组共 25 个页面。
> 这 19 个业务菜单最初是代码生成器直接写进开发库的，SQL 一直没入仓，
> 现已补为 `sql/biz_menu_business_pages.sql` 并接入 `init-all.sh`。

### 小程序侧

- `miniprogram7/utils/config.js` 的默认 `BASE_URL` 目前是内网地址，上线必须改成 **HTTPS 域名**
  （或由第三方平台代发布时通过 `ext.json` 注入 `apiBaseUrl`）
- 微信后台「开发设置 → 服务器域名」需把该 HTTPS 域名加入 `request` 白名单
- 太阳码 `getWxaCodeUnlimited` 要求小程序**已发布**，未发布返回 `errcode 40066`

---

## License

基于 [RuoYi-Vue](https://gitee.com/y_project/RuoYi-Vue) v3.9.2 改造，二次开发用于多商户团购 SaaS。
原 RuoYi 遵循 MIT 协议；本仓库同样以 MIT 开源。
