# C30 v2 audit 收尾 + AGENTS.md 同步 · 2026-08-15

## 目标
完成 v2 audit 报告 (`doc/v2升级一致性审计-2026-08-14.md`) 列出的剩余 P1/P2/P3 项收尾:

## 完成项
| 项 | 状态 | 备注 |
|---|---|---|
| P1.3 admin 商品页字典化 | ✅ 已做 (C11 commit a173de17) | productType.js + v-for 替换 hardcode |
| P1.4 小程序商家端商品创建 page | ⏳ 跳过 (2-3 天工作量, 超本轮) | 待后续 v3 周期 |
| P1 sys_menu/perms (5 controller 缺) | ⏸️ 部分过时 — 5 controller 全是 mini 端不需 admin 菜单 | 已查 DB, 4/5 perms 已建 (商品类型/子品/协议) |
| P2.5 AGENTS.md 同步 | ✅ 本轮做 | 追加"续篇 2 (C19~C29) 11 commit"段 |
| P2.6 三方对账 | ✅ 实际已对齐 (SQL 11 种 = PRD 8 + COMBO + BILL + BOOKING) | admin 12 减 MONTH/QUARTER/YEAR 合并到 PERIOD_CARD |
| P2.5 删 `doc/抖音来客落地-今日交付.md` | ✅ git rm | 8-14 计划文档已过期 |
| P3.7 删 ApiPingController | ⏸️ 不过时 — C12 文档化为"健康检查" | miniprogram 启动探测用 |
| P3.8 miniprogram7/tests/ | ⏸️ 保留 (vitest 30 tests 持续 PASS) | 工具单测 |
| P3.9 .agents/ .playwright-cli/ | ✅ 已 gitignore | 早期 commit 985ccc26 已加 |

## 真实业务决策
1. **P1.4 商品创建 page** — 2-3 天工作量 + 涉及多端代码, 超出"摸底+修缺陷"范畴, 留 v3 周期
2. **P2.6 已对齐** — SQL 11 种字典已经按 PRD 8 + 3 顶层方式实装, admin 12 减 3 周期变体是设计上故意; **不动代码**
3. **P3.7 误判** — ApiPingController 不是调试用, 是 C12 文档化的 health check 端点, **保留**

## 摸出真实业务缺陷
本轮 0 (收尾工作, 不涉及代码改动)

## 全套回归 (C30 无新 smoke, 沿用 C29 基线)
- 40/40 smoke PASS
- 10/10 JUnit PASS
- 30/30 vitest PASS

## 剩余真实可推
1. **v2 P1.4 小程序商家端商品创建 page** (2-3 天)
2. **v3 周期规划** (登录入口 userType 路由分流 / admin 端代理商升级入口 / 完整 PRD 8 主流程)
3. **C26 dead-end 配套** — admin 端把普通 sys_user 升级为 biz_member.user_type=1+agent_id=N 的入口
