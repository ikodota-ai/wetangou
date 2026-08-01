-- 预约明细列表菜单（挂在“团购运营”目录 2001 下，复用 biz:booking 权限）
-- menu_id 使用 2104，避免与现有 biz 菜单冲突

delete from sys_menu where menu_id = 2104;
insert into sys_menu
  (menu_id, menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
values
  (2104, '预约明细', 2001, 6, 'bookingmember', 'biz/bookingmember/index', '', '', 1, 0, 'C', '0', '0', 'biz:booking:list', 'form', 'admin', sysdate(), '预约报名明细列表');

-- 授予超级管理员角色（role_id=1）
delete from sys_role_menu where menu_id = 2104;
insert into sys_role_menu (role_id, menu_id) values (1, 2104);
