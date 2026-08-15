# C32 admin 端 BizStaffInviteController smoke · 2026-08-15

## 目标
admin 端商家邀请码 + 员工名单 9 端点端到端,14/14 PASS + 摸出/修复 1 个 P1 缺陷。

## 端点覆盖
| # | 端点 | 验证 |
|---|---|---|
| A | POST /login | admin token |
| B | GET /biz/staffInvite/list | 分页 total ✅ |
| C | GET /biz/staffInvite/{id} | 详情 inviteCode=STAFF001 ✅ |
| D | POST add (带 scene) | 落库 inviteId ✅ |
| D- | POST add (不带 scene) | **P1 修复** 自动生成 scene ✅ |
| E | PUT edit (改 remark) | DB remark=C32_EDIT ✅ |
| F | DELETE /biz/staffInvite/{id} | DB 删除 ✅ |
| G | GET /biz/staffInvite/staff/list | 员工分页 ✅ |
| H | GET /biz/staffInvite/qrcode/{id} | 落盘 png + scene ✅ |
| I | member token 越权 | 401 ✅ |

## 真实业务缺陷 × 1 (已修)
**根因**: biz_merchant_staff_invite.scene 字段 NOT NULL, 客户端 add 时未传 scene → SQL 异常 "Field 'scene' doesn't have a default value"
**修复** (1 处 controller):
```java
if (invite.getScene() == null || invite.getScene().isEmpty()) {
    invite.setScene("invite:" + invite.getMerchantId() + ":" + invite.getStoreId() + ":AUTO");
}
```
**验证**: 不传 scene 也能成功生成邀请码 + 自动 wxacode 落盘

## 历史覆盖对比
- c11 走过商家端商品创建 (3 P1 缺陷), 但**没摸 admin 端 staffInvite 9 端点**
- C32 首次独立覆盖 0→9 端点 + 摸出 scene 缺默认 P1 缺陷

## 全套回归
- 42/42 smoke PASS (含 C32)
- 10/10 JUnit PASS
- 30/30 vitest PASS
