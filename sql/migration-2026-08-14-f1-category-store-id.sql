-- F1 修复 biz_product_category 表缺 store_id 列
-- 现象: CategoryController.getInfo 报 SQL 错 (Unknown column 'c.store_id' in 'field list')
-- 根因: v2 升级 (8-14) 表结构变更后, XML/Domain 引用 store_id 但 schema 未加列
-- 修法: ALTER TABLE biz_product_category ADD COLUMN store_id BIGINT(20) DEFAULT NULL
--       DEFAULT NULL 保证现有数据不受影响 (NULL=平台级/全门店)
-- 验证: E16 smoke Category 段 6/6 PASS (agent 别人 500 / 自己 200 / admin 200)
USE ry-vue;
ALTER TABLE biz_product_category
  ADD COLUMN store_id BIGINT(20) DEFAULT NULL COMMENT '门店ID（NULL=平台级/全门店）' AFTER compliance_notice;
