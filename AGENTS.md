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

### 1. 平台 / 代理商 / 商户登录入口分流（剩余项，本次未做）
- 已交付 11/11 项 plan：sys_user 身份回填 / WxPayService 按商户 / 微信代发布 / 商户筛选列 / @Sensitive 脱敏 / 佣金冷静期 Quartz / 首页 banner 后端化 / 文档同步。
- 剩余项：登录入口按 userType 路由分流未做（用户未授权），工作量约 0.6 天。
- 待做：
  - `LoginUser`/`getInfo` 返回体补 `userType / agentId / merchantId`
  - `ruoyi-ui/src/views/login.vue` 顶部加「平台 / 代理商 / 商户」三选一 tabs（仅文案提示，不参与鉴权）
  - `ruoyi-ui/src/store/modules/user.js` 登录成功按 `userType` 跳转：
    - 平台 → `/index`
    - 代理商 → `/agent/index`（新建代理商工作台：名下商户 / 缴费记录 / 额度）
    - 商户 → `/merchant/index`（新建商户工作台：门店 / 订单 / 资金）
  - 路由 + 菜单按 `userType` 过滤
- 详情见 doc/多商户与代理商改造方案.md 6. 实施顺序表（11 项 ✅）

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
- **P2 登录分流**: 8-02 计划的 userType 路由分流仍未做（LoginUser / login.vue / user.js 待改）
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
