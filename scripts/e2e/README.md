# 5 条 C 端客户旅程端到端验证脚本

本目录的 Java 工具用于在开发环境**临时打开 mock 走通 5 条 C 端客户旅程**后端链路。  
**生产环境绝不允许开启 mock**（`wx.miniapp.mockEnabled` / `wx.pay.mockEnabled` 必须为 false）。

## 准备

- 后端跑在 127.0.0.1:8080，MySQL 跑在 127.0.0.1:3306（root/133301）
- 编译：`javac -cp ~/.m2/repository/com/mysql/mysql-connector-j/9.6.0/mysql-connector-j-9.6.0.jar *.java`

## 5 条旅程（已验证全部走通）

| 旅程 | 链路 |
|---|---|
| 1 到店消费 | 微信登录 → 选商品 → 下单 → 预支付(mock) → 员工核销 |
| 2 预约到店 | 查询可用时段 → 会员报名 → 员工确认到店 |
| 3 邀请省钱 | A 申请推客 → B 携 inviteBy 登录 → B 下单 → A 得 10% 佣金(冻结) |
| 4 现场买单 | 顾客发起买单 → 员工确认 → 顾客支付 |
| 5 提现 | 冷静期到 → quartz 自动结算 → A 申请提现 |

## 使用

```bash
# 1. 打开 mock
java -cp .:~/.m2/repository/com/mysql/mysql-connector-j/9.6.0/mysql-connector-j-9.6.0.jar EnableMock
redis-cli -n 0 flushdb

# 2. 跑测试（见 doc/小程序API文档.md 中的端点）

# 3. 关 mock（验证完必做）
java -cp .:~/.m2/repository/com/mysql/mysql-connector-j/9.6.0/mysql-connector-j-9.6.0.jar DisableMock
```

## 已知测试账号

- `staff001 / admin123` — 春熙路餐饮员工，关联 store 200/101/100
- mock 用户：code 任意字符串（如 `e2e_journey1_user`），自动派生 openid
