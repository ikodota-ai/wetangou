-- ============================================================
-- 首页 banner 种子数据（演示用，真阿里云 OSS 图片）
-- ============================================================
-- 用法：
--   mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_banner_home_seed.sql
--
-- 前提：
--   1) 已执行 sql/deploy/sys_config_production.sql（或商户 wx.* 配置已就位）
--   2) 已上传演示图到 OSS（参考 AGENTS.md 部署章节）
--   3) merchant_id=1 是 demo 商户（洞天团购）
-- ============================================================

-- 清空旧演示 banner
DELETE FROM biz_banner WHERE merchant_id = 1 AND position = 'home' AND title LIKE '%双人火锅%';
DELETE FROM biz_banner WHERE merchant_id = 1 AND position = 'home' AND title LIKE '%代金券%';
DELETE FROM biz_banner WHERE merchant_id = 1 AND position = 'home' AND title LIKE '%组合券包%';

-- 3 张 banner（点击跳商品详情）
INSERT INTO biz_banner
  (merchant_id, position, title, image_url, link_url, status, sort, create_by, create_time)
VALUES
  (1, 'home', '云南野生菌双人火锅套餐',
     'https://wetuango.oss-cn-shenzhen.aliyuncs.com/2026/08/17/RestaurantImg_20260817172226A004.png',
     '/pages/goods/detail/index?id=999534',
     '0', 1, 'admin', NOW()),
  (1, 'home', '100 元代金券 / 满 200 可用',
     'https://wetuango.oss-cn-shenzhen.aliyuncs.com/2026/08/17/GoodsImg_20260817172230A005.jpg',
     '/pages/goods/detail/index?id=999535',
     '0', 2, 'admin', NOW()),
  (1, 'home', '超值组合券包 / 一次购买分次核销',
     'https://wetuango.oss-cn-shenzhen.aliyuncs.com/2026/08/17/banner1_20260817172230A006.jpg',
     '/pages/goods/detail/index?id=999536',
     '0', 3, 'admin', NOW());

-- 验证
SELECT banner_id, title, image_url, link_url, sort
FROM biz_banner WHERE position='home' ORDER BY sort;
