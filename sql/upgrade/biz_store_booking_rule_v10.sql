-- ============================================================================
-- 门店级预约可约范围（v10）
--
-- 背景（用户第 6 问：「后台的预约服务是不是可以不要、预约日期和预约时间
-- 是不是用来限制小程序可选的预约日期和时间的？」）：
--
-- 后半句的答案是「不是」—— 后台「预约管理」里每一行 biz_booking 是一个
-- 已经存在的场次（谁哪天几点约了），是结果不是规则。实测证明过：把门店
-- business_hours 从 10:00-22:00 改成 14:00-19:00，小程序可选时段立刻从
-- [10..21] 变成 [14..18]；而 biz_booking 里那些 15:00-16:00 的历史场次
-- 对可选范围毫无影响。
--
-- 但顺着这个问题往下看，会发现「可约范围」这件事系统里其实只做了一半：
-- 起止小时跟着营业时间走，而另外三件都是写死的 ——
--   · 能约未来几天：小程序 getNextDays(7) 写死 7 天
--   · 时段粒度：后端按整点展开，做不了 30 分钟一档
--   · 歇业日：完全没有，门店周一休息顾客照样能约周一
-- 也就是说运营想「限制小程序可选的预约日期和时间」，目前只能改营业时间，
-- 而营业时间还同时被首页「营业中/已打烊」用着，一改就互相干扰。
--
-- 所以把「规则」独立出来放在门店级（不去动 biz_booking 的场次语义 ——
-- 一行既是规则又是已发生的场次，后台列表就没法看了）。
--
-- 导入：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/upgrade/biz_store_booking_rule_v10.sql
-- 幂等：可重复执行
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) booking_ahead_days：能约未来几天（含今天）
--
-- 默认 7 与原先小程序写死的 7 天保持一致，保证升级后行为不变。
-- 允许 1~60；填 1 表示只能约当天。
-- ----------------------------------------------------------------------------
set @exists := (
  select count(*) from information_schema.columns
  where table_schema = database() and table_name = 'biz_store'
    and column_name = 'booking_ahead_days'
);
set @sql := if(@exists > 0,
  'select ''biz_store.booking_ahead_days already exists'' as msg',
  'alter table biz_store add column booking_ahead_days int(4) default 7
     comment ''可提前预约天数（含今天，1-60，默认7）'' after rating');
prepare stmt from @sql; execute stmt; deallocate prepare stmt;

-- ----------------------------------------------------------------------------
-- 2) booking_slot_minutes：时段粒度（分钟）
--
-- 默认 60 = 原先的整点展开，升级后行为不变。
-- 允许 15/30/60/120；餐饮常用 30，服务类常用 60。
-- ----------------------------------------------------------------------------
set @exists := (
  select count(*) from information_schema.columns
  where table_schema = database() and table_name = 'biz_store'
    and column_name = 'booking_slot_minutes'
);
set @sql := if(@exists > 0,
  'select ''biz_store.booking_slot_minutes already exists'' as msg',
  'alter table biz_store add column booking_slot_minutes int(4) default 60
     comment ''预约时段粒度分钟（15/30/60/120，默认60=整点）'' after booking_ahead_days');
prepare stmt from @sql; execute stmt; deallocate prepare stmt;

-- ----------------------------------------------------------------------------
-- 3) booking_closed_days：歇业日（每周几不可约）
--
-- 存 1-7 逗号分隔（1=周一 … 7=周日，与 ISO-8601 一致，避免「周日算 0 还是 7」
-- 这种歧义）。空 = 每天都可约。
-- 用 varchar 而不是 bitmask：后台要用 el-checkbox-group 直接绑，
-- 且 DBA 排查时 '1,2' 比 3 直观。
-- ----------------------------------------------------------------------------
set @exists := (
  select count(*) from information_schema.columns
  where table_schema = database() and table_name = 'biz_store'
    and column_name = 'booking_closed_days'
);
set @sql := if(@exists > 0,
  'select ''biz_store.booking_closed_days already exists'' as msg',
  'alter table biz_store add column booking_closed_days varchar(32) default null
     comment ''歇业日：每周几不可约，1-7逗号分隔（1=周一,7=周日），空=每天可约'' after booking_slot_minutes');
prepare stmt from @sql; execute stmt; deallocate prepare stmt;

-- ----------------------------------------------------------------------------
-- 存量数据补默认值
--
-- 加列时带了 default，但已存在的行在某些 MySQL 版本 / 之前手工加过列的库里
-- 可能是 null，而 null 会让后端走「粒度 0」的除零分支，必须补齐。
-- ----------------------------------------------------------------------------
update biz_store set booking_ahead_days = 7   where booking_ahead_days is null or booking_ahead_days <= 0;
update biz_store set booking_slot_minutes = 60 where booking_slot_minutes is null or booking_slot_minutes <= 0;

-- ----------------------------------------------------------------------------
-- 校验
-- ----------------------------------------------------------------------------
select 'booking_ahead_days' as item, count(*) as ok from information_schema.columns
  where table_schema=database() and table_name='biz_store' and column_name='booking_ahead_days'
union all
select 'booking_slot_minutes', count(*) from information_schema.columns
  where table_schema=database() and table_name='biz_store' and column_name='booking_slot_minutes'
union all
select 'booking_closed_days', count(*) from information_schema.columns
  where table_schema=database() and table_name='biz_store' and column_name='booking_closed_days'
union all
select '存量行已补默认值', count(*) from biz_store
  where booking_ahead_days > 0 and booking_slot_minutes > 0;
