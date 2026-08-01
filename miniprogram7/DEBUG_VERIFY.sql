-- =====================================================================
-- 一键验证：「appid 配在商户了，但小程序还是看不到数据」
-- 跑这条 SQL，结果集前 3 行就能告诉你为什么
-- =====================================================================

SELECT
  -- 你配的 appid（带 HEX，方便看有没有不可见字符）
  m.merchant_id,
  m.merchant_name,
  CONCAT('appid=[', m.appid, '] len=', CHAR_LENGTH(m.appid),
         ' hex=', HEX(m.appid)) AS appid_detail,
  m.status AS merchant_status,
  CASE WHEN m.status='0' THEN '✅ 正常' ELSE '❌ 停用（status=1 导致 fallback）' END AS status_tip,
  -- 与小程序编译期 appid 比对（项目硬编码 wx9e147c4e2151b123）
  CASE WHEN m.appid = 'wx9e147c4e2151b123' THEN '✅ 一致'
       WHEN m.appid IS NULL OR m.appid = '' THEN '❌ appid 为空'
       ELSE '❌ 不一致：DB=[' + m.appid + '] ≠ 小程序=[wx9e147c4e2151b123]' END AS appid_match_tip
FROM biz_merchant m
WHERE m.del_flag = '0'
ORDER BY m.merchant_id;

-- 顺手看 store_id=200 挂哪个商户
SELECT store_id, store_name, merchant_id, status, del_flag
  FROM biz_store WHERE store_id = 200;
-- 期望：merchant_id 等于上表里你配了 appid 的那个 merchant_id
-- 异常：merchant_id=1 但上表 merchant_id=200 没配 appid → 数据挂错了
-- 异常：merchant_id=200 但上表 status=1 → 商户被停用
