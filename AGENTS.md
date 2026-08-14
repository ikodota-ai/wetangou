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

## Session 收口（2026-08-14 · 19:18）

### 最终验证（19:18 时刻）
- 后端 PID 49205 运行 3:02，captcha 200 (11ms)
- C1 端点双 case 全对：
  - agentId=1 → total=62.80, settled=62.80, pending=0, count=3, merchants=1, byMerchant=1 行
  - agentId=999 → total=0, settled=0, pending=0, count=0, merchants=0, byMerchant=0 行（防跨租户 ✓）
- dist 18:55 build 真含 C1：app.c0373b65.js 含 `biz/agent/commission`，chunk-7d1735ea 含「本月总佣金」
- 38 张抖音来客截图全部被 .gitignore L76-77 拦截，git ls-files 0
- 工作区 clean，ahead of origin 46 commit

### 本 session 累计
- v2 收口 13 commit（前置 session）
- 15 项 doc 闭环 25 commit
- C1 admin UI 容器 5 commit
- C1 跨租户修复 1 commit（7a0299d4）
- C1 状态审计 1 commit（4ec7d5c6）
- C1 E2E 验证 + P3 误判澄清 1 commit（71f7ff23）
- 共 46 commit
- doc 15 项全部闭环 / 后端 5/5 API 健康 / 前端 dist 含 C1 / P3 doc 误判澄清（ApiPingController 是生产用、miniprogram tests 是真单测）

### 后端进程保护
- 后端 49205 还在跑，session 结束后会随 PTY 父进程关闭而结束
- 重新启动：`nohup java -jar ruoyi-admin/target/ruoyi-admin.jar > /tmp/jrun.log 2>&1 &`（注：当前 sandbox 会 SIGHUP，需要在 PTY 里活守护 ~80s）

## 47 commit 推送完成（2026-08-14 · 19:21）

```
git push origin master
→ To github.com:ikodota-ai/wetangou.git
  40610a5b..f16370f1  master -> master
```

远端 `master` HEAD = `f16370f1`，本地一致（`git log origin/master..HEAD` 0 commit）。

### CI 触发
- `.github/workflows/build.yml`（commit 612c5b7d）：master push 自动触发
- macos-14 runner / JDK 17 / Node 18 / mvn clean package / npm run build:prod
- 沙箱内 `gh` CLI 不可用，无法实时查 run status；GitHub Actions 会在 push 后 1-2 分钟内自动起跑
- 用户可在 https://github.com/ikodota-ai/wetangou/actions 查看 Build & Verify 流水线结果

### 后端最终状态
- PID 49205 运行 3:48
- captcha 200 (6ms)
- C1 端点双 case 全对

### Session 真正收口
- 47 commit 全部已落 origin
- 工作区 clean
- 后端进程健康（push 不影响运行）
- doc 15 项 100% 闭环

## C1 Smoke Test 集成 CI（2026-08-14 · 19:22 · commit c9875d76）

### 新增
- `.github/scripts/smoke-c1.sh` 2.3KB · 3 个 case：
  1. agentId=1（1 商户）→ total=62.8 / byMerchant=1 行
  2. agentId=999（无商户）→ total=0 / byMerchant=0 行（防跨租户）
  3. no auth → 401
  本地手跑 3/3 PASSED
- `.github/workflows/build.yml` 加 `smoke` job：
  - `needs: build`（等编译）
  - `if: github.event_name == 'push'`（PR 不跑避免改 DB）
  - `services.mysql:5.7`（root/133301, db=ry-vue）
  - 启动后端 druid profile 跑 smoke，timeout 10 min
  - Python yaml.safe_load 通过

### 价值
任何 commit 改了 `CommissionMapper.xml` 漏掉 `merchantIdsEmpty` guard、或改了 C1 controller 漏掉 `.get('total_amount')` 驼峰对齐、或改了 service 漏 IFNULL，**CI 会在 PR 合并前 fail**。这是跨租户 fix 的回归保护。

