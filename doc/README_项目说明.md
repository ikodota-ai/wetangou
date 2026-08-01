# 洞天团购 · 多店铺到店自取小程序（基于 RuoYi-Vue 二次开发）

一个支持多店铺的到店自取团购小程序，覆盖到店自取、在线预约、到店买单（店员确认+代金券）、推客分销与提现等核心场景。后端基于 RuoYi-Vue，前端为微信原生小程序，后台管理复用 ruoyi-ui。

## 一、模块组成
- 后端：RuoYi-Vue 多模块（`ruoyi-admin/framework/system/common/...`）。新增业务模块 `com.ruoyi.biz`（19 张 `biz_*` 表 CRUD）与小程序 C 端 `/api/**`。
- 小程序：`miniprogram/`（微信原生，21 页面）。
- 后台管理：`ruoyi-ui`（Vue2 + element-ui），新增「团购运营」菜单（17 菜单 + 85 按钮权限），下设 5 个分组目录：门店商品 / 交易订单 / 会员体系 / 推客分销 / 平台配置。

## 二、核心能力
- 多店铺：所有业务数据按 `store_id` 隔离；会员全局唯一、可跨店消费；后台账号-门店映射 `biz_store_user`。
- 到店自取闭环：下单 → 微信支付（当前 mock）→ 生成核销码 → 门店核销（校验门店/状态/有效期，防重复）。
- 在线预约：提交 → 门店确认 → 完成/取消。
- 到店买单：会员发起 → 店员现场确认金额 → 会员支付，支持代金券抵扣。
- 推客分销：加入推客、按可配规则（`biz_commission_rule`）结算佣金、提现申请与记录。
- 统一商户号 + 分账：`biz_settle_account/record` 建模，接口预留（需商户资质接入）。

## 三、数据库
- 库：`ry-vue`（MySQL，utf8mb4）。
- 脚本执行顺序：`sql/ry_20260417.sql` → `sql/quartz.sql` → `sql/biz_tables.sql` → `sql/biz_seed.sql`（演示数据）
  → `sql/biz_tenant_tables.sql` → `sql/biz_tenant_upgrade.sql` → `sql/biz_tenant_menu.sql`（多商户/代理商，**后端启动前必须执行**）。
- 菜单分组：`sql/biz_menu_reorganization.sql`（将「团购运营」下 19 个平级菜单归入 5 大类，可重复执行）。
- 租户三件套均幂等可重复执行；执行前建议 `mysqldump ry-vue > backup.sql`（唯一键变更不可逆）。

## 四、本地启动
### 后端
```
export JAVA_HOME=$(/usr/libexec/java_home -v 25)   # 目标 Java 17，可用 JDK25
mvn -o package -DskipTests -pl ruoyi-admin -am
java -Dlog.path=./logs -jar ruoyi-admin/target/ruoyi-admin.jar   # 端口 8080
```
- 数据源：`ruoyi-admin/src/main/resources/application-druid.yml`（root/133301）。
- 微信登录：`application.yml` 的 `wx.miniapp`，无凭证时 `mockEnabled: true`（用 code 派生 openid 联调）。

### 后台管理（ruoyi-ui）
```
cd ruoyi-ui && npm install
npm run dev            # 开发，默认 80
npm run build:prod     # 生产打包到 dist（已验证成功）
```
- 登录 admin/admin123，进入「团购运营」维护门店、商品、订单、预约、推客、代金券、协议等。

### 小程序（miniprogram）
- 微信开发者工具导入 `miniprogram/`；`config.js` 配置 `baseUrl`。
- 真机：配置合法域名、真实 appId/secret 并关闭 mock。

## 五、C 端接口（/api）
认证 `/api/auth`（login/info/logout）、会员 `/api/member`、门店 `/api/store`、商品 `/api/product`、
订单 `/api/order`（下单/支付/核销/我的）、预约 `/api/booking`、买单 `/api/bill`、
代金券 `/api/voucher`、推客 `/api/distributor`、协议 `/api/agreement`。
- 会员鉴权：独立 JWT（`MemberTokenService`）+ Redis，`@LoginRequired` + `MemberAuthInterceptor` 拦截 `/api/**`，与后台 admin token 隔离。

## 六、验证结论
- 后端：编译/启动正常，登录鉴权链路通过。
- 后台 CRUD：19 表接口全部 HTTP 200；ruoyi-ui 生产构建成功。
- C 端：22 项接口端到端主链路全部通过（登录→浏览→领券→推客→下单→支付→核销→佣金→预约→买单）。
- 小程序：21 页面 JS 语法/JSON 全部校验通过。

