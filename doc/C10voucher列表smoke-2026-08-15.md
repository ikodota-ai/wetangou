# C10 voucher 列表/搜索/我的券 smoke · 2026-08-15

## 背景

C8 已覆盖「发券→领券→下单抵扣」核心链路，**但列表/搜索/我的券**未端到端验证。
C10 一次性补齐：admin 端 + 小程序端 + 跨会员隔离 + 按状态过滤。

## 本轮发现 2 个真实业务缺陷

### 缺陷 1：小程序「可领列表」无 voucherName 搜索参数
- **现状**：`GET /api/voucher/list?storeId=...` 只按 storeId 过滤
- **修复**：`ApiVoucherController.list` 加 `voucherName` 可选参数（与 admin /biz/voucher/list 对齐）
- **价值**：用户在「代金券」Tab 里能按关键字搜券（如「生日」「满减」）

### 缺陷 2：「我的代金券」返回缺 voucherName 字段
- **现状**：`MemberVoucherMapper` SQL 只查 `biz_member_voucher` 表，无 `voucher_name`
- **影响**：小程序「我的券」页面只能显示 `faceValue + threshold + expireTime`，**没券名**
- **修复**：
  - `MemberVoucher` 加 `voucherName` 字段（非持久化，靠 join 填充）
  - `MemberVoucherMapper.xml` 改 `selectMemberVoucherVo` SQL：LEFT JOIN `biz_voucher` 取 `voucher_name`
  - 修 where 子句列名 ambiguous（voucher_id / status 加 `mv.` 前缀）

## 19 case 验证

```
[init] A=999328 B=999329
[init] VA=999515 VB=999516 VC=999517 VD=999518(disabled)
  ✅ A admin 全量列表 (rows 包含 coupon_AAA_c10)
  ✅ A admin 全量列表 (rows 包含 coupon_BBB_c10)
  ✅ A admin 全量列表 (rows 包含 coupon_CCC_c10)
  ✅ B 搜索 coupon_BBB 命中
  ✅ B 搜索 coupon_BBB 排除其他
  ✅ C storeId=201 命中 coupon_CCC_c10
  ✅ C storeId=201 隔离
  ✅ D 小程序 storeId=200 命中 coupon_AAA_c10
  ✅ D 排除已停用券
  ✅ E 小程序搜索 coupon_BBB 命中
  ✅ E 小程序搜索隔离
  ✅ F A 领取 AAA (id=17)
  ✅ F B 领取 BBB (id=18)
  ✅ G A my 看到 coupon_AAA_c10
  ✅ G A my 隔离 B 的券
  ✅ G B my 看到 coupon_BBB_c10
  ✅ G B my 隔离 A 的券
  ✅ H status=0 排除已使用
  ✅ H status=1 看到已使用券

C10 smoke: PASS=19 FAIL=0
```

| 维度 | 验证点 | 结果 |
|---|---|---|
| A | admin 全量分页 | ✅ 3/3 命中 |
| B | admin voucherName LIKE 搜索 | ✅ |
| C | admin storeId 过滤 | ✅ |
| D | 小程序可领列表仅 status=0 | ✅ |
| E | 小程序 voucherName 搜索（新加参数） | ✅ |
| F | 跨会员领取 | ✅ |
| G | 跨会员 my 列表隔离 | ✅ |
| H | my 按 status 过滤（0未用/1已用/2过期） | ✅ |

## 三重回归（22 + 10 + 30 = 62/62）

| 类型 | 范围 | 结果 |
|---|---|---|
| business smoke | c1~c10 + subitem | 10/10 |
| guard smoke | e4/e10/e11/e13~e19 + g6 | 12/12 |
| JUnit | ruoyi-system | 10/10 |
| vitest | miniprogram7 | 30/30 |

## 关键文件

- `ruoyi-admin/.../api/ApiVoucherController.java` — list 端点加 voucherName 参数（3 行）
- `ruoyi-system/.../domain/MemberVoucher.java` — 加 voucherName 字段 + getter/setter
- `ruoyi-system/.../mapper/biz/MemberVoucherMapper.xml` — SQL join biz_voucher + where 加 mv. 前缀
- `.github/scripts/smoke-c10.sh` — 19 case 端到端验证