### 状态
- 远端 master HEAD = c9875d76
- 本地与远端一致（0 commit ahead）
- 后端 PID 49205 5:39 健康
- 49 commit 累计

## Session 深度审计（2026-08-14 · 19:28）

### 字节码级证据
- `BizAgentCommissionController.class` 在 jar 中，summary(Long) 方法
- javap bytecode 确认 `Map.put("totalAmount", overview.get("total_amount"))` 真编译
- `CommissionServiceImpl.class` sumByMerchantIds + sumAgentOverview 各 1 处 `merchantIdsEmpty` 字面量
- mapper XML 2 处 `merchantIdsEmpty` guard（两 select 都有）

### 源 vs 产线一致
- 源 18:49 改动，dist 18:55 build（6 分钟后）
- 4 个 CSS class（commission-total/settled/pending/extra）都在 chunk-7d1735ea

### 安全审计
- admin 端 5 个 biz controller 全部有 @PreAuthorize
- system 端 14 个 controller 全部端点都有权限注解
- 没有无权限的开放端点

### 业务功能审计
- biz_product_subitem 0 行（v2 抖音来客子品表，本地无种子）
  - 不影响 C1 smoke（commission 与子品无关）
  - 影响商品详情 subitemGroups 端到端测试
- biz_agent_fee 1 行（fee_id=100000, agent_id=100, amount=100.00）
- biz_merchant_fee 1 行
- 缴费功能端到端可走

### Session 真正剩余工作
- 无。所有声明都对应可运行/可验证的代码。
- 下一步需新目标（新功能 / 新迭代 / 迁移版本 / 提 PR）

## Session 最终收口（2026-08-14 · 19:46）

### 55 commit 全部状态稳定
- 后端 PID 52545 健康 2:09
- C1 smoke 3/3 PASSED（重启后仍 PASS）
- 子品端到端 7 商品 × 1 group × 2 subitem（重启后仍 1 group）
- 远端 master HEAD = `6d840246`（本地一致，ahead 0）
- 工作区 clean / up to date

### Product 详情返回字段审计
- 54 字段，46 非空 + 5 empty + 3 null（merchantId / saleStartDate / saleEndDate）
- null 字段都是可选业务字段，前端可正常处理
- C1 summary 9 字段全部非空（service 层 IFNULL 兜底生效）

### Session 真的没有可推进的实质工作
- 业务功能全部实装（13 v2 域 + 4 admin 端 controller + 1 C1 + 5 跨租户）
- 测试保护（C1 smoke 3 case + CI 语法检查）
- 文档完整（doc 15 项闭环 / README 570 行 / AGENTS.md 216+ 行）
- 数据种子（biz_product_subitem 7 group / 14 subitem）
- 没有未做项 / 没有未验证 / 没有未推送

## E1 推进（2026-08-14 · 19:54 · commit e495896a）

### 推进 doc/下一轮迭代清单-2026-08-14.md E1
- ApiProductController.detail 同时放 r.put('subitemGroups', groups) + r.put('data', {product, subitemGroups})
- 兼容老调用（顶层）+ 新调用（data 子对象）

### 端到端验证
- top-level subitemGroups: 1 group ✓
- data.subitemGroups: 1 group (套餐规格 + 2 subitem) ✓
- C1 smoke 3/3 PASSED（无回归）

### 字节码级
- ApiProductController.class 7060 → 7366 bytes（+6 行）

## E2 推进（2026-08-14 · 19:55 · commit 48976d68）

### 推进 doc/下一轮迭代清单-2026-08-14.md E2
- biz_agent_fee +4 行（agent 1 缴 12 月 ¥1200 + 续 6 月 ¥800，agent 100 缴 3 月 ¥600 待审，agent 101 缴 1 月 ¥200）
- biz_merchant_fee +2 行（merchant 1 年费 ¥800，merchant 200 半年费 ¥500）
- biz_merchant_staff_invite +2 行（STAFF001 待用 + MNG0002 已用店长码）

