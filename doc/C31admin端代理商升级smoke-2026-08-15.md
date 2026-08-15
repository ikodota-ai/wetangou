# C31 admin 端代理商升级入口 smoke · 2026-08-15

## 目标
C26 解锁 `/api/distributor/agent/summary` 后, 需要 admin 端把 biz_member 升级为代理商 (user_type=1, agent_id=N) 的入口。C31 补全这条链路。

## 端点
- `POST /biz/agent/upgrade?memberId=X&agentId=Y` — 升级为代理商
- `POST /biz/agent/upgrade/downgrade/{memberId}` — 降级

权限: `@PreAuthorize("@ss.hasPermi('biz:agent:upgrade:add/remove')")`

## 真实业务缺陷 × 1 (已修)
**根因**: C26 加 `Member.userType/agentId` 字段 + resultMap + selectMemberVo, 但**忘了 updateMember SQL**。
**症状**: API 返 200 但 DB 没真写 user_type/agent_id。
**修复**: MemberMapper.xml updateMember 加 2 列 + agent_id 用 `IF(#{agentId}=0, NULL, #{agentId})` 处理降级到 NULL 的边界。

```xml
<if test="userType != null">user_type = #{userType},</if>
agent_id = IF(#{agentId} = 0, NULL, #{agentId}),
```

controller 降级用 `setAgentId(0L)` 配合 SQL 的 IF 触发 NULL。

## smoke 验证 (C31 10/10)
| 用例 | 端点 | 验证 |
|---|---|---|
| A | /login admin | 200 + token |
| B | /api/auth/login mock | 200 + memberId |
| C | POST /biz/agent/upgrade (缺参) | "memberId 与 agentId 必填" |
| D | POST /biz/agent/upgrade?memberId=999999 | "会员不存在" |
| E | POST upgrade memberId=N agentId=1 | "升级成功" + DB user_type=1 agent_id=1 |
| E++ | 重复升级 | 200 (幂等) |
| F | POST downgrade memberId | "降级成功" + DB user_type=0 agent_id=NULL |
| G | POST upgrade 用 member token | 401 (RuoYi security 拦截) |

## 历史覆盖对比
- C26 解锁 dead-end (前端调用入口)
- C31 补 admin 端把 member 升级为代理商的入口 (后端操作入口)
- C26+ C31 一起完成代理商小程序端完整链路

## 业务侧影响
- **admin 端**: 现在可以 POST /biz/agent/upgrade 把 member 升级为代理商
- **小程序端**: 升级后 member 重新登录即获得 userType=1 + agentId=N, 可调 /agent/summary
- **降级**: 降级后失去代理商身份, /agent/summary 返 500 "仅代理商账号可调用"

## 全套回归
- 41/41 smoke PASS (含 C31)
- 10/10 JUnit PASS
- 30/30 vitest PASS
