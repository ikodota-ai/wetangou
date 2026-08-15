# C13 首页 Banner 链路 + 1 业务缺陷 · 2026-08-15

## 背景

C13 摸底发现 `biz_banner` 链路没有端到端 smoke（E18 只验了 tenant registry 注册，未验 API）。
本轮首次写 banner 端到端测试时**暴露 1 个 P0 业务缺陷**。

## 本轮修的 1 个 P0 缺陷

### 缺陷：banner 永远只返 ctx.merchantId=1 的数据
- **症状**：`GET /api/banner/list?merchantId=2` 返 `data:[]`，但 DB 里有 merchant_id=2 的 banner
- **根因**：
  - 8-15 E18 commit 把 `biz_banner` 加到 `TenantTableRegistry.ISOLATED_TABLES`（强隔离表）
  - 强隔离表 SQL 追加 `merchant_id = ctx.merchantId`
  - `ApiBannerController` 是 `@Anonymous`（小程序匿名），ctx 默认填 `merchantId=1`
  - 任何匿名端点拉 banner 都被强插 `merchant_id = 1`，`?merchantId=2` 永远返空
- **修复**：`biz_banner` 从强隔离表移到**共享表**
  - 共享表 SQL 追加 `merchant_id IN (0, ctx.merchantId)`，0 = 平台 banner
  - 与 `biz_voucher` 一样的语义（平台 + 商户混合）
- **影响**：所有小程序匿名 banner 拉取现在能拿到平台通用 banner

## 14 case 验证

```
C13 首页 Banner 链路 smoke:
  ✅ A home 默认匿名 200 + 包含 C13_home_m1
  ✅ A 仅 home 位置 / merchantId=NULL 隔离 merchantId=2
  ✅ B agent position 包含 C13_agent_m1
  ✅ C merchantId=1 包含 C13_home_m1 + 隔离
  ✅ D shared 语义: ctx=1 不含 merchantId=2 banner
  ✅ D shared 语义: 默认拉含 merchantId=1 banner
  ✅ E status=1 排除
  ✅ F sort 升序
  ✅ G mini 端 bannerList 已就绪
  ✅ H anonymous 200

C13 smoke: PASS=14 FAIL=0
```

| 维度 | 验证点 | 结果 |
|---|---|---|
| A | 匿名 home 位置 | ✅ |
| B | agent 位置 | ✅ |
| C | merchantId=1 隔离 | ✅ |
| D | shared 语义（IN 0, ctx） | ✅ |
| E | status 过滤 | ✅ |
| F | sort 排序 | ✅ |
| G | mini 端 api 已就绪 | ✅ |
| H | @Anonymous 端点 | ✅ |

## 三重回归（26 + 10 + 30 = 66/66）

| 类型 | 范围 | 结果 |
|---|---|---|
| business smoke | c1~c13 + subitem | 13/13 |
| E2E smoke | e4/e10/e11/e13~e19/e21 + g6 | 13/13 |
| JUnit | ruoyi-system | 10/10 |
| vitest | miniprogram7 | 30/30 |

## 关键文件

- `ruoyi-framework/.../tenant/TenantTableRegistry.java` — `biz_banner` 从强隔离移到共享
- `.github/scripts/smoke-c13.sh` — 14 case 端到端（用绝对路径避免 cd 影响）

## 业务价值

- 修了一个会让所有小程序 banner 拉取永远只返 merchantId=1 的 P0 bug
- banner 表的语义修正为「平台 + 商户混合」（与 voucher 一致）
- banner 链路首次端到端 smoke 覆盖