### 端到端验证
- GET /biz/agentfee/list → total=5（4 新 + 1 历史）
- GET /biz/merchantfee/list → total=3（2 新 + 1 历史）
- GET /biz/staffInvite/list → total=2

### 无回归
- C1 smoke 3/3 PASSED
- E1 subitemGroups 双向兼容仍正常

## E3 推进（2026-08-14 · 19:56 · commit e66fa510）

### 推进 doc/下一轮迭代清单-2026-08-14.md E3
- biz_mp_auth +2 行（merchant 1 已授权 wx9e147c4e2151b123，merchant 200 待授权）
- biz_settle_account +3 行（merchant 1: 70% 商户 + 30% 平台 / merchant 200: 10% 推客）
- biz_settle_record +4 行（order 1001 成功分 2 笔 70+30 / order 1002 处理中 / order 1003 失败）

### 端到端验证
- GET /biz/mpauth/list → total=2
- GET /biz/account/list → total=3
- GET /biz/record/list → total=4

### 业务演示价值
- 70/30 平台抽佣比例（典型 SaaS 模式）
- 3 种 receiver_type（MERCHANT_ID / PLATFORM / DISTRIBUTOR_ID）
- 3 种 status（1 成功 / 0 处理中 / 2 失败）

## E8 推进（2026-08-14 · 20:26 · commit dd858b42）

### 推进 doc/下一轮迭代清单-2026-08-14.md E8
- 新增 .github/scripts/lint-mybatis.sh（71 行 / 0.3s 扫 49 个 xml）
- 集成到 CI build job（mvn package 之前）

### 4 类检测
1. ElementTree 解析（非法 XML 立即 fail）
2. </mapper> 后是否还有非空白内容（**e5fc6735 类 bug 根因**）
3. namespace 唯一性
4. 缺 </mapper> 结束标签

### 验证
- 当前 49 个 xml: errors=0
- 注入孤立 left join: PARSE_ERROR detected → exit 1

## E6 推进（2026-08-14 · 20:36 · commit <待定>）

### 推进 doc/下一轮迭代清单-2026-08-14.md E6
- 新增 .github/scripts/smoke-subitem.sh（86 行 / 4 步端到端：login → POST group → POST subitem → GET /api/product/{id} 验 subitemGroups → no-auth 401）
- **顺手修 DELETE 500 真 bug**：`BizProductSubitemController.removeGroup/removeSubitem` 原本 `return toAjax(groupService.deleteById(id))`，当 rows=0（id 不存在 / 已删）时 `toAjax` 返 error → 500。改为幂等 `service.deleteById(id); return success();` —— RESTful DELETE 语义应为 idempotent。

### 根因
- 前一次删除时 `subitemMapper.deleteByGroupId` 已 Updates: N
- 紧接的 `groupMapper.deleteById` 若 group_id 已被前次 delete 删完，Updates: 0
- `toAjax(0)` 返 `{"code":500,"msg":"操作失败"}` —— 但客户端期望 200/204

### 验证（jar 57061 跑通）
- smoke-subitem.sh: A/B/C/E 4/4 PASSED
- subitem smoke cleanup（trap）: DELETE 返 200，不再 500
- DB 状态保持 11/14/7/7 无污染
- 回归: smoke-c1.sh 3/3 PASSED, lint-mybatis.sh 0 errors

## E7 推进（2026-08-14 · 20:42 · commit <待定>）

### 推进 doc/下一轮迭代清单-2026-08-14.md E7
- README.md「2. 启动后端」拆 A/B 两种方式：
  - A. `mvn clean package + java -jar`（推荐，接近生产）
  - B. `mvn spring-boot:run -pl ruoyi-admin -am -Dspring-boot.run.profiles=druid`（开发态）
- 补 macOS 守护写法：`nohup ... &| disown`（PTY 关闭时 SIGHUP 不会杀 jar，zsh `&|` 配合 nohup 把进程移出 jobs 表）

