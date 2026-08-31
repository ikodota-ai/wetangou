-- ============================================================================
-- 门店评分 + 预约类型字典（v8）
--
-- 背景（用户报的两个问题）：
--  1. 小程序首页店铺卡片写死「评分功能即将上线」—— 当初因为没有评价表，
--     索性把星级去掉了。但商家其实只需要一个后台能填的门店评分（如大众点评
--     那样的 4.8 分），不需要完整的用户评价体系。这里加 biz_store.rating。
--  2. 后台新增预约时「预约类型」只能手填，无法统一口径。改成走 RuoYi 字典，
--     商家可在「字典管理」里自行增删（堂食预约 / 到店消费 / 其他预约…）。
--
-- 导入：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/upgrade/biz_store_rating_booking_type_v8.sql
-- 幂等：可重复执行
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) biz_store 加列 rating
--
-- decimal(2,1)：取值 0.0 ~ 5.0，一位小数够用（评分展示到 4.8 这个精度）。
-- 默认 null 而不是 0：0.0 分和「还没评分」是两回事，
-- 前端靠 null 判断该不该显示星级，落 0 会让新门店显示成差评。
-- ----------------------------------------------------------------------------
set @exists := (
  select count(*) from information_schema.columns
  where table_schema = database() and table_name = 'biz_store'
    and column_name = 'rating'
);
set @sql := if(@exists > 0,
  'select ''biz_store.rating already exists'' as msg',
  'alter table biz_store add column rating decimal(2,1) default null
     comment ''门店评分（0.0-5.0，后台手工维护，null=未评分）'' after services');
prepare stmt from @sql; execute stmt; deallocate prepare stmt;

-- ----------------------------------------------------------------------------
-- 2) biz_booking 加列 booking_type
--
-- 存字典 value（如 dine_in），中文标签由字典翻译，避免中文进业务表。
-- ----------------------------------------------------------------------------
set @exists := (
  select count(*) from information_schema.columns
  where table_schema = database() and table_name = 'biz_booking'
    and column_name = 'booking_type'
);
set @sql := if(@exists > 0,
  'select ''biz_booking.booking_type already exists'' as msg',
  'alter table biz_booking add column booking_type varchar(32) default null
     comment ''预约类型（字典 biz_booking_type 的 value）'' after service_name');
prepare stmt from @sql; execute stmt; deallocate prepare stmt;

-- ----------------------------------------------------------------------------
-- 3) 预约类型字典
--
-- 不写死 dict_id / dict_code：这两个是自增主键，硬编码会和别的升级脚本撞车
-- （biz_product_type 就踩过 Duplicate entry 的坑）。用 where not exists 判重。
-- ----------------------------------------------------------------------------
insert into sys_dict_type (dict_name, dict_type, status, create_by, create_time, remark)
select '预约类型', 'biz_booking_type', '0', 'admin', now(), '门店预约的类型划分'
from dual
where not exists (select 1 from sys_dict_type where dict_type = 'biz_booking_type');

insert into sys_dict_data (dict_sort, dict_label, dict_value, dict_type, css_class, list_class, is_default, status, create_by, create_time, remark)
select 1, '堂食预约', 'dine_in', 'biz_booking_type', '', 'primary', 'Y', '0', 'admin', now(), ''
from dual where not exists (select 1 from sys_dict_data where dict_type='biz_booking_type' and dict_value='dine_in');

insert into sys_dict_data (dict_sort, dict_label, dict_value, dict_type, css_class, list_class, is_default, status, create_by, create_time, remark)
select 2, '到店消费', 'in_store', 'biz_booking_type', '', 'success', 'N', '0', 'admin', now(), ''
from dual where not exists (select 1 from sys_dict_data where dict_type='biz_booking_type' and dict_value='in_store');

insert into sys_dict_data (dict_sort, dict_label, dict_value, dict_type, css_class, list_class, is_default, status, create_by, create_time, remark)
select 3, '其他预约', 'other', 'biz_booking_type', '', 'info', 'N', '0', 'admin', now(), ''
from dual where not exists (select 1 from sys_dict_data where dict_type='biz_booking_type' and dict_value='other');

-- ----------------------------------------------------------------------------
-- 校验
-- ----------------------------------------------------------------------------
select 'rating 列' as item, count(*) as ok from information_schema.columns
  where table_schema=database() and table_name='biz_store' and column_name='rating'
union all
select 'booking_type 列', count(*) from information_schema.columns
  where table_schema=database() and table_name='biz_booking' and column_name='booking_type'
union all
select '字典类型', count(*) from sys_dict_type where dict_type='biz_booking_type'
union all
select '字典项', count(*) from sys_dict_data where dict_type='biz_booking_type';
