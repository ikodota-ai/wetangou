# 部署 SQL 导入指南

## 只需按顺序跑 3 个文件

| 顺序 | 文件 | 内容 |
|---|---|---|
| 1 | `sql/ry_20260417.sql` | RuoYi 基础表（用户/角色/菜单/字典/配置） |
| 2 | `sql/quartz.sql` | 定时任务表 |
| 3 | `sql/deploy/wetuangou.sql` | **全部业务内容**（建表 + v2 商品模型 + 代理商/会员/预约 + 260 个菜单 + 字典种子） |

```bash
mysql -uroot -p -e "CREATE DATABASE \`ry-vue\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"

mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/ry_20260417.sql
mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/quartz.sql
mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/deploy/wetuangou.sql
```

生产环境再补一个配置模板：

```bash
mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/deploy/sys_config_production.sql
```

演示/测试环境可选（**生产不要跑**）：

```bash
mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/deploy/wetuangou-demo.sql
```

导完最后一句会打印统计，`bad_parent_should_be_0` 必须是 0。默认管理员 `admin / admin123`。

## 用 Navicat / DBeaver 等 GUI

1. 新建库，字符集选 `utf8mb4`，排序规则 `utf8mb4_general_ci`
2. 右键库 → **运行 SQL 文件**，按上表顺序选文件，**编码选 `utf-8` / `utf8mb4`**（选错中文会乱码）
3. `wetuangou.sql` 里含 2 处 `DELIMITER`（定义 3 个幂等加列助手过程）。
   Navicat 的「运行 SQL 文件」支持 DELIMITER；如果你的客户端报错，
   改用命令行 `mysql < 文件` 即可。

## 注意

- **顺序不能换**：`wetuangou.sql` 依赖前两个文件建好的表
- **幂等**：3 个文件都可重复执行（已实测连跑两遍无报错）
- **只对空库/新库执行**：脚本内含 `drop table`，会清掉同名业务表
- 导入后请登录后台确认侧边栏「团购运营」下有 **6 个分组共 25 个页面**

## 文件怎么来的

`wetuangou.sql` 由 `sql/deploy/build-merged.py` 从 `sql/*.sql` 按实测顺序自动合并生成，
**不要手改**。改了源脚本后重新生成：

```bash
python3 sql/deploy/build-merged.py
```

合并时做了三件事：
1. 6 个源文件各自用 `DELIMITER` 定义近似的「幂等加列」过程 → 统一成开头定义一次，末尾统一清理
2. `biz_product_industry_sync_safe.sql` 的游标过程等价改写为一条 `UPDATE`（少一处 DELIMITER）
3. 剔除 `USE xxx;`（库名由连接决定，避免误写到别的库）

`sql/deploy/init-all.sh` 是等价的 shell 版本（逐文件打印 OK/FAIL，便于排错），保留备用。

## 验证过什么

空库依次导入 3 个文件后，与 `init-all.sh` 逐项对比：

- 表结构 **900 列逐行一致**
- `sys_menu` **260 行逐行一致**（menu_name / menu_type / perms / path / component）
- `sys_role_menu` 451 / `biz_product_type` 11 / `biz_product_category` 94 / `sys_dict_data` 34 全一致
- 真后端指向该库启动：`/getRouters` 200，团购运营下 6 分组 25 页；16 个后台列表接口全 200
