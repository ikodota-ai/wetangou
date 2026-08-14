# Repository Guidelines

## Project Structure & Module Organization
This is a RuoYi-Vue admin platform: a multi-module Maven backend plus a Vue 2 frontend.
- `ruoyi-admin/` — Spring Boot entry point, controllers under `src/main/java/com/ruoyi/web/controller`, configs in `src/main/resources`.
- `ruoyi-framework/` — security, web, and framework config; `ruoyi-system/` — business services, mappers, and MyBatis XML.
- `ruoyi-common/` — shared utils, annotations, constants; `ruoyi-quartz/` — scheduled jobs; `ruoyi-generator/` — code generator.
- `ruoyi-ui/` — Vue 2 client (`src/`, `public/`); `sql/` — DB scripts; `doc/`, `bin/` — docs and helper scripts.

## Build, Test, and Development Commands
- `mvn clean package` — build all backend modules and produce `ruoyi-admin/target/ruoyi-admin.jar`.
- `mvn spring-boot:run -pl ruoyi-admin` — run the API locally (default port 8080).
- `./ry.sh start|stop|restart|status` — manage the packaged jar on Linux/macOS; `ry.bat` on Windows.
- `cd ruoyi-ui && npm install` — install frontend deps; `npm run dev` — serve UI at `localhost:80`.
- `npm run build:prod` — produce production frontend assets in `ruoyi-ui/dist`.

## Coding Style & Naming Conventions
- Java: 4-space indent, `PascalCase` classes, `camelCase` methods/fields; controllers end in `Controller`, services in `ServiceImpl`, mappers in `Mapper`.
- Frontend: 2-space indent, LF endings, UTF-8, final newline (see `ruoyi-ui/.editorconfig`); Vue components in `PascalCase`, API modules under `src/api`.
- Keep MyBatis XML alongside mapper packages; match `<mapper namespace>` to the Java interface.

## Testing Guidelines
- No formal test suite ships with the project; `TestController.java` is a demo endpoint, not a unit test.
- Add backend tests with JUnit under `src/test/java` mirroring the source package, named `*Test.java`, and run via `mvn test`.
- Validate UI changes manually through `npm run dev` before submitting.

## Commit & Pull Request Guidelines
- Commit messages are short, imperative summaries (often Chinese), e.g. `优化代码` / `修复脱敏不生效问题`; keep to one focused change per commit.
- PRs should include a clear description, linked issue when applicable, affected modules, and screenshots for UI changes.
- Confirm `mvn clean package` and `npm run build:prod` succeed before requesting review.

## Security & Configuration Tips
- Configure datasource, Redis, and tokens in `ruoyi-admin/src/main/resources/application*.yml`; never commit real credentials.
- Run `sql/*.sql` scripts to initialize the database before first launch.

## 已交付（2026-08-02 全部 11 项已完成）

### 1. 平台 / 代理商 / 商户登录入口分流 ✅ 已交付
- 已交付 12/12 项 plan（含登录入口 userType 路由分流）。
- 登录分流 commit：`fade76ff feat: 方案C身份路由与菜单权限（3测试账号+SQL脚本+验证报告，0行代码改动）`
- 落地位置：`ruoyi-ui/src/views/login.vue` 的 `resolveEntryPath()` —— 平台→`/index`、代理商→`/agent/index`、商户→`/merchant/index`
- 配套：`LoginUser`/`getInfo` 已返 `userType / agentId / merchantId`（`530c5a3b` commit）；路由 + 菜单按 `userType` 过滤（同 fade76ff）。
- 详情见 doc/多商户与代理商改造方案.md 6. 实施顺序表（12 项 ✅）



## A2 佣金冷静期余额联动闭环（2026-08-14 · 1 commit）

> 背景（doc/下一轮迭代清单-2026-08-05.md A2）：佣金产生时没联动 frozen_amount，
> 冷静期到期 transfer 找不到 amount 来源；订单退款不联动 available 减扣。

