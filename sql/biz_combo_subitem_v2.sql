-- 续篇 7 · 组合券包子品类型字段
-- 抖音来客截图 271：组合券包"商品搭配"每条搭配有类型下拉：团购套餐/代金券/满减券/折扣券
-- 抖音来客截图 273：填好态（团购套餐·团购 + 代金券·代金券）

ALTER TABLE biz_product_subitem
  ADD COLUMN subitem_type VARCHAR(20) DEFAULT 'GROUPON' COMMENT '子品类型（团购套餐/代金券/满减券/折扣券；组合券包用）' AFTER group_id,
  ADD COLUMN pick_quantity INT DEFAULT 1 COMMENT '份数（组合券包每条搭配的份数）' AFTER quantity,
  ADD COLUMN total_value DECIMAL(10,2) DEFAULT NULL COMMENT '总价值/划线价（组合券包整体划线价）' AFTER price;

-- 历史数据兜底
UPDATE biz_product_subitem SET subitem_type = 'GROUPON' WHERE subitem_type IS NULL;
UPDATE biz_product_subitem SET pick_quantity = quantity WHERE pick_quantity IS NULL OR pick_quantity = 0;
