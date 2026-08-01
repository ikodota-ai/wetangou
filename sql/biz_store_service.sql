-- 导入前请指定字符集，避免中文乱码：
--   mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_store_service.sql
-- ----------------------------
-- 门店「设置及服务」字典 + biz_store.services 字段
-- 说明：services 存字典键值，多选逗号分隔
-- ----------------------------

-- 1) 门店新增服务设置字段（存在则忽略，可手动执行一次）
alter table biz_store add column services varchar(255) default '' comment '服务设置（字典biz_store_service，多选逗号分隔）' after intro;

-- 2) 字典类型
delete from sys_dict_type where dict_type = 'biz_store_service';
insert into sys_dict_type (dict_name, dict_type, status, create_by, create_time, remark)
values ('门店服务设置', 'biz_store_service', '0', 'admin', sysdate(), '门店可堂食/可预约/独立空间/停车等服务标签');

-- 3) 字典数据
delete from sys_dict_data where dict_type = 'biz_store_service';
insert into sys_dict_data (dict_sort, dict_label, dict_value, dict_type, css_class, list_class, is_default, status, create_by, create_time, remark) values
(1, '可堂食',       'dine_in',          'biz_store_service', '', 'success', 'N', '0', 'admin', sysdate(), '可堂食'),
(2, '可预约',       'can_book',         'biz_store_service', '', 'primary', 'N', '0', 'admin', sysdate(), '可预约'),
(3, '提供独立空间', 'private_room',     'biz_store_service', '', 'warning', 'N', '0', 'admin', sysdate(), '提供独立空间'),
(4, '提供免费停车场', 'free_parking_lot', 'biz_store_service', '', 'info', 'N', '0', 'admin', sysdate(), '提供免费停车场'),
(5, '免费停车',     'free_parking',     'biz_store_service', '', 'info', 'N', '0', 'admin', sysdate(), '免费停车');
