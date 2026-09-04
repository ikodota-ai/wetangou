-- ============================================================
-- 诊断：门店换商户后残留的跨商户脏数据
--
-- 【何时用】商家端建品报「门店 X 不属于该商家，不能作为本商品的适用门店」，
--          且用老板账号也一样。
--
-- 【为什么会这样】biz_store.merchant_id 能被后台单独改掉（门店换商户），
--   但指向这家门店的两类记录各自还存着一份旧的 merchant_id，且没有外键联动：
--     - biz_merchant_staff：员工在职关联（决定登录后 token 里的 storeIds）
--     - biz_product.store_ids：商品适用门店
--   门店一转走，它们就变成「声明属于商户 A，指向的门店已属于商户 B」的脏数据。
--   登录时只按 user_id 取 store_id、从不回查门店真实归属，脏 storeId 被写进 token，
--   商家端「适用门店」照常列出来，商家勾上保存才在服务端门店归属校验处报错 ——
--   现象是「连老板都建不了商品」，病根却在几天前那次门店换商户，中间零提示。
--
-- 【注意】本脚本**只查不改**。看清结果后再从文件末尾挑一条修复语句手工执行。
-- 【不进部署链】一次性排障用，放 sql/archive/，init-all.sh 不引用。
-- ============================================================

-- ---------- 1. 员工关联 vs 门店真实归属 ----------
-- 有行返回 = 找到病根。这些员工登录后拿到的门店是别家商户的，建品必然被拦。
SELECT  ms.id            AS staff_link_id,
        ms.user_id,
        u.user_name,
        ms.role,
        ms.status        AS link_status,      -- 0在职 1离职 3待审核
        ms.merchant_id   AS link_merchant,    -- 关联声明的商户
        ms.store_id,
        s.store_name,
        s.merchant_id    AS store_merchant,   -- 门店当前实际所属商户
        '关联与门店归属不一致' AS problem
FROM    biz_merchant_staff ms
JOIN    biz_store s  ON s.store_id = ms.store_id
LEFT JOIN sys_user  u ON u.user_id  = ms.user_id
WHERE   ms.store_id <> 0                      -- store_id=0 表示「全商户」，不指向具体门店
  AND   s.merchant_id <> ms.merchant_id
ORDER BY ms.user_id, ms.store_id;

-- ---------- 2. 员工关联指向的门店已被删除 ----------
SELECT  ms.id AS staff_link_id, ms.user_id, ms.merchant_id AS link_merchant, ms.store_id,
        '指向的门店不存在' AS problem
FROM    biz_merchant_staff ms
LEFT JOIN biz_store s ON s.store_id = ms.store_id
WHERE   ms.store_id <> 0 AND s.store_id IS NULL;

-- ---------- 3. 商品适用门店 vs 门店真实归属 ----------
-- 这类脏数据的后果：原商户看不到该商品却仍要履约核销，新商户想下架也下不掉。
SELECT  p.product_id, p.product_name,
        p.merchant_id AS product_merchant,
        s.store_id, s.store_name,
        s.merchant_id AS store_merchant,
        '商品与适用门店跨商户' AS problem
FROM    biz_product p
JOIN    biz_store s ON FIND_IN_SET(s.store_id, p.store_ids)
WHERE   p.del_flag = '0'
  AND   s.merchant_id <> p.merchant_id
ORDER BY p.product_id;

-- ---------- 4. 单个账号的完整归属画像（排查具体某人时用） ----------
-- 把 :USER_NAME 换成实际账号，例如 'owner_c43'。
-- 三张表的 merchant_id 语义各不相同，混着看才知道哪一处对不上：
--   sys_user.merchant_id  —— 死列，恒为 0 且无人读（PC 端「所属商户」不写它）
--   biz_merchant_user     —— PC 后台数据权限用
--   biz_merchant_staff    —— 小程序商家版**唯一**依据（登录/建品都看它）
SELECT  u.user_id, u.user_name, u.user_type,
        u.merchant_id            AS sys_user_merchant_id_deadcol,
        mu.user_type             AS pc_user_type,
        mu.merchant_id           AS pc_merchant_id,
        ms.id                    AS staff_link_id,
        ms.merchant_id           AS mp_merchant_id,
        ms.store_id              AS mp_store_id,
        ms.role, ms.status,
        s.store_name,
        s.merchant_id            AS store_actual_merchant
FROM    sys_user u
LEFT JOIN biz_merchant_user  mu ON mu.user_id = u.user_id
LEFT JOIN biz_merchant_staff ms ON ms.user_id = u.user_id
LEFT JOIN biz_store          s  ON s.store_id = ms.store_id
WHERE   u.user_name = 'owner_c43';   -- ← 改成要排查的账号

-- ============================================================
-- 修复（看清上面结果后**手工挑一条**执行，不要整段跑）
--
-- 情形一：门店本就该留在原商户，是门店归属被误改
--   把门店改回去即可，员工关联和商品都不用动：
--     UPDATE biz_store SET merchant_id = <原商户ID> WHERE store_id = <门店ID>;
--
-- 情形二：门店确实要归新商户
--   那么原商户下指向它的员工关联和商品都必须处置，二者不能只做一半：
--     -- 2a) 员工改绑到新商户（人跟着门店走）
--     UPDATE biz_merchant_staff SET merchant_id = <新商户ID>
--      WHERE store_id = <门店ID> AND merchant_id = <原商户ID>;
--     -- 2b) 或者让员工留在原商户、解除对这家门店的关联（人不跟着走）
--     UPDATE biz_merchant_staff SET status = '1'
--      WHERE store_id = <门店ID> AND merchant_id = <原商户ID>;
--     -- 2c) 商品移除该适用门店（商品不能跨商户，必须由新商户重新上架）
--     --     store_ids 是逗号串，逐个确认后再改，别批量 REPLACE 误伤同前缀 ID
--
-- 改完必做：清商户缓存，否则 appid→商户的映射还是旧的
--   redis-cli DEL merchant:appid:<APPID> merchant:id:<商户ID>
-- 然后让相关员工在小程序里**重新登录**：storeIds 是登录时算进 token 的，
-- 不重登会继续用旧的那份。
-- ============================================================