### 已闭环
- **commit 2701f1e7**：`CommissionServiceImpl.insertCommission` 成功后调 `distributorMapper.incFrozenAmount(#{amount})`
  - 同一事务，insert 失败/amount 为 null 都不调
  - 冷静期到期由 SettleCommissionTask.linkSettlementToDistributor 做 frozen→available 转换（已有，未改）

### 端到端验证（distributor 1003 baseline frozen=0）
- POST 5.00 → frozen 0→5 ✅
- POST 8.00 → frozen 5→13 ✅
- 改 create_time 8 天前 + 触发 SettleCommissionTask
  → frozen 13→0 / available 16.6→29.6 / total 7.6→20.6 / commission 2 笔 status 0→1 ✅

### A2 TODO2（未做）
- 订单退款回调 → commission.status=2 → 已结算过则 available -= amount
- 现状：业务系统**没有 Order 退款入口/Service**（status 0~4 简单流程无 refund 端点）
- 不是"已存在但联动漏了"，是"功能未实装"——超出 A2 范围
- 后续若加退款功能，需在 Order 退款回调里挂 commission 联动

### A3 release UI（已实装，doc 误判）
- 实际状态：MpReleaseController 8 端点 + UI 8 按钮 + 4 API（list/getInfo/add/edit/extjson + submit/undo/release）全部就绪
- doc/下一轮迭代清单-2026-08-05.md 标"未做"是误判
## A1 业务表租户过滤闭环（2026-08-14 · 5 commit）

> 背景（doc/下一轮迭代清单-2026-08-05.md A1）：代理商/商户账号调 /biz/order/list 等业务表
> 没强制 tenant 过滤，会看到别家订单 → 跨租户数据泄漏。

### 已闭环
- **公共工具** `ruoyi-system/biz/tenant/TenantFilterHelper.java`：apply(BaseEntity, setter, getter)
  - 平台（userType=0）：不强制
  - 代理商（userType=1）：强制限定到名下商户 IN(...)
  - 商户（userType=2）：强制 merchantId，前端越权传值 → 500 '无权查询其他商户的数据'
- **7 个核心 Service 切片**（5 commit）：
  - Order（5f17bd5a）→ Booking（46fe6616）→ PayBill/Distributor/Withdraw（86676864）→ Commission/Product（a542ff9d）
- **5 个 mapper XML** 加 `params.merchantIdsIn` 过滤（IN/单值/空集三种形态）

### 端到端验证（每表 3-10 测试行 + M1/M2 分布）
- 平台 admin：全平台视角（不限制）
- 代理商：只看名下商户
- 商户：只自己；越权 → 500 拒

### 剩余（非 P0）
- Member/Voucher/Store/MerchantStaff/MpRelease 等 ~10 个 Service 按需补 helper（模板已固化，5-10 分钟/个）

## v2 升级交付（2026-08-14 · 13 commit）

> 详见 `doc/v2升级一致性审计-2026-08-14.md`（289 行）。基于抖音来客商品模型 PRD（`doc/PRD-抖音来客商品模型.md` 437 行）实施。

### 已实装
- **后端域 (5 类)**: ProductType / ProductSubitem / ProductSubitemGroup / MerchantStaff / MerchantStaffInvite（5 domain + 5 mapper + 5 service 接口 + 5 impl + 5 xml）
- **后端 controller (5 个)**: BizProductTypeController（字典 CRUD 7 端点）/ BizProductSubitemController / BizStaffInviteController / ApiMerchantStaffController（小程序端 16 端点）/ ApiPingController
- **后端 v2 字段 (biz_product 加列)**: typeCode / industryCode / faceValue / minConsume / totalTimes / periodType / periodCount 等（sql/biz_product_model_v2.sql）
- **SQL 迁移 (7 张表)**: biz_product_category（3 级）/ biz_product_type（11 种字典）/ biz_product_subitem(_group) / biz_product 加列 / biz_merchant_staff(_invite)
- **admin 端 12 种 typeCode 下拉**: views/biz/product/index.vue 硬编码（GROUPON / VOUCHER / TIMECARD / STORED_CARD / PERIOD_CARD / HUIXIANG_CARD / COMBO / BILL / BOOKING / MONTH / QUARTER / YEAR）
- **admin 端员工邀请页**: views/biz/staffInvite/index.vue
- **小程序商家端 10 page**: home / order / bill / booking / verify / scan / profile / me / history / login（核销/管理/扫码视角，581 行）
- **SysUser 多商户身份字段**: openid / openidBound / userType / merchantId + selectUserByOpenId

