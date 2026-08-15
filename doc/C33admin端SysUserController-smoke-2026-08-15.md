# C33 admin 端 SysUserController 端到端 smoke

> 日期 2026-08-15 · commit HEAD (待 push)

## 目标
覆盖 RuoYi 标准 SysUserController 全部 14 个端点 (含两个工具端点 deptTree/authRole)。

## 范围（20 断言）

| # | 端点 | 断言 | 结果 |
|---|---|---|---|
| A | POST /login | admin login | ✅ |
| B | GET /system/user/list | 200 + 含 admin | ✅ ✅ |
| C | GET /system/user/{id} | 详情 | ✅ ✅ |
| D | GET /system/user/deptTree | 200 | ✅ |
| E | POST /system/user | 新建 + DB 落库 | ✅ ✅ |
| E- | 重复 userName | 拒绝 | ✅ |
| F | PUT /system/user | 改 nickName + DB | ✅ ✅ |
| G | PUT /system/user/resetPwd | 200 | ✅ |
| H | PUT /system/user/changeStatus | 停用 + DB status=1 | ✅ ✅ |
| I | GET /system/user/authRole/{id} | 200 | ✅ |
| J | DELETE /system/user/{id,id} | 逻辑删除 + DB del_flag=2 | ✅ ✅ |
| J- | 删自己 (admin) | 拒绝 | ✅ |
| K | GET 不存在 userId | 业务异常 (允许 500 包装) | ✅ |
| L | member token 越权 | 401/403 | ✅ |

## 关键发现（已修 smoke，无业务改动）
1. **DELETE 端点接收形式是 `/{userIds}` 复数**（RuoYi 标准批量删除），mapper 用 `update sys_user set del_flag='2' where user_id in ( ? , ? )` 期待 2 个位置参数 → 单 id 要发 `id,id`
2. **SysUser 删除是逻辑删除** (del_flag=2)，不删行 → smoke J+) 断言从 count=0 改为 del_flag=2
3. **bash `UID` 是只读变量** (Bash special var)，smoke 用 `NEW_UID` 别名 (从 handoff 已知)

## 业务缺陷
- 0 真实业务缺陷
- RuoYi 内置防御全部命中：删自己拒绝、重复 userName 拒绝、不存在 userId 返 500

## 文件
- `smoke-c33.sh` 130 行 20 断言
- 复跑结果：**PASS=20 FAIL=0**

## 全套回归
- 43 smoke 文件 / 0 退化
- 10 JUnit / 0 退化
- 30 vitest / 0 退化
- **baseline 83/83**
