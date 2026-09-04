-- ============================================================================
-- 预约模型统一：移除 booking_type 列，service_name 改为派生列
--
-- 背景：
--  原先预约场次（biz_booking）有 service_name（自由文本）和 booking_type
--  （字典 biz_booking_type）两个字段，前者存的是类型名（「堂食预约」），
--  后者是类型 code（dine_in）。而小程序首页「预约服务」tab 读的是
--  /api/product/list?typeCode=BOOKING —— 真实商品。同一个「预约」入口，
--  两套数据模型：商家上架的预约商品在预约 tab 里一个都看不到，预约单的
--  product_id 一直是 NULL，后台只能看到「堂食预约」四个字。
--
--  现在统一以商品为准：service_name 由后端按 product_id 查商品名写入，
--  不再是任人填的自由文本。booking_type 列不再使用。
--
-- 导入：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/upgrade/booking_remove_type_v11.sql
-- 幂等：可重复执行
-- ============================================================================

-- ---------------------------------------------------------------------------
-- biz_booking 移除 booking_type 列
-- ---------------------------------------------------------------------------
set @exists := (
  select count(*) from information_schema.columns
  where table_schema = database() and table_name = 'biz_booking'
    and column_name = 'booking_type'
);
set @stmt := if(@exists > 0,
  'alter table biz_booking drop column booking_type',
  'select 1'
);
prepare stmt from @stmt;
execute stmt;
deallocate prepare stmt;

-- 注：biz_booking_member 没有自己的 service_name 列 —— 它是 BookingMemberMapper.xml
-- 里从 biz_booking 联表取的（b.service_name），实体上那个字段只是接收联表结果，
-- 所以这里不需要动 biz_booking_member 的表结构。