### 遗留 / 未做（§6 P0~P3）
- **P0 阻塞**: `sql/biz_product_model_v2.sql` + `sql/biz_merchant_v2.sql` 未在 Navicat 执行 → R1a 报 `biz_product_type doesn't exist`
- **P0 commit**: ✅ 13 commit 已落地（40610a5b..3162bb8c），137 文件 / +7987/-350
- **P0 编译**: ✅ `mvn -o clean compile` BUILD SUCCESS（47s，7 模块）
- **P1 字典化**: admin 商品页 12 种下拉仍 hardcode，未对接 biz_product_type 字典 API（缺 productType.js）
- **P1 商家端商品创建**: 10 page 无 typeCode/createProduct 入口，PRD §8 主流程未实现
- **P1 菜单/权限**: 5 个新 controller 缺对应 sys_menu + biz:productType:* perms SQL
- **P2 文档对账**: PRD 8 种 vs admin 12 种 vs SQL 11 种三方不一致（建议统一为 11 种）
- **P2 登录分流**: ✅ fade76ff commit 已实装 login.vue resolveEntryPath + userType 路由过滤（不是"未做"，AGENTS.md 上方话术已修正）
- **P3 待清理**: ApiPingController 仅调试用 / miniprogram7/tests/ 决定去留

### 13 commit 速查
```
3162bb8c refactor(system): 删除已拆分的旧 ApiOrderService（234 行）
530c5a3b feat(v2): SysUser 多商户/代理商/微信身份字段 + 查询接口
b92586b2 feat(v2): 小程序全局配置 + 18 page 业务 + admin 微信配置 + druid
cd808b89 feat(v2): admin 商品页 12 种下拉 + api 端点 v2 字段支持 + 微信配置
f7910124 feat(biz): v2 商品域/Mapper 同步 + api service 拆分类引用调整
934e02b4 docs: v2 抖音来客商品模型 PRD + 审计报告 + 调试文档
201b3ec3 chore: ignore doc/*.sh 运维脚本
f6095eab feat(miniprogram): 商家端 10 page（核销/管理/扫码视角）
f874259a feat(ui): v2 子品/员工邀请 前端 API + 员工邀请管理页
c0127c64 feat(admin): v2 admin 端 controller + 部署配置
6f58330d feat(system): v2 商品字典/子品/商家员工域 + api 订单 service 拆分
4e071924 feat(sql): v2 商品模型 + 商家员工表迁移脚本（业务）
5f435ace chore: ignore 抖音来客参考素材 + node_modules 等不入库产物
```

## 下一轮迭代清单 15 项收口（2026-08-14 · 25 commit）

> 来源：`doc/下一轮迭代清单-2026-08-05.md` 状态审计表。

### 最终状态
- **12 项 doc 误判**（A3/A4/A5/B1/B2/B3/C1/C2/D1/D2/D3 + 部分 A2）：实际已实装或采用不同方案
- **5 项本轮闭环**（A1 / A2 / A3 / C1 / D4）：A1 12 Service 切片、A2 frozen 联动、A3 release UI 8 端点、C1 admin UI 容器、D4 CI
- **0 项未做**：15 项 doc 全部闭环 🎉

