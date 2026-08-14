-- ============================================================
-- biz_product_subitem / biz_product_subitem_group 种子数据
-- 2026-08-14
-- 用途：本地端到端测试商品详情 subitemGroups 端点
-- 幂等：INSERT IGNORE / NOT EXISTS，重复跑安全
-- 注：每行 group_id 自增（避免 product 共享主键冲突）
-- ============================================================

-- === GROUPON 商品：2-3 人餐 / 4-6 人餐 规格 ===
-- product 2000 套餐
INSERT IGNORE INTO biz_product_subitem_group (group_id, product_id, group_name, pick_rule, sort, create_time)
VALUES (20001, 2000, '套餐规格', 'PICK', 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (20001, 2000, '2-3 人餐', 1, 168.00, 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (20001, 2000, '4-6 人餐', 1, 268.00, 2, NOW());

-- product 2001 套餐
INSERT IGNORE INTO biz_product_subitem_group (group_id, product_id, group_name, pick_rule, sort, create_time)
VALUES (20011, 2001, '套餐规格', 'PICK', 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (20011, 2001, '2-3 人餐', 1, 168.00, 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (20011, 2001, '4-6 人餐', 1, 268.00, 2, NOW());

-- product 2002
INSERT IGNORE INTO biz_product_subitem_group (group_id, product_id, group_name, pick_rule, sort, create_time)
VALUES (20021, 2002, '套餐规格', 'PICK', 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (20021, 2002, '2-3 人餐', 1, 168.00, 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (20021, 2002, '4-6 人餐', 1, 268.00, 2, NOW());

-- product 2003
INSERT IGNORE INTO biz_product_subitem_group (group_id, product_id, group_name, pick_rule, sort, create_time)
VALUES (20031, 2003, '套餐规格', 'PICK', 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (20031, 2003, '2-3 人餐', 1, 168.00, 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (20031, 2003, '4-6 人餐', 1, 268.00, 2, NOW());

-- === BOOKING 商品：SPA 时长 ===
-- product 1002 SPA 60/90 分钟
INSERT IGNORE INTO biz_product_subitem_group (group_id, product_id, group_name, pick_rule, sort, create_time)
VALUES (10021, 1002, '服务时长', 'PICK', 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (10021, 1002, '60 分钟', 1, 198.00, 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (10021, 1002, '90 分钟', 1, 298.00, 2, NOW());

-- === GROUPON 口味/主菜 ===
-- product 1000 套餐
INSERT IGNORE INTO biz_product_subitem_group (group_id, product_id, group_name, pick_rule, sort, create_time)
VALUES (10001, 1000, '口味', 'PICK', 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (10001, 1000, '微辣', 1, 128.00, 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (10001, 1000, '中辣', 1, 128.00, 2, NOW());

-- product 1001 主菜
INSERT IGNORE INTO biz_product_subitem_group (group_id, product_id, group_name, pick_rule, sort, create_time)
VALUES (10011, 1001, '主菜', 'PICK', 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (10011, 1001, '宫保鸡丁', 1, 38.00, 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (10011, 1001, '鱼香肉丝', 1, 38.00, 2, NOW());
