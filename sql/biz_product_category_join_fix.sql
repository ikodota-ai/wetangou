-- ============================================================================
-- 商品分类归一：把商品/佣金规则的 category_id 从 biz_category 迁到 biz_product_category
--
-- 背景（为什么要这个脚本）：
--   系统里有两张分类表，职责本该不同：
--     * biz_product_category —— 平台级「行业品类」多级树，带 industry_code /
--       allowed_types / deposit_amount / license_required。
--       商品高级编辑页第 1 步的「商品品类」级联选择器、后台「商品分类」菜单
--       （menu_id=2032，component=biz/category/index）用的都是这张表。
--     * biz_category —— 早期的商户/门店级自定义分组（只有 name/icon/sort +
--       merchant_id/store_id），用于小程序点单页左侧导航那种分组。
--
--   但 ProductMapper.xml / CommissionRuleMapper.xml 一直 join 的是 biz_category，
--   而 category_id 实际来自 biz_product_category —— 两张表 ID 空间独立，
--   于是新建商品在列表页「商品分类」列显示为空；
--   更危险的是 ID 会撞车：biz_category 里 100='套餐'，
--   将来 biz_product_category 自增到 100 时是另一个东西，会显示成不相干的分类。
--
--   现已把两处 join 改为 biz_product_category。本脚本负责把存量数据对齐，
--   否则那些老商品改完 join 后分类名会变空。
--
--   biz_category 目前没有任何写入入口（mapper 里只有 join，无 insert/update/delete），
--   小程序端也不读它，属于遗留表，故只迁引用、不动它本身。
--
-- 幂等：只更新「在 biz_category 命中、且在 biz_product_category 不命中」的行，
--       重复执行不会产生额外变更。
-- ============================================================================

-- 1) 商品：老 category_id → biz_product_category 中的同名二级品类
--    映射依据是两表同名分类（100 套餐→10100 套餐，200 野生菌套餐→10200 …）
UPDATE biz_product p
  JOIN biz_category      old_c ON old_c.category_id = p.category_id
  JOIN biz_product_category new_c
       ON new_c.category_name = old_c.category_name
      AND new_c.level = 2
  LEFT JOIN biz_product_category chk ON chk.category_id = p.category_id
SET p.category_id = new_c.category_id
WHERE chk.category_id IS NULL;

-- 2) 佣金规则：同样的迁移（当前数据 category_id 全为 NULL，此处为将来兜底）
UPDATE biz_commission_rule r
  JOIN biz_category      old_c ON old_c.category_id = r.category_id
  JOIN biz_product_category new_c
       ON new_c.category_name = old_c.category_name
      AND new_c.level = 2
  LEFT JOIN biz_product_category chk ON chk.category_id = r.category_id
SET r.category_id = new_c.category_id
WHERE chk.category_id IS NULL;

-- 3) 校验：期望 0 行。非 0 说明还有 category_id 落在 biz_product_category 之外，
--    需要人工确认该分类应归到哪个行业品类。
SELECT p.product_id, p.product_name, p.category_id
FROM biz_product p
LEFT JOIN biz_product_category c ON c.category_id = p.category_id
WHERE p.category_id IS NOT NULL
  AND p.category_id <> 0
  AND c.category_id IS NULL;
