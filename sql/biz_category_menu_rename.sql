-- ============================================================================
-- 菜单改名：「商品分类」→「行业品类」（menu_id=2032 及其 5 个按钮）
--
-- 为什么改：
--   menu_id=2032 指向 biz/category/index，而该页实际管理的是
--   biz_product_category —— 平台级「行业品类」多级树
--   （带 industry_code / allowed_types / deposit_amount / license_required），
--   是商品高级编辑页第 1 步「商品品类」级联选择器的数据源。
--
--   但它挂在「门店商品」(parent_id=2108) 下且叫「商品分类」，
--   极易被误认为是商家给自己菜单分组用的那种分类
--   （那个是另一张遗留表 biz_category）。改名消除歧义。
--
-- 只改 menu_name（显示名），不动 perms / path / component：
--   perms 是 biz:category:* ，前端 v-hasPermi 和后端 @PreAuthorize 都在用，
--   改了会直接导致该页按钮全部失效、甚至整页 403。
--
-- 幂等：带 WHERE menu_name 条件，重复执行不会产生额外变更。
--
-- 执行后必须清 Redis，否则 getRouters 仍返回缓存里的旧菜单名：
--   redis-cli -n 0 flushdb
-- ============================================================================

UPDATE sys_menu SET menu_name = '行业品类'     WHERE menu_id = 2032 AND menu_name = '商品分类';
UPDATE sys_menu SET menu_name = '行业品类查询' WHERE menu_id = 2033 AND menu_name = '商品分类查询';
UPDATE sys_menu SET menu_name = '行业品类新增' WHERE menu_id = 2034 AND menu_name = '商品分类新增';
UPDATE sys_menu SET menu_name = '行业品类修改' WHERE menu_id = 2035 AND menu_name = '商品分类修改';
UPDATE sys_menu SET menu_name = '行业品类删除' WHERE menu_id = 2036 AND menu_name = '商品分类删除';
UPDATE sys_menu SET menu_name = '行业品类导出' WHERE menu_id = 2037 AND menu_name = '商品分类导出';

-- 校验：应看到 6 行「行业品类*」，且 perms 仍为 biz:category:*
SELECT menu_id, parent_id, menu_name, path, component, perms
FROM sys_menu WHERE menu_id BETWEEN 2032 AND 2037 ORDER BY menu_id;
