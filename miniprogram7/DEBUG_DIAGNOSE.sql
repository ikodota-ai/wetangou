-- =====================================================================
-- 小程序拿不到门店？执行这 5 步定位
-- 在 MySQL 客户端里跑（数据库名 ry-vue，账号 root/root）
-- 每一步的「期望」如果对不上，就是根因
-- =====================================================================

-- ===== 第 1 步：看默认商户 1 现在的 appid 是什么 =====
SELECT merchant_id, merchant_name, appid, mp_auth_mode, status, del_flag
  FROM biz_merchant WHERE merchant_id = 1;
-- 期望：appid = 'wx9e147c4e2151b123'（或至少与第 2 步里小程序编译 appid 一致）
-- 异常：appid = '' 或 'NULL'  → 在后台「商户管理 → 微信配置」填上

-- ===== 第 2 步：看小程序编译期 appid =====
-- 打开 miniprogram7/project.config.json，搜 "appid": "wx..."
-- 期望：与第 1 步 biz_merchant.appid 完全一致
-- 异常：两边不一致  → 二选一改齐（推荐改 DB，因为门店都已挂到 merchant_id=1）

-- ===== 第 3 步：看 store_id=200 属于哪个商户 =====
SELECT store_id, store_name, merchant_id, status, del_flag
  FROM biz_store WHERE store_id = 200;
-- 期望：merchant_id = 1
-- 异常：merchant_id ≠ 1  → 要么把这条 store 改挂到 1，要么把 DB 里 appid 改成 store 200 所属商户的 appid

-- ===== 第 4 步：看所有 appid 重复情况（防止 B 商户占用 A 的 appid 命中） =====
SELECT merchant_id, merchant_name, appid, status
  FROM biz_merchant
 WHERE appid = 'wx9e147c4e2151b123'
    OR appid IS NOT NULL AND appid <> '';
-- 期望：只有 1 行（默认商户）
-- 异常：多行  → appid 重复，删除重复行的 appid

-- ===== 第 5 步：看 Redis 缓存（如果有 redis-cli） =====
-- redis-cli -h localhost KEYS 'merchant:appid:*'
-- 期望：merchant:appid:wx9e147c4e2151b123 存在且 value 不为空
-- 异常：缓存里没这条 key 但 DB 有 → 重启后端会自动重建缓存
-- 异常：缓存里有但 value 是空/缺失 → 删掉这条 key: redis-cli DEL merchant:appid:wx9e147c4e2151b123

-- =====================================================================
-- 快速修复（确认是 appid 不匹配后）
-- =====================================================================

-- 方案 A：把默认商户的 appid 改成小程序编译期 appid
-- UPDATE biz_merchant SET appid = 'wx9e147c4e2151b123' WHERE merchant_id = 1;

-- 方案 B：把 store_id=200 改挂到默认商户
-- UPDATE biz_store SET merchant_id = 1 WHERE store_id = 200;

-- =====================================================================
-- 一键自愈（如果第 1 步 appid 是空，第 2/3 步还不对就跑这个）
-- =====================================================================

-- 1. 把默认商户 1 的 appid 强制改成 miniprogram7/project.config.json 里的 appid
UPDATE biz_merchant SET appid = 'wx9e147c4e2151b123' WHERE merchant_id = 1 AND (appid IS NULL OR appid = '');

-- 2. 把所有 store 强制挂到默认商户 1（演示用，不影响生产语义；生产环境按实际业务挂载）
-- UPDATE biz_store SET merchant_id = 1 WHERE merchant_id <> 1;

-- 3. 重启后端，让 Redis 缓存重建
--    pkill -f ruoyi-admin.jar
--    ./ry.sh start
