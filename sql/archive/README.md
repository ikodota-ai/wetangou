# archive —— 一次性脚本，不要执行

这里的脚本都已被正式版取代，只作为排查历史问题时的线索保留。

| 文件 | 当时用途 | 现在由谁承接 |
|---|---|---|
| `biz_merchant_v2_step1.sql` | `sys_user` 加 openid 的分步试错版 | `sql/biz_merchant_v2.sql` |
| `biz_merchant_v2_simple.sql` | 同上，无 PREPARE 版 | 同上 |
| `biz_product_model_v2_step2a.sql` | 只建 `add_column_if_missing` 过程 | `sql/biz_product_model_v2_safe.sql` |
| `v2_fix_sys_user_openid_null.sql` | 修一次跑挂留下的 `openid=''` | 正式脚本已改成 `DEFAULT NULL`，不会再有 |
| `check_old_ips.sql` | 查库里残留的内网 IP 图片地址 | 纯 SELECT，排查用 |
| `verify_v3.sql` | 校验 v3 字段有没有加上 | 纯 SELECT，排查用 |
