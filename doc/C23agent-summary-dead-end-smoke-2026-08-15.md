# C23 /api/distributor/agent/summary dead-end smoke · 2026-08-15

## 目标
端到端验证 `/api/distributor/agent/summary` 端点对小程序端不可达,5/5 PASS。

## 关键发现 (设计死端)
**`/api/distributor/agent/summary` 在小程序端永远不可达**:
- `ApiAuthController.login` 创建 `LoginMember(Member)` 时**未写 userType** → 始终为 null
- `ApiDistributorController.agentSummary` 第 95 行 `!"1".equals(me.getUserType())` → 对任何 mini member 返 "仅代理商账号可调用" (code 500)
- TenantContextHolder 注入只在 admin 登录时发生,mini token 走 MemberAuthInterceptor 不会写
- **biz_member 表 schema 没有 user_type/agent_id 列** — 数据模型层就缺字段

## 端点覆盖
| # | 端点 | 预期 | 实际 |
|---|---|---|---|
| 1 | GET /api/distributor/agent/summary (mini member) | 拒绝 | "仅代理商账号可调用" code=500 ✅ |
| 2 | GET /api/distributor/agent/summary (无 token) | 401 | 401 ✅ |
| 3 | GET /biz/agent/commission/summary?agentId=1 (admin) | 200 | 200 + 数据 ✅ |

## 业务侧建议
代理商小程序端: 当前**没入口**。两种修复路线:
- **A. 改 admin 端** `/biz/agent/commission/summary` 走代理商登录 (c1 已验证 200)
- **B. 修 dead-end**: Member domain 加 userType/agentId + ApiAuthController.login 写 + agentSummary 改读 LoginMember (改动大, 4 个文件 + DB schema)

本项目当前**不修**, 文档化作为 known limitation。

## 全套回归
- 36/36 smoke PASS (含 C23)
- 10/10 JUnit PASS
- 30/30 vitest PASS
