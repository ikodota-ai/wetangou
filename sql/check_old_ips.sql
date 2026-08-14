-- 检查数据库里所有 IP 形式存储的图片 URL
SELECT 'biz_product.cover' AS col, COUNT(*) AS bad_count
  FROM biz_product
  WHERE cover LIKE 'http://172.31.26.216%' OR cover LIKE 'http://192.168.1.136%';

SELECT 'biz_product.images' AS col, COUNT(*) AS bad_count
  FROM biz_product
  WHERE images LIKE 'http://172.31.26.216%' OR images LIKE 'http://192.168.1.136%';

SELECT 'biz_store.logo' AS col, COUNT(*) AS bad_count
  FROM biz_store
  WHERE logo LIKE 'http://172.31.26.216%' OR logo LIKE 'http://192.168.1.136%';

-- 修复：把历史 IP 替换为相对路径（前端会通过 request URL 自动补全）
UPDATE biz_product SET cover = REPLACE(REPLACE(REPLACE(cover, 'http://172.31.26.216:8080', ''), 'http://192.168.1.136:8080', ''), 'http://127.0.0.1:8080', '')
  WHERE cover LIKE 'http://172.31.26.216%' OR cover LIKE 'http://192.168.1.136%' OR cover LIKE 'http://127.0.0.1%';

UPDATE biz_product SET images = REPLACE(REPLACE(REPLACE(images, 'http://172.31.26.216:8080', ''), 'http://192.168.1.136:8080', ''), 'http://127.0.0.1:8080', '')
  WHERE images LIKE 'http://172.31.26.216%' OR images LIKE 'http://192.168.1.136%' OR images LIKE 'http://127.0.0.1%';

UPDATE biz_store SET logo = REPLACE(REPLACE(REPLACE(logo, 'http://172.31.26.216:8080', ''), 'http://192.168.1.136:8080', ''), 'http://127.0.0.1:8080', '')
  WHERE logo LIKE 'http://172.31.26.216%' OR logo LIKE 'http://192.168.1.136%' OR logo LIKE 'http://127.0.0.1%';

-- 验证：再次检查
SELECT 'after_fix_bad_count' AS col, COUNT(*) AS cnt
  FROM biz_product
  WHERE cover LIKE 'http://172.31.26.216%' OR cover LIKE 'http://192.168.1.136%';