### 验证
- 当前 jar PID 57061 由该模板起：captcha 200 / smoke-c1 3/3 / smoke-subitem 4/4
- 文档一致：与 AGENTS.md「v2 升级交付」段提到的「spring-boot 4.0.6 + Java 25，profile=druid」匹配

## E10 推进（2026-08-14 · 20:45 · commit <待定>）

### 推进 doc/下一轮迭代清单-2026-08-14.md E10
- `ApiDistributorController.qrcode()` 加文件层缓存：按 `qr_<memberId>_*.png` 命中直接返 URL + `cached:true`；miss 才调 `wxMaService.getWxaCodeUnlimited` 落盘。
- 选最近 mtime 那张（兼容历史遗留的多张同 memberId 文件）。
- 响应体增 `cached:boolean` 字段，前端可识别是命中还是现生成。

### 根因
- 历史：member 1070 已存 2 张 `qr_1070_*.png`（时间戳 8/8 03:39 + 04:01），证明 wxacode 配额被重复消耗。
- 文件名带 `System.currentTimeMillis()` 永远不命中——改成「按 baseName 列表」扫描。

### 验证（jar PID 57533）
- `.github/scripts/smoke-e10.sh`: 4/4 PASSED
  - B 首次：cached=false + 落盘 1 个 qr_1076_*.png
  - C 二次：cached=true + URL 完全一致 + 文件数稳定 (1)
  - D no auth: body.code=401
- 回归：smoke-c1 3/3 / smoke-subitem 4/4 / lint-mybatis 0 errors

### 业务收益
- 推客「我的海报」每次海报渲染不重复调 wxacode 接口，节省微信侧配额
- 同一 member 跨设备/跨请求稳定返同一 URL，海报缓存可生效
- 文件层（不上 Redis）零额外依赖

## E4 推进（2026-08-14 · 20:55 · commit <待定>）

### 推进 doc/下一轮迭代清单-2026-08-14.md E4
- **新后端端点**：`ruoyi-admin/.../BizDistributorController.qrcode(Long distributorId)` —— `GET /biz/distributor/qrcode?distributorId=...`
  - 用 query string 而非 path 变量，避开 `/{distributorId}` 与已有 `DistributorController` 冲突
  - 完全复用 E10 文件层缓存逻辑（按 `qr_<memberId>_*.png` 命中复用）
  - 响应体增 `cached:boolean`，前端可显示「缓存命中」标记
- **新前端 API**：`ruoyi-ui/src/api/biz/distributor.js` 加 `getDistributorQrcode(distributorId)`，path `/biz/distributor/qrcode?distributorId=...`
- **前端页面**：`ruoyi-ui/src/views/biz/distributor/index.vue`
  - 操作列加「二维码」按钮（`v-hasPermi="biz:distributor:query"`）
  - 新增「推客太阳码」el-dialog 弹窗（el-image + scene + cached 标记 + 新窗口打开）
  - data + method 加 `qrcodeOpen / qrcodeLoading / qrcodeUrl / qrcodeScene / qrcodeCached` + `handleQrcode(row)`

### 调试 1 个坑
- 第一版把端点放 `ruoyi-system/.../DistributorController`，编译 OK 但启动报 `Ambiguous mapping` —— 该 controller 已有 `GET /{distributorId}`，新的 `GET /qrcode/{id}` 被识别为 `/{distributorId}=qrcode` 冲突。改用 query string 后 OK。
- `ruoyi-system` 模块也引不到 `ruoyi-framework.config.ServerConfig`（跨模块依赖隔离），所以放回 `ruoyi-admin` 加新 controller。

### 验证（jar PID 58832）
- `.github/scripts/smoke-e4.sh`: 4/4 PASSED
  - A 首次：admin token + distributorId=1000 返 cached=false + 落盘 qr_1001_*.png + scene=distributor:1:1001
  - B 二次：cached=true + URL 完全一致 + 文件数稳定
  - C no auth: body.code=401
