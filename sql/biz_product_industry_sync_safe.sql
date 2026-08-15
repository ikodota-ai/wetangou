-- ============================================================
-- biz_product.industry_code 同步脚本 (MySQL 5.7 兼容版)
-- ============================================================
-- 背景: 原 sql/biz_product_seed.sql 第 9 步用 `UPDATE ... JOIN` 语法
--       MySQL 5.7.10 不支持 (需 8.0.19+) → 同步失败 → 8 行 product 的
--       industry_code 仍为空，违反 P1 字典化质量要求。
--
-- 产品级标准:
--   1. 幂等可重跑 (基于 WHERE 条件 + 游标替代 JOIN)
--   2. 字符集正确 (SET NAMES utf8mb4 + connection charset)
--   3. 安全默认值 (找不到映射时用 'OTHER' 而非 NULL)
--   4. 业务断言 (R1 行数检查，便于 CI 集成)
--
-- 依赖: 已存在 biz_product + biz_product_category 表
--       biz_product_category.industry_code 已有值 (CATERING/DINING/...)
-- 用法: mysql -h127.0.0.1 -uroot -p133301 ry-vue < biz_product_industry_sync_safe.sql
-- ============================================================

SET NAMES utf8mb4;
SET @db := DATABASE();

-- 1) 临时映射表：从 biz_product_category 提取 (category_id-10000 → industry_code) 映射
DROP TEMPORARY TABLE IF EXISTS tmp_cat_industry;
CREATE TEMPORARY TABLE tmp_cat_industry (
    legacy_category_id INT PRIMARY KEY,
    industry_code      VARCHAR(50) NOT NULL
) ENGINE=Memory;

INSERT INTO tmp_cat_industry (legacy_category_id, industry_code)
SELECT category_id - 10000, industry_code
FROM biz_product_category
WHERE category_id BETWEEN 10000 AND 19999
  AND industry_code IS NOT NULL
  AND industry_code <> '';

-- 2) 游标式 UPDATE (MySQL 5.7 兼容)
DROP PROCEDURE IF EXISTS sync_industry_code;
DELIMITER //
CREATE PROCEDURE sync_industry_code()
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE v_pid BIGINT;
    DECLARE v_cid BIGINT;
    DECLARE v_cur CURSOR FOR
        SELECT product_id, category_id
        FROM biz_product
        WHERE industry_code IS NULL OR industry_code = '';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN v_cur;
    read_loop: LOOP
        FETCH v_cur INTO v_pid, v_cid;
        IF done = 1 THEN LEAVE read_loop; END IF;

        UPDATE biz_product p
        JOIN tmp_cat_industry m ON m.legacy_category_id = v_cid
        SET p.industry_code = m.industry_code
        WHERE p.product_id = v_pid;
    END LOOP;
    CLOSE v_cur;
END//
DELIMITER ;

CALL sync_industry_code();
DROP PROCEDURE sync_industry_code;

-- 3) 兜底：未匹配到的置 'OTHER' (保证 NOT NULL 约束或业务展示正常)
UPDATE biz_product
SET industry_code = 'OTHER'
WHERE industry_code IS NULL OR industry_code = '';

-- 4) 业务断言 (CI 集成)
SELECT 'biz_product_industry_sync_safe' AS step,
       COUNT(*)                           AS total,
       SUM(CASE WHEN industry_code = '' OR industry_code IS NULL THEN 1 ELSE 0 END) AS empty_industry,
       SUM(CASE WHEN industry_code = 'OTHER' THEN 1 ELSE 0 END) AS other_fallback
FROM biz_product;
