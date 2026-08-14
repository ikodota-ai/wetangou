# C9 commission 冷静期真实结算链路 smoke · 2026-08-15

## 背景

C7 提现链路用 SQL 模拟冷静期结算（`UPDATE commission status=1 + distributor 金额调整`），
绕过了真实 Quartz `SettleCommissionTask` 链路。本轮**真正端到端**验证 commission 冷静期 +
Quartz 结算 + 推客金额联动，避免「生产 cron 跑挂了但 C7 还在 PASS」的危险假阳性。

## 设计

- 不写新 controller，**复用 RuoYi 原生 `PUT /monitor/job/run`**（`monitor:job:changeStatus` 权限），
  手动触发 `settle_commission_task` (jobId=4)。admin 角色直接拥有权限。
- 触发后走生产**完全相同**的代码路径：`SysJobService.run → QuartzScheduler.triggerJob → Job 反射到 settleCommissionTask.ryNoParams()`。
- 冷静期 7 天太慢，fixture 直接 `create_time = NOW - 8 day`，让 `settleExpiredCommissions` 一次命中。

## 8 case 验证

```
[A] member=999309 dist=999259 comm=999230 (frozen=12.80, comm 8 天前)
  [B] /monitor/job/run resp: {"msg":"操作成功","code":200}
  ✅ B Quartz 触发 HTTP 200
  ✅ C commission.status=1
  ✅ C settle_time=2026-08-15 04:09:03
  ✅ D frozen_amount=0
  ✅ D available_amount=12.80
  ✅ D total_commission=12.80
  ✅ E 幂等：二次触发无重复结算
  ✅ F 冷静期未到：comm 保持 status=0
```

| 维度 | 验证点 | 结果 |
|---|---|---|
| B | `/monitor/job/run` 触发成功 | ✅ |
| C | `commission.status 0→1` + `settle_time` 写入 | ✅ |
| D | `distributor.frozen_amount -= 12.80` / `available_amount += 12.80` / `total_commission += 12.80` | ✅ |
| E | 二次触发幂等（comm.status 已 1，SQL WHERE 不命中） | ✅ |
| F | `create_time = NOW` 的 comm 不被错误结算 | ✅ |

## 三重回归（21 + 10 + 30 = 61/61）

| 类型 | 范围 | 结果 |
|---|---|---|
| business smoke | c1~c9 + subitem | 9/9 |
| guard smoke | e4/e10/e11/e13~e19 + g6 | 12/12 |
| JUnit | ruoyi-system | 10/10 |
| vitest | miniprogram7 | 30/30 |

## 关键文件

- `.github/scripts/smoke-c9.sh` — 8 case 端到端 Quartz 触发验证
- 不改动业务代码（端到端复用现有 `PUT /monitor/job/run` + `SettleCommissionTask`）

## 业务价值

- **生产 cron 链路**被 smoke 覆盖（之前只有 SQL 模拟）
- 若有人改坏 `settleExpiredCommissions` / `linkSettlementToDistributor`，C9 立刻 fail
- 真正可在线上运维排错：手动 `/monitor/job/run` 触发冷静期结算