## 七、设计文档索引（doc/design/）
- `../小程序API文档.md`：C 端 `/api/**` 全量接口说明（含实测响应）+ 小程序功能完整度盘点与待补清单。
- `00_原型分析进度.md`、`01_原型逐图分析.md`：33 张原型图分析。
- `02_小程序开发规划.md`：架构、数据模型、流程、接口、路由、技术决策。
- `03_环境与数据库搭建产物.md`
- `04_后台CRUD生成产物.md`
- `05_C端接口开发产物.md`
- `06_小程序前端产物.md`
- `07_资金结算闭环产物.md`：佣金冷静期结算 + 提现审核回退（含验证证据）。

## 七之二、多商户与代理商（进行中）
平台 → 代理商 → 商户 → 门店 四层体系，详见 `doc/多商户与代理商改造方案.md`。
- 已完成：租户上下文（后台/小程序双侧）、MyBatis 读写自动过滤（`merchant_id`）、
  代理商与商户 CRUD + 开户额度校验、小程序 appid 多租户化（请求头 `X-App-Id`）、
  代理商缴费与商户收费（审核确认后自动发放额度/延长服务期）、小程序发布状态机与留痕，
  以及「租户管理」下 5 个后台页面（代理商 / 代理商缴费 / 商户 / 商户收费 / 小程序发布）。
- ext.json 自动生成：代上传时按商户 appid + 平台接口域名自动生成，无需手工抄写
  （`GET /biz/mprelease/extjson/{merchantId}`）。
- 「小程序平台配置」页（团购运营 → 平台配置）：开放平台第三方平台参数、代码模板ID、
  接口域名集中维护，不再去「系统参数」逐条改（菜单脚本 `sql/biz_mpconfig_menu.sql`）。
- 演示数据已从小程序 mock 提取入库（`sql/biz_demo_data.sql`）：门店「菌鑫来餐饮」+ 4 款商品
  （含套餐明细与使用规则）+ 相册 4 张 + 分类 3 个 + 2 张代金券，并把用户协议/隐私政策
  正文从 46 字补全到 635/686 字；协议、相册、客服三页已改为读后台数据。
- C 端接口已全链路实测通过并输出 `doc/小程序API文档.md`；实测中修掉 3 个阻塞级 bug
  （10 张表 update/delete 的无效表别名、`biz_order.verify_code` 唯一索引冲突、
  `sys_config` 清空值不落库）。
- 小程序去 mock 进度（截至 2026-08-01）：
  - 已接真实接口的有**订单三页**（提交 / 列表 / 新增详情含核销码）、
    **买单页**（真实券筛选 + 轮询店员确认 + 支付）、商品详情、我的资料、协议、相册、客服页。
  - 预约链路全部跑通：新增 `GET /api/booking/slots`（按门店营业时间 + 已约人数计算容量）、
    `GET /api/booking/signup/{id}`（仅本人）、场次详情脱敏只回本人报名；
    创建页支持门店动态加载 + 时段选择（含已过/已满/剩 N 提示），
    列表页 4 个 tab 区分全部/待确认/已完成/已取消，详情页按状态控制取消按钮。
  - 推客中心真实化：center 返回订单数/提现中金额等概览，佣金与提现记录按状态 tab 展示，
    提现页支持微信/支付宝/银行卡 3 种方式与「全部提现」；
    后端补 `GET /api/store/{id}/services` 字典翻译接口，设施标签不再硬编码。
  - 新增「代金券」页（领券中心 + 我的券 3 状态 tab），首页/「我的」均有入口；
    后端补同券同会员不可重复领取拦截，推客协议正文 15 字补到 905 字。
  - 首页 banner 改用门店相册、客服电话/二维码/营业时间跟随门店；商品划线价只显示与现价不同的市场价。
  - `request.js` 修掉 4 处路径错配并补 11 个封装，同时移除「失败也提示成功」的伪造兜底。
  - 剩余待做：推客粉丝模块需先在会员表加 `invite_by` 关系与邀请海报页（约 0.5 天）、
    门店端核销/确认/审核的角色鉴权（约 0.5 天）、
    17 个 datetime 字段的序列化精度（API 文档 10.10）。
- 待做：`WxPayService` 按商户取支付凭证与回调路由 `/api/pay/notify/{merchantId}`、
  微信第三方平台真实代发布接口、19 个业务页的「商户」筛选列、
  推客粉丝邀请机制（详见 10.12 收尾说明）。

## 八、后续待接入（生产化）
- 微信支付真实下单与回调 `/api/notify/wxpay`、分账执行。
- 佣金冷静期结算已实现（`POST /biz/commission/settle` 手动触发，见 07 文档）；生产建议接入定时任务自动结算。
- 门店端独立核销角色与数据权限细化（`@DataScope` + `biz_store_user`）。
- 手机号解密（`getPhoneNumber` 加密数据后端解密）。
