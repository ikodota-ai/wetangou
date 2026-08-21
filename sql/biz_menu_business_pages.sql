-- ============================================================
-- 补齐 19 个业务菜单页 + 按钮权限（2026-08-22）
--
-- 背景：这 19 个业务菜单最初由 RuoYi 代码生成器直接写进开发库，
--       建表 SQL 从未入仓。sql/biz_menu_reorganization.sql 只做「重新分组」
--       （把已存在的菜单移到 5 个分组下），并不创建它们。
--       → 全新库跑完 init-all.sh 后，后台只有 14 个业务菜单，
--         订单/会员/商品/门店/推客/佣金等 18 个页面在侧边栏根本不出现。
--
-- 幂等：全部按 perms / menu_name 判断存在性，可重复执行
-- 注意：菜单 ID 由自增分配，父子关系一律按「菜单名」查找，不硬编码 ID
--       （本地库 2108=门店商品，脚本库 2108=首页轮播图，硬编码必错）
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p <库名> < sql/biz_menu_business_pages.sql
-- ============================================================

-- 0) 分组目录（门店商品/交易订单/会员体系/推客分销/平台配置）由
--    sql/biz_menu_reorganization.sql 创建，本脚本必须在它之后执行，
--    这里只按名字查找、绝不自建，否则会出现两套同名分组。

-- 1) 18 个业务菜单页（C 型）

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='商品管理' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品创建', @pid, 1, 'create', 'biz/product/create', NULL, '', 1, 0, 'C', '0', '0', 'biz:product:add', '#', 'admin', SYSDATE(), '商品创建路由（抖音来客风格）'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:add' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='商品管理' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品详情', @pid, 2, 'detail/:productId(d+)', 'biz/product/detail', NULL, '', 1, 0, 'C', '1', '0', 'biz:product:query', '#', 'admin', SYSDATE(), '商品详情路由'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:query' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='门店商品' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店管理', @pid, 1, 'store', 'biz/store/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:store:list', 'shopping', 'admin', SYSDATE(), '门店菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:store:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='门店商品' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品分类', @pid, 2, 'category', 'biz/category/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:category:list', 'list', 'admin', SYSDATE(), '商品分类菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:category:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='门店商品' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品管理', @pid, 3, 'product', 'biz/product/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:product:list', 'goods', 'admin', SYSDATE(), '商品菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='门店商品' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '相册管理', @pid, 4, 'album', 'biz/album/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:album:list', 'image', 'admin', SYSDATE(), '门店相册菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:album:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='门店商品' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '协议管理', @pid, 5, 'agreement', 'biz/agreement/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:agreement:list', 'documentation', 'admin', SYSDATE(), '协议菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='交易订单' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '团购订单', @pid, 1, 'order', 'biz/order/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:order:list', 'form', 'admin', SYSDATE(), '订单菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:order:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='交易订单' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单记录', @pid, 2, 'bill', 'biz/bill/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:bill:list', 'money', 'admin', SYSDATE(), '买单流水菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='会员体系' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员管理', @pid, 1, 'member', 'biz/member/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:member:list', 'peoples', 'admin', SYSDATE(), '会员菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:member:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='会员体系' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员用户', @pid, 2, 'user', 'biz/user/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:user:list', 'tree', 'admin', SYSDATE(), '账号门店关联菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:user:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='会员体系' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '代金券管理', @pid, 3, 'voucher', 'biz/voucher/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:voucher:list', 'star', 'admin', SYSDATE(), '代金券模板菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='会员体系' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员账户', @pid, 4, 'account', 'biz/account/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:account:list', 'validCode', 'admin', SYSDATE(), '分账接收方菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:account:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='推客分销' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '推客管理', @pid, 1, 'distributor', 'biz/distributor/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:distributor:list', 'user', 'admin', SYSDATE(), '推客菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='推客分销' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金规则', @pid, 2, 'rule', 'biz/rule/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:rule:list', 'edit', 'admin', SYSDATE(), '佣金规则菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='推客分销' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金记录', @pid, 3, 'commission', 'biz/commission/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:commission:list', 'money', 'admin', SYSDATE(), '佣金明细菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='推客分销' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '提现申请', @pid, 4, 'withdraw', 'biz/withdraw/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:withdraw:list', 'money', 'admin', SYSDATE(), '提现记录菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='推客分销' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '提现记录', @pid, 5, 'record', 'biz/record/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:record:list', 'documentation', 'admin', SYSDATE(), '分账明细菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:record:list' AND menu_type='C') x);