### 25 commit 速查（本 session）
```
7daf9f60 fix(biz): C1 端点 snake→camel + IFNULL 兜底
1566425f docs(plan): C1 admin UI 容器实装后状态收口
8135060e feat(biz): C1 代理商佣金概览 admin 端 UI 容器
8b7f794b docs(plan): B2/B3/C1/C2/D2 状态审计纠错
11cca693 feat(ui): BizSelect 改用 webpack require.context 自动注册
7d31ef3d feat(api): 代理商佣金概览端点
9b9eb59d docs(plan): doc 状态审计表
612c5b7d ci(github): Build & Verify 流水线
305ba002 feat(biz): Member/Voucher/Store/Agreement/CommissionRule 租户过滤
f89b038f docs(agents): A2 联动闭环 + A3 release UI 误判
2701f1e7 fix(biz): 佣金 frozen 联动
cb2e27ad docs(agents): A1 段
a542ff9d feat(biz): Commission+Product 租户过滤
86676864 feat(biz): PayBill+Distributor+Withdraw 租户过滤
46fe6616 feat(biz): TenantFilterHelper + Booking
5f17bd5a feat(biz): Order 租户过滤
42a57f5c docs(agents): 修正登录分流话术
42d24ac1 feat(miniprogram): 商家端-创建商品 page
088e7b89 feat(api): ApiProductController.add
985ccc26 docs(PRD): v2.1 对齐 11 种商品类型
33ecedca feat(ui+sql): admin v2 字典/子品/权限
09088ba0 feat(ui): typeCode 下拉字典化
e5fc6735 fix(biz): ProductMapper.xml 孤立 left join
8704a7eb fix(sql): 适配 RuoYi 默认表结构
30c9ea6e fix(sql): 拆出 v2 seed 独立文件
```
（合并前 5 commit v2 收口，省略）

### 关键 C1 闭环证据
- 后端：`BizAgentCommissionController` 67 行 + `CommissionMapper.xml` 修 Date 比较 + IFNULL 兜底
- 前端：`agentCommission.js` API + `agent/index.vue` 加 4 卡（总/已结/待结/商户）+ 名下商户佣金明细表
- SQL：`sql/biz_agent_commission_c1.sql` 33 行幂等脚本（menu_id=2281, perms=biz:agent:commission:summary）
- E2E：`GET /biz/agent/commission/summary?agentId=1` → `{totalAmount:62.80, settledAmount:62.80, pendingAmount:0.00, commissionCount:3, byMerchant:[1个商户]}`

### 当前后端进程
- PID 48484 (java -jar ruoyi-admin/target/ruoyi-admin.jar)
- 启动 ~1:42，profile=druid，端口 8080
- 验证：`GET /captchaImage` → 200 (127ms)

### 下一轮起点
- `doc/下一轮迭代清单-2026-08-14.md`（如已建）or 重新规划

## C1 端到端验证（2026-08-14 · 19:14）

### 后端健康
- PID 49205（java -jar ruoyi-admin/target/ruoyi-admin.jar），port 8080
- profile=druid，启动 1:10 后 captcha 200 OK
- 5/5 关键 API 全 200：
  - GET /getInfo
  - GET /biz/agent/commission/summary?agentId=1
  - GET /biz/merchant/list
  - GET /biz/distributor/list
  - GET /biz/commission/list

### C1 跨租户泄漏修复（commit 7a0299d4）
- Bug：agentId=999（无商户）→ 返 agentId=1 的 ¥62.80
- 根因：sumByMerchantIds mapper `<where>` 在 merchantIds=[] 时只保 beginTime/endTime
- 修：mapper 加 `<if merchantIdsEmpty==true> and 1=0 </if>` + service 传 merchantIdsEmpty
- E2E：
  - agentId=999 → {merchantCount:0, totalAmount:0, byMerchant:[]} ✓
  - agentId=1 → {merchantCount:1, totalAmount:62.80, byMerchant:[1条]} ✓

### P3 待清理 doc 误判
- ApiPingController：实际是生产健康检查端点（小程序启动探测用），非调试代码，保留
- miniprogram7/tests/：3 个真实 vitest 单测（util/request/pickNearestStore），保留
- 不需要清理

### 前端 dist 状态
- 18:55 build 含 C1 改动（agentCommission.js + 4 卡）
- 后续 5 commit 全是后端 / doc，无前端改动，dist 无需重 build
