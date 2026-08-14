# CI 集成 · test.yml workflow · 2026-08-15

## 背景

8-14 P3 计划里写「CI/CD 集成：macos-14 runner 缺 docker 暂不能端到端」。
本轮在已有 `build.yml` 基础上补 `test.yml`，覆盖静态 lint + 单元测试 + 前端 vitest。

## 设计约束

- **macos-14 runner 限制**：
  - 无 docker（无法跑 MySQL 5.7 镜像）
  - 无 mysql-client（无法 `mysql` CLI）
  - brew install mysql-client 需 5+ 分钟，超出 10min 预算
- **结论**：CI 端到端 smoke 不现实，退而求其次做：
  1. 静态 lint（任何 runner 都能跑）
  2. JUnit（不需要外部依赖）
  3. vitest（不需要外部依赖）
  4. 端到端 smoke 仍由开发者本地手跑

## 三个 lint 脚本

### 1) lint-mybatis.sh（已存在，本轮复用）
扫 `ruoyi-system/src/main/resources/mapper/**.xml`：
- 孤立 `</mapper>` 之后内容（e5fc6735 类 bug 守门）
- XML 合法性（ElementTree 解析）
- namespace 唯一性

### 2) lint-smoke.sh（本轮新增）
扫 `.github/scripts/smoke-*.sh` 共 25 个：
- shebang `#!/usr/bin/env bash` 存在
- `bash -n` 语法校验
- `trap cleanup EXIT` 模式（warning 不 fail）

### 3) lint-sql-seed.sh（本轮新增）
扫 `sql/*.sql`：
- 关键 seed 文件存在（biz_product_model_v2 / biz_merchant_v2 / biz_product_dict_charset_fix）
- INSERT 必有 `ON DUPLICATE KEY` / `INSERT IGNORE` / `REPLACE`（idempotent）

## test.yml workflow

```yaml
jobs:
  lint:        # MyBatis + Smoke + SQL seed lint
  backend-test: # mvn -B -ntp test -pl ruoyi-system
  mini-test:    # miniprogram7 vitest
```

3 job 串行（lint → backend + mini 并行），总耗时 ~3min。

## 模拟 CI 验证（本地手跑 5 步）

```
=== STEP 1: MyBatis lint ===
lint-mybatis: scanned 49 xml, errors=0

=== STEP 2: Smoke lint ===
smoke lint: total=25 fail=0

=== STEP 3: SQL seed lint ===
sql seed lint: total=17 fail=0

=== STEP 4: JUnit ===
[INFO] BUILD SUCCESS (10 tests PASS)

=== STEP 5: vitest ===
Test Files  3 passed (3)
     Tests  30 passed (30)
```

## 关键文件

- `.github/workflows/test.yml` — 3 job workflow (lint / backend-test / mini-test)
- `.github/scripts/lint-smoke.sh` — 25 smoke 脚本语法 + shebang + trap 校验
- `.github/scripts/lint-sql-seed.sh` — sql seed 完整性 + idempotent 校验
- `.github/workflows/build.yml` — 已有，复用 mybatis lint

## 业务价值

- PR / push 时 5 步自动验证（无人工成本）
- 任何 PR 改坏 mybatis XML / smoke 脚本 / SQL seed 立刻 fail
- 端到端 smoke 仍走开发者本地（10s/case × 25 = 4min）
- 后续加 GitHub Action self-hosted runner（macos + docker + mysql）即可开启真端到端 smoke