-- 2) 按钮权限（F 型），父菜单按 perms 定位

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:account:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账接收方查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:account:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:account:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:account:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账接收方新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:account:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:account:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:account:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账接收方修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:account:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:account:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:account:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账接收方删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:account:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:account:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:account:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账接收方导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:account:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:account:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '协议查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:agreement:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '协议新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:agreement:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '协议修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:agreement:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '协议删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:agreement:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '协议导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:agreement:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:album:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店相册查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:album:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:album:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:album:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店相册新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:album:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:album:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:album:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店相册修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:album:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:album:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:album:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店相册删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:album:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:album:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:album:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店相册导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:album:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:album:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单流水查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:bill:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单流水新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:bill:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单流水修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:bill:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单流水删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:bill:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单流水导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:bill:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单确认', @pid, 6, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:bill:confirm', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:confirm') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:category:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品分类查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:category:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:category:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:category:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品分类新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:category:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:category:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:category:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品分类修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:category:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:category:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:category:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品分类删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:category:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:category:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:category:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品分类导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:category:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:category:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金明细查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:commission:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金明细新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:commission:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金明细修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:commission:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金明细删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:commission:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金明细导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:commission:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '推客查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:distributor:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '推客新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:distributor:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '推客修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:distributor:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '推客删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:distributor:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '推客导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:distributor:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:member:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:member:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:member:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:member:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:member:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:member:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:member:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:member:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:member:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:member:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:member:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:member:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:member:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:member:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:member:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:order:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '订单查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:order:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:order:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:order:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '订单新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:order:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:order:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:order:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '订单修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:order:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:order:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:order:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '订单删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:order:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:order:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:order:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '订单导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:order:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:order:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:order:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '订单核销', @pid, 6, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:order:verify', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:order:verify') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:product:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:product:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:product:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:product:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:product:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:product:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:product:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:product:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:product:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:product:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:record:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账明细查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:record:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:record:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:record:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账明细新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:record:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:record:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:record:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账明细修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:record:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:record:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:record:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账明细删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:record:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:record:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:record:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账明细导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:record:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:record:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金规则查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:rule:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金规则新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:rule:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金规则修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:rule:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金规则删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:rule:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金规则导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:rule:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:store:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:store:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:store:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:store:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:store:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:store:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:store:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:store:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:store:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:store:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:store:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:store:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:store:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:store:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:store:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:user:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '账号门店关联查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:user:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:user:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:user:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '账号门店关联新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:user:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:user:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:user:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '账号门店关联修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:user:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:user:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:user:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '账号门店关联删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:user:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:user:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:user:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '账号门店关联导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:user:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:user:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '代金券模板查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:voucher:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '代金券模板新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:voucher:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '代金券模板修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:voucher:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '代金券模板删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:voucher:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '代金券模板导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:voucher:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '提现记录查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:withdraw:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:query') x);


-- ============================================================
-- 5) 延后建的按钮：biz:booking:* / biz:withdraw:* 的父菜单由本文件之后的
--    脚本创建（预约明细 / 提现申请），必须放在角色绑定之后再挂，否则 @pid 为空。
-- ============================================================
SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '在线预约查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:booking:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '在线预约新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:booking:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '在线预约修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:booking:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '在线预约删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:booking:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '在线预约导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:booking:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '提现记录新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:withdraw:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '提现记录修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:withdraw:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '提现记录删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:withdraw:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '提现记录导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:withdraw:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:export') x);

-- ============================================================
-- 4) 角色绑定：把业务菜单授予 admin(role_id=1) 与平台角色(role_id=3)
--    不绑的话菜单建了也不会出现在侧边栏（RuoYi 按 sys_role_menu 过滤）
-- ============================================================
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu WHERE perms LIKE 'biz:%';

INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu WHERE menu_type='M'
  AND menu_name IN ('团购运营','门店商品','交易订单','会员体系','推客分销','平台配置');

INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 3, menu_id FROM sys_menu
WHERE (perms LIKE 'biz:%'
       OR (menu_type='M' AND menu_name IN ('团购运营','门店商品','交易订单','会员体系','推客分销','平台配置')))
  AND EXISTS (SELECT 1 FROM sys_role WHERE role_id=3);

-- 补绑这些按钮到角色
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu WHERE perms IN
  ('biz:booking:query','biz:booking:add','biz:booking:edit','biz:booking:remove','biz:booking:export',
   'biz:withdraw:add','biz:withdraw:edit','biz:withdraw:remove','biz:withdraw:export');
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 3, menu_id FROM sys_menu WHERE perms IN
  ('biz:booking:query','biz:booking:add','biz:booking:edit','biz:booking:remove','biz:booking:export',
   'biz:withdraw:add','biz:withdraw:edit','biz:withdraw:remove','biz:withdraw:export')
  AND EXISTS (SELECT 1 FROM sys_role WHERE role_id=3);

-- ============================================================
-- 6) 兜底：sys_menu.parent_id 绝不允许 NULL
--    SysMenu.getParentId() 被 SysMenuServiceImpl 直接 longValue()，
--    任何一行 parent_id IS NULL 都会让 GET /getRouters 抛 500，
--    表现为「登录成功但后台侧边栏全空」。
--    历史上 biz_banner.sql（找不存在的「商城管理」）和 biz_merchant_v2.sql
--    （要求门店商品挂在团购运营下）都踩过，这里统一收敛为顶级 0。
-- ============================================================
UPDATE sys_menu SET parent_id = 0 WHERE parent_id IS NULL;

-- 6.1) 上面兜底会把这两个菜单变成「顶级但无分组标题」（侧边栏出现无名分组）。
--      归位：员工管理 → 门店商品；小程序授权 → 平台配置。
--      注：MySQL 不允许 UPDATE 的子查询引用同一张表（ERROR 1093），先用变量取出。
SET @goods_pid = (SELECT menu_id FROM sys_menu WHERE menu_name='门店商品' AND menu_type='M' ORDER BY menu_id LIMIT 1);
UPDATE sys_menu SET parent_id = @goods_pid
WHERE perms = 'biz:staffInvite:list' AND menu_type='C' AND parent_id = 0 AND @goods_pid IS NOT NULL;

SET @conf_pid = (SELECT menu_id FROM sys_menu WHERE menu_name='平台配置' AND menu_type='M' ORDER BY menu_id LIMIT 1);
UPDATE sys_menu SET parent_id = @conf_pid
WHERE perms = 'biz:mpauth:list' AND menu_type='C' AND parent_id = 0 AND @conf_pid IS NOT NULL;
