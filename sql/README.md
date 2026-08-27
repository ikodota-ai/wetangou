# sql/ 目录约定

脚本按**用途**分目录，避免「不知道服务器上该跑哪几个」。

| 目录 | 用途 | 服务器要跑吗 |
|---|---|---|
| `sql/` | 全新库初始化：建表 / 加列 / 菜单 / 字典种子 | **不要单独跑**，走 `sql/deploy/` |
| `sql/upgrade/` | 存量库增量迁移，每个都幂等 | **要**，见下 |
| `sql/archive/` | 一次性调试产物、分步试错版、纯查询校验脚本 | **不要跑** |
| `sql/deploy/` | 上面这些合并成的单文件成品（生成物） | 新库用这个 |

## 全新库

```bash
bash sql/deploy/init-all.sh <库名>            # 逐个脚本跑，失败能定位到文件
WITH_DEMO=1 bash sql/deploy/init-all.sh <库名> # 额外导演示数据（生产勿用）
```

或者用合并好的单文件（Navicat 友好，无 DELIMITER）：

```bash
mysql --default-character-set=utf8mb4 -uroot -p 库名 < sql/ry_20260417.sql
mysql --default-character-set=utf8mb4 -uroot -p 库名 < sql/quartz.sql
mysql --default-character-set=utf8mb4 -uroot -p 库名 < sql/deploy/wetuangou.sql
```

⚠️ `sql/biz_product_model_v2.sql` 会 `drop table` 重建 4 张表
（`biz_product_category` / `biz_product_type` / `biz_product_subitem` / `biz_product_subitem_group`），
**只能对空库执行**。已有数据的库一律走 `sql/upgrade/`。

## 存量库（已上线的服务器）

只跑 `sql/upgrade/` 里的，全部幂等、可重复执行：

```bash
for f in sql/upgrade/*.sql; do
  mysql --default-character-set=utf8mb4 -h<RDS> -u<user> -p 库名 < "$f" || echo "FAIL $f"
done
```

顺序无关（互不依赖），但建议按文件名里的版本号 v4 → v5 → v6 递增执行。

## 加新脚本时

- 改表结构 / 补菜单 / 修存量数据 → 放 `sql/upgrade/`，**同时**加进
  `sql/deploy/init-all.sh` 的「5.5 增量迁移」段和 `build-merged.py` 的 `BUSINESS` 列表，
  否则全新库会缺这部分（历史上 6 个脚本就是这么漏掉的）。
- 纯查询 / 校验 / 分步试错 → 放 `sql/archive/`，不要接进部署链。
- 改完任何被引用的脚本，跑 `python3 sql/deploy/build-merged.py` 重新生成
  `sql/deploy/wetuangou.sql`（那是生成物，别手工改）。
