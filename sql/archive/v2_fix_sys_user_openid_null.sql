-- 修复 sql/biz_merchant_v2.sql 跑失败遗留的 openid 空字符串问题
-- 场景：之前已经 ADD COLUMN openid DEFAULT '' 成功，sys_user 多行 openid=''
-- 改法：把空字符串 UPDATE 成 NULL（MySQL UNIQUE 允许多个 NULL）

-- 1) 看现状
SELECT
  COUNT(*) AS total_rows,
  SUM(openid IS NULL)     AS null_count,
  SUM(openid = '')        AS empty_string_count,
  SUM(openid IS NOT NULL AND openid != '') AS bound_count
FROM sys_user;

-- 2) 修复：把空字符串刷成 NULL
UPDATE sys_user SET openid = NULL WHERE openid = '';
-- 受影响行数应 = 上面的 empty_string_count
SELECT ROW_COUNT() AS fixed_rows;

-- 3) 验证
SELECT
  COUNT(*) AS total_rows,
  SUM(openid IS NULL)     AS null_count,
  SUM(openid = '')        AS empty_string_count
FROM sys_user;
-- empty_string_count 应=0
