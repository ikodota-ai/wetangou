-- =============================================
-- 洞天「团购运营」菜单重新分组（5 大类）
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_menu_reorganization.sql
-- 说明：19 个平级菜单调整为 门店商品 / 交易订单 / 会员体系 / 推客分销 / 平台配置
--       脚本可重复执行（幂等），菜单ID由自增分配，不硬编码，避免与代码生成器冲突
-- =============================================

-- ----------------------------
-- 步骤0：定位「团购运营」一级目录（不存在则创建）
-- 注意：不能傅底到固定 ID，否则在缺少该目录的库上会撞上自增分配的菜单 ID
-- ----------------------------
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '团购运营', 0, 4, 'tuangou', '', '', '', 1, 0, 'M', '0', '0', '', 'shopping', 'admin', SYSDATE(), '洞天团购业务'
FROM (SELECT 1) t
WHERE NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE menu_name = '团购运营' AND parent_id = 0) x);

SET @biz_id = (SELECT menu_id FROM sys_menu WHERE menu_name = '团购运营' AND parent_id = 0 LIMIT 1);

-- ----------------------------
-- 步骤1：清理历史分组目录（重复执行时先复原层级，再删除旧目录）
-- ----------------------------
UPDATE sys_menu c
  JOIN sys_menu p ON c.parent_id = p.menu_id
SET c.parent_id = @biz_id
WHERE p.parent_id = @biz_id
  AND p.menu_type = 'M'
  AND p.menu_name IN ('门店商品', '交易订单', '会员体系', '推客分销', '平台配置');

DELETE rm FROM sys_role_menu rm
  JOIN sys_menu m ON rm.menu_id = m.menu_id
WHERE m.parent_id = @biz_id
  AND m.menu_type = 'M'
  AND m.menu_name IN ('门店商品', '交易订单', '会员体系', '推客分销', '平台配置');

DELETE FROM sys_menu
WHERE parent_id = @biz_id
  AND menu_type = 'M'
  AND menu_name IN ('门店商品', '交易订单', '会员体系', '推客分销', '平台配置');

-- ----------------------------
-- 步骤2：新增 5 个二级目录（menu_type=M，component 留空 → 前端 ParentView）
-- ----------------------------
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('门店商品', @biz_id, 1, 'goods', '', '', '', 1, 0, 'M', '0', '0', '', 'shopping', 'admin', SYSDATE(), '门店、分类、商品、相册、协议');
SET @dir_goods = LAST_INSERT_ID();

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('交易订单', @biz_id, 2, 'trade', '', '', '', 1, 0, 'M', '0', '0', '', 'money', 'admin', SYSDATE(), '团购订单、买单、预约');
SET @dir_trade = LAST_INSERT_ID();

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('会员体系', @biz_id, 3, 'membership', '', '', '', 1, 0, 'M', '0', '0', '', 'peoples', 'admin', SYSDATE(), '会员、会员用户、代金券、账户');
SET @dir_member = LAST_INSERT_ID();

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('推客分销', @biz_id, 4, 'promoter', '', '', '', 1, 0, 'M', '0', '0', '', 'people', 'admin', SYSDATE(), '推客、佣金规则与记录、提现');
SET @dir_promoter = LAST_INSERT_ID();

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('平台配置', @biz_id, 5, 'setting', '', '', '', 1, 0, 'M', '0', '0', '', 'tool', 'admin', SYSDATE(), '微信小程序/支付等平台配置');
SET @dir_setting = LAST_INSERT_ID();

-- ----------------------------
-- 步骤3：19 个业务菜单挂到新目录下（按 component 匹配，同时统一菜单名称与排序）
-- ----------------------------

-- 3.1 门店商品
UPDATE sys_menu SET parent_id = @dir_goods, order_num = 1, menu_name = '门店管理' WHERE component = 'biz/store/index';
UPDATE sys_menu SET parent_id = @dir_goods, order_num = 2, menu_name = '商品分类' WHERE component = 'biz/category/index';
UPDATE sys_menu SET parent_id = @dir_goods, order_num = 3, menu_name = '商品管理' WHERE component = 'biz/product/index';
UPDATE sys_menu SET parent_id = @dir_goods, order_num = 4, menu_name = '相册管理' WHERE component = 'biz/album/index';
UPDATE sys_menu SET parent_id = @dir_goods, order_num = 5, menu_name = '协议管理' WHERE component = 'biz/agreement/index';

-- 3.2 交易订单
UPDATE sys_menu SET parent_id = @dir_trade, order_num = 1, menu_name = '团购订单' WHERE component = 'biz/order/index';
UPDATE sys_menu SET parent_id = @dir_trade, order_num = 2, menu_name = '买单记录' WHERE component = 'biz/bill/index';
UPDATE sys_menu SET parent_id = @dir_trade, order_num = 3, menu_name = '预约管理' WHERE component = 'biz/booking/index';
UPDATE sys_menu SET parent_id = @dir_trade, order_num = 4, menu_name = '预约明细' WHERE component = 'biz/bookingmember/index';

-- 3.3 会员体系
UPDATE sys_menu SET parent_id = @dir_member, order_num = 1, menu_name = '会员管理' WHERE component = 'biz/member/index';
UPDATE sys_menu SET parent_id = @dir_member, order_num = 2, menu_name = '会员用户' WHERE component = 'biz/user/index';
UPDATE sys_menu SET parent_id = @dir_member, order_num = 3, menu_name = '代金券管理' WHERE component = 'biz/voucher/index';
UPDATE sys_menu SET parent_id = @dir_member, order_num = 4, menu_name = '会员账户' WHERE component = 'biz/account/index';

-- 3.4 推客分销
UPDATE sys_menu SET parent_id = @dir_promoter, order_num = 1, menu_name = '推客管理' WHERE component = 'biz/distributor/index';
UPDATE sys_menu SET parent_id = @dir_promoter, order_num = 2, menu_name = '佣金规则' WHERE component = 'biz/rule/index';
UPDATE sys_menu SET parent_id = @dir_promoter, order_num = 3, menu_name = '佣金记录' WHERE component = 'biz/commission/index';
UPDATE sys_menu SET parent_id = @dir_promoter, order_num = 4, menu_name = '提现申请' WHERE component = 'biz/withdraw/index';
UPDATE sys_menu SET parent_id = @dir_promoter, order_num = 5, menu_name = '提现记录' WHERE component = 'biz/record/index';

-- 3.5 平台配置
UPDATE sys_menu SET parent_id = @dir_setting, order_num = 1, menu_name = '微信配置' WHERE component = 'biz/wxconfig/index';
UPDATE sys_menu SET parent_id = @dir_setting, order_num = 2, menu_name = '小程序平台配置' WHERE component = 'biz/mpconfig/index';

-- ----------------------------
-- 步骤4：角色权限同步（凡拥有分组内任一菜单的角色，补授该分组目录）
-- ----------------------------
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT DISTINCT rm.role_id, c.parent_id
FROM sys_role_menu rm
  JOIN sys_menu c ON rm.menu_id = c.menu_id
WHERE c.parent_id IN (@dir_goods, @dir_trade, @dir_member, @dir_promoter, @dir_setting);

-- ----------------------------
-- 验证：查看分组结果
-- ----------------------------
SELECT p.menu_name AS 分组, c.order_num AS 排序, c.menu_name AS 菜单, c.path AS 路由, c.component AS 组件
FROM sys_menu p
  JOIN sys_menu c ON c.parent_id = p.menu_id
WHERE p.parent_id = @biz_id AND p.menu_type = 'M'
ORDER BY p.order_num, c.order_num;
