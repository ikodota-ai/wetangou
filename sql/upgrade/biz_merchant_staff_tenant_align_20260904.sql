-- ===========================================================================
-- 修员工关联的商户归属：biz_merchant_staff.merchant_id 与门店真实归属对齐
--
-- 背景（生产真实故障）：biz_store.merchant_id 能在后台被单独改，而指向该门店的
-- biz_merchant_staff.merchant_id 不会跟着动（两表之间没有外键、没有联动）。
-- 于是出现「员工关联声明属于商户 A，但它绑的门店已经属于商户 B」的脏数据。
--
-- 后果链条很长且报错位置完全指错方向：
--   登录时只按 user_id 取 store_id，从不回查门店真实归属
--   → 脏 storeId 写进 token
--   → 商家端「适用门店」照常把这个门店列出来
--   → 老板勾上门店保存商品，直到 ProductServiceImpl.assertStoresBelongToMerchant
--     才抛「门店 X 不属于该商家」
--   → 现象看起来像「老板没有建品权限」，排查方向被彻底带偏。
--
-- 生产实际形态：门店 100 属于商户 100，三条员工关联(owner/manager/staff_c43)
-- 却停留在 merchant_id = 1（关联建立时挂的是商户 1，后来门店体系重建成商户 100）。
--
-- 幂等：以门店的 merchant_id 为准回填，重复执行不会有额外影响。
--
-- ⚠️ 执行后必须做两件事，否则改了库也不生效：
--   1. 清商户缓存（生产 Redis 是 db 3，缓存无 TTL）：
--      redis-cli -n 3 --scan --pattern 'merchant:*' | xargs -r redis-cli -n 3 DEL
--   2. 受影响的员工重新登录小程序 —— storeIds 是登录那一刻算进 token 的。
-- ===========================================================================

-- 【改前自检】将要被改动的行，先看清楚
select ms.id           as 关联ID,
       ms.user_id      as 用户ID,
       ms.role         as 角色,
       ms.merchant_id  as 现在声明的商户,
       s.merchant_id   as 门店真实商户,
       s.store_name    as 门店名称
from biz_merchant_staff ms
join biz_store s on s.store_id = ms.store_id
where ms.store_id is not null and ms.store_id <> 0
  and ms.merchant_id <> s.merchant_id;

-- 【对齐】以门店的真实归属为准
update biz_merchant_staff ms
join biz_store s on s.store_id = ms.store_id
set ms.merchant_id = s.merchant_id
where ms.store_id is not null and ms.store_id <> 0
  and ms.merchant_id <> s.merchant_id;

-- 【改后自检】应当返回 0 行
select count(*) as 仍不一致的关联数
from biz_merchant_staff ms
join biz_store s on s.store_id = ms.store_id
where ms.store_id is not null and ms.store_id <> 0
  and ms.merchant_id <> s.merchant_id;

-- 【另一类脏数据】绑了一个已经不存在的门店：无法自动修（不知道该挂哪个商户），
-- 只能人工确认后停用或改绑。这里只报出来。
select ms.id as 关联ID, ms.user_id as 用户ID, ms.store_id as 门店ID不存在, ms.merchant_id as 声明商户
from biz_merchant_staff ms
left join biz_store s on s.store_id = ms.store_id
where ms.store_id is not null and ms.store_id <> 0 and s.store_id is null;
