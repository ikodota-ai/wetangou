# C26 /api/distributor/agent/summary dead-end 解锁 smoke · 2026-08-15

## 目标
修 C23 摸出的 dead-end: 代理商小程序端 `/api/distributor/agent/summary` 永远不可达
- biz_member 表缺 user_type/agent_id 列
- LoginMember(Member) 不读 userType/agentId
- agentSummary 从 TenantContextHolder 读 (mini 端没值) → 永远 500

## 真实业务修复 (4 文件 + 1 SQL)
| 文件 | 改动 |
|---|---|
| sql/biz_member_agent_identity.sql | ADD COLUMN user_type + agent_id + idx |
| ruoyi-system/biz/domain/Member.java | 加 2 字段 + getter/setter + toString |
| ruoyi-system/biz/api/domain/LoginMember.java | 加 agentId 字段 + LoginMember(Member) 读 userType/agentId |
| ruoyi-system/mapper/biz/MemberMapper.xml | resultMap + selectMemberVo 加 2 列 |
| ruoyi-admin/web/api/ApiDistributorController.java | agentSummary 改读 LoginMember.agentId |

## 端点验证 (C26 10/10)
| # | 端点 | 行为 |
|---|---|---|
| 1 | /api/auth/login (普通 member) | 200, user_type=0, agent_id=NULL |
| 2 | /api/distributor/agent/summary (普通) | 500 "仅代理商账号可调用" ✅ 防御保留 |
| 3 | DB 升级 user_type=1, agent_id=1 | 成功 |
| 4 | /api/auth/login 重新登录 | 200, info 含 userType/agentId |
| 5 | /api/distributor/agent/summary (代理商) | **200 + agentId=1 + merchantCount=1 + byMerchant 数据** ✅ |
| 6 | /api/auth/info | userType=1, agentId=1 |

## dead-end 解锁后真实业务响应
```json
{
  "agentId": 1,
  "merchantCount": 1,
  "beginTime": "2026-08-01 00:00:00",
  "endTime": "2026-08-15 12:04:18",
  "byMerchant": [
    {
      "merchant_id": 1,
      "total_amount": 142.80,
      "settled_amount": 62.80,
      "pending_amount": 80.00,
      "commission_count": 4
    }
  ]
}
```

## fixture / cleanup
- 用同 JSCODE 二次 login 拿新 token (读 DB 最新 userType/agentId)
- trap EXIT 还原 member.user_type='0', agent_id=NULL

## 全套回归
- 38/38 smoke PASS (含 C26)
- 10/10 JUnit PASS
- 30/30 vitest PASS

## 业务侧影响
- **小程序前端**: 代理商登录后, /agent/summary 真实可用, 可渲染本月佣金概览 + 名下商户列表
- **数据模型**: 会员表多 2 列 (varchar(2) + bigint(20)), 加 (user_type, agent_id) 联合索引
- **向后兼容**: 现有 member.user_type 默认 '0' (普通), 行为不变
- **运营侧**: admin 端要把代理商账号 upgrade 为 user_type=1 + agent_id=N (建议写一个 admin 端升级入口, 本次未做)
