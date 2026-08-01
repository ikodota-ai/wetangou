-- ----------------------------
-- 商品「适用门店」：store_ids 存字典键值，多选逗号分隔（如 100,101）
-- 说明：保留 store_id 作为主门店（用于下单归属/兼容），store_ids 为适用门店集合
-- 导入：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_product_stores.sql
-- ----------------------------
alter table biz_product add column store_ids varchar(500) default '' comment '适用门店ID集合（逗号分隔）' after store_id;

-- 已有数据：把主门店写进 store_ids（store_id>0 的）
update biz_product set store_ids = store_id where (store_ids is null or store_ids = '') and store_id is not null and store_id > 0;