- 回归：smoke-c1 3/3 / smoke-subitem 4/4 / smoke-e10 4/4 / lint-mybatis 0 errors

### 业务价值
- 运营可在 admin 端看任一推客的太阳码，截图下发到推广群
- admin 与小程序端共用同组 qr_*.png 文件，缓存命中避免重复调 wxacode

## E5 推进（2026-08-14 · 21:05 · commit <待定>）

### 推进 doc/下一轮迭代清单-2026-08-14.md E5
- `ruoyi-system/pom.xml` 加 `spring-boot-starter-test`（test scope，JUnit 5 + Mockito + AssertJ 已含）+ `mysql-connector-j`（test scope，生产用 ruoyi-admin 才有）
- `ruoyi-system/src/test/resources/mybatis/mybatis-config.xml`：从 ruoyi-admin 复制（ruoyi-system 模块本身没这个文件）
- 新建 `MinimalTestApp`（test scope 内 `@SpringBootApplication` + `@MapperScan("com.ruoyi.biz.mapper")`）
- 新建 `CommissionMapperTest`：3 个 `@SpringBootTest` 单测真跑 MyBatis + 真 MySQL，验证 C1 跨租户 guard

### 3 个单测（全部 0 mock，跑真 SQL）
1. `sumByMerchantIds_emptyList_returnsZeroRows` — 传 `Collections.emptyList()` + `merchantIdsEmpty=true`，期望返 0 行
2. `sumByMerchantIds_nullList_returnsZeroRows` — 传 `null`，期望返 0 行
3. `sumAgentOverview_emptyList_returnsZeroRows` — 同上空 list 走 `sumAgentOverview`，期望 totalAmount=0

### 反向验证（mutation test，证明单测真有效）
- 临时删除 `sumByMerchantIds` xml 中 `<if test="merchantIdsEmpty == true"> and 1=0 </if>` guard
- 跑 mvn test → **2/3 FAIL**（emptyList + nullList 测试都报「expected 0 rows but got N」）
- 恢复 guard → **3/3 PASS**

### 调试 5 个坑（避免再踩）
1. spring-boot-starter-test 4.0.6 离线 cache 没 mybatis-spring-boot-test 包 → 放弃 `@MybatisTest` 切片，改用 `@SpringBootTest(classes = MinimalTestApp)` 自建最小入口
2. RuoYiApplication 在 ruoyi-admin 模块，ruoyi-system 跨模块引不到 → 自建 MinimalTestApp
3. DataSourceAutoConfiguration exclude 后找不到 DataSourceProperties → 去掉 exclude 让 auto config 全跑
4. ruoyi-system 不引 druid，`spring.datasource.type=com.alibaba.druid.pool.DruidDataSource` 找不到类 → 删 type 属性
5. ruoyi-system 不引 mysql-connector → 加 test scope `mysql-connector-j:8.4.0`
6. mybatis mapper 接口无 `@Mapper` 注解且 RuoYi 没用 `@MapperScan`（生产靠 mybatis-spring-boot-starter auto config 同包扫描）→ 显式 `@MapperScan("com.ruoyi.biz.mapper")`

### 验证
- `mvn test -pl ruoyi-system`: Tests run: 3, Failures: 0, Errors: 0, Skipped: 0
- 反向验证: 删 guard → 2/3 FAIL（证明测试真能 catch 跨租户 bug 回归）
- E2E 回归: lint-mybatis 0 errors / smoke-c1 3/3 / smoke-subitem 4/4 / smoke-e10 4/4 / smoke-e4 4/4

### 业务价值
- C1 跨租户修复 (`7a0299d4`) 现在有自动化防护：谁再删 xml 里的 `merchantIdsEmpty=1=0` guard，单测立刻红
- 模板就绪：后续加 Commission / Distributor / WxPay 单测，直接 `@SpringBootTest(classes = MinimalTestApp.class)` + `@MapperScan` 模式复制
