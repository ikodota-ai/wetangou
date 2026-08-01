-- 微信配置菜单（独立维护页面，挂在"团购运营" 2001 下）
-- 权限：biz:wxconfig:query / biz:wxconfig:edit
-- menu_id 使用 2105，避免冲突

-- 父菜单（页面本身）
delete from sys_menu where menu_id in (2105, 2106, 2107);
insert into sys_menu
  (menu_id, menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
values
  (2105, '微信配置', 2001, 7, 'wxconfig', 'biz/wxconfig/index', '', '', 1, 0, 'C', '0', '0', 'biz:wxconfig:query', 'wechat', 'admin', sysdate(), '小程序/支付配置（AppId、AppSecret、支付证书等）');
-- 按钮权限
insert into sys_menu
  (menu_id, menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
values
  (2106, '微信配置查询', 2105, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:wxconfig:query', '#', 'admin', sysdate(), '');
insert into sys_menu
  (menu_id, menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
values
  (2107, '微信配置修改', 2105, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:wxconfig:edit', '#', 'admin', sysdate(), '');

-- 授予超级管理员（role_id=1）
delete from sys_role_menu where menu_id in (2105, 2106, 2107);
insert into sys_role_menu (role_id, menu_id) values (1, 2105);
insert into sys_role_menu (role_id, menu_id) values (1, 2106);
insert into sys_role_menu (role_id, menu_id) values (1, 2107);
