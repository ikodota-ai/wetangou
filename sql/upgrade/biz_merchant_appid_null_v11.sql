-- ============================================================================
-- 修复：不填 appid 的商户从第二个起就建不出来
--
-- 根因：biz_merchant.appid 是 UNIQUE KEY（uk_appid），列默认值又是 ''。
--      MySQL 唯一索引允许多个 NULL，但不允许多个 ''。于是：
--        · 第一个不填小程序 appid 的商户 → 落 ''，建成功
--        · 第二个不填的 → Duplicate entry '' for key 'uk_appid'，整个新增 500
--      而「先建商户、等商家提供小程序资质后再回来配 appid」是最常见的开通顺序，
--      实测本地商户 203 落了 '' 之后，再建任何不带 appid 的商户都直接失败。
--
-- 代码侧已修：
--   · MerchantServiceImpl.normalizeAppid 空 appid 落 NULL（并 trim 掉粘贴带的空格）
--   · 显式提交空 appid（解绑小程序）走 MerchantMapper.clearAppid 置 NULL
--     —— updateMerchant 的动态 set 是 <if appid != null>，置 null 那行不会生成，清不掉
--
-- 本脚本负责存量数据：把已经落成 '' 的 appid 洗成 NULL。
-- 同时把列默认值改成 NULL，避免以后再有代码/工具插出空串。
--
-- 幂等：可重复执行。
-- ============================================================================

-- 1) 空串 appid 洗成 NULL（多个 NULL 不冲突唯一索引）
UPDATE biz_merchant SET appid = NULL WHERE appid = '';

-- 2) 顺带把首尾带空格的 appid trim 掉：带空格的 appid 匹配不上任何小程序请求，
--    表现为「后台明明配了 appid，小程序却一直拿默认商户数据」
UPDATE biz_merchant
SET appid = TRIM(appid)
WHERE appid IS NOT NULL AND appid <> TRIM(appid);

-- 3) 列默认值由 '' 改为 NULL，从源头堵住空串
ALTER TABLE biz_merchant
    MODIFY COLUMN appid varchar(32) DEFAULT NULL COMMENT '小程序AppId（未配置时必须为 NULL，uk_appid 唯一索引不容许多个空串）';

-- 4) 校验：执行后应为 0 行
-- SELECT merchant_id, merchant_name FROM biz_merchant WHERE appid = '';
