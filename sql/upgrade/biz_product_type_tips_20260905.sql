-- ===========================================================================
-- 商品详情页「类型说明」改由库里维护 + 商户级销量/库存展示开关
--
-- 背景（会员端 pages/goods/detail 三处硬编码）：
--
-- 1) 类型名硬编码。详情页「类型」那一行走的是页面里的 typeText() 映射表，
--    GROUPON 写死成「团购套餐」；而 biz_product_type.type_name 早就被运营
--    改成了「到店自取」。运营在后台改了名字，顾客端半点不动 —— 字典表形同虚设。
--
-- 2) 类型说明卡硬编码。「团购套餐说明 / 下单后凭核销码到店使用……」这类文案
--    直接写在 WXML 里，5 种类型 5 段。运营想改一个字都得改代码重新发版，
--    而且标题里的类型名同样和字典对不上。type_desc 是给后台运营看的业务说明
--    （「搭配自由，快速吸引顾客」这种招商话术），不适合直接给顾客看，
--    所以新增 type_tips 专门存面向顾客的使用说明。
--
-- 3) 「已售 0」无条件显示。新品还没卖过就明晃晃写着「已售 0」，
--    对商家是负面信号；库存同理，有的商家不愿把余量透给顾客。
--    这两项做成商户级开关，默认都开（保持现状，不改变既有商户观感）。
--
-- 幂等：可重复执行。
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. biz_product_type.type_tips —— 面向顾客的类型使用说明
-- ---------------------------------------------------------------------------
set @sql = (select if(
  (select count(*) from information_schema.columns
    where table_schema = database() and table_name = 'biz_product_type' and column_name = 'type_tips') = 0,
  'alter table biz_product_type add column type_tips varchar(500) null comment ''面向顾客的类型使用说明（商品详情页展示）'' after type_desc',
  'select ''biz_product_type.type_tips 已存在, skip'''));
prepare stmt from @sql; execute stmt; deallocate prepare stmt;

-- 把原先写死在 WXML 里的 5 段文案迁进库，作为初始值。
-- 只在 type_tips 为空时写，避免覆盖运营已经改过的内容。
update biz_product_type set type_tips = '下单后凭核销码到店使用，可选择套餐内不同子品搭配'
  where type_code = 'GROUPON' and (type_tips is null or type_tips = '');
update biz_product_type set type_tips = '现金抵扣券，到店买单时出示核销，符合门槛时直接抵扣'
  where type_code = 'VOUCHER' and (type_tips is null or type_tips = '');
update biz_product_type set type_tips = '团购、代金券、实物自由组合，一次购买分次核销'
  where type_code = 'COMBO' and (type_tips is null or type_tips = '');
update biz_product_type set type_tips = '下单后请到「我的订单」选择预约时段，凭预约凭证到店'
  where type_code = 'BOOKING' and (type_tips is null or type_tips = '');
-- 余下 6 种原先在详情页上没有说明卡（wx:if 一个都没命中），顾客看不到任何解释。
-- 顺带补齐，否则改成读库之后这些类型依然是空白。
update biz_product_type set type_tips = '一次购买分次核销，每次到店消耗一次，用完为止'
  where type_code = 'TIMECARD' and (type_tips is null or type_tips = '');
update biz_product_type set type_tips = '充值后余额存在卡内，到店买单时逐次抵扣'
  where type_code = 'STORED_CARD' and (type_tips is null or type_tips = '');
update biz_product_type set type_tips = '有效期内不限次数使用，到店出示核销码即可'
  where type_code = 'PERIOD_CARD' and (type_tips is null or type_tips = '');
update biz_product_type set type_tips = '大额分次核销，购买后按约定次数到店使用'
  where type_code = 'HUIXIANG_CARD' and (type_tips is null or type_tips = '');
update biz_product_type set type_tips = '先购买后预约，请在有效期内联系门店确认到店时间'
  where type_code = 'PRESALE' and (type_tips is null or type_tips = '');
update biz_product_type set type_tips = '购买后到门店凭核销码提取实物商品'
  where type_code = 'PICKUP_VOUCHER' and (type_tips is null or type_tips = '');
update biz_product_type set type_tips = '顾客自助输入金额付款，无需提前购买'
  where type_code = 'BILL' and (type_tips is null or type_tips = '');

-- ---------------------------------------------------------------------------
-- 2. biz_merchant 销量 / 库存展示开关
--    默认 '1'（显示），与改造前行为一致 —— 升级后不能让既有商户的页面突然变样。
-- ---------------------------------------------------------------------------
set @sql = (select if(
  (select count(*) from information_schema.columns
    where table_schema = database() and table_name = 'biz_merchant' and column_name = 'show_sales') = 0,
  'alter table biz_merchant add column show_sales char(1) default ''1'' comment ''商品详情页是否展示销量 1显示 0隐藏'' after promoter_enabled',
  'select ''biz_merchant.show_sales 已存在, skip'''));
prepare stmt from @sql; execute stmt; deallocate prepare stmt;

set @sql = (select if(
  (select count(*) from information_schema.columns
    where table_schema = database() and table_name = 'biz_merchant' and column_name = 'show_stock') = 0,
  'alter table biz_merchant add column show_stock char(1) default ''1'' comment ''商品详情页是否展示库存 1显示 0隐藏'' after show_sales',
  'select ''biz_merchant.show_stock 已存在, skip'''));
prepare stmt from @sql; execute stmt; deallocate prepare stmt;

-- 存量行 default 只作用于新增，已有记录仍是 null，必须显式回填成 '1'
update biz_merchant set show_sales = '1' where show_sales is null;
update biz_merchant set show_stock = '1' where show_stock is null;

-- ⚠️ 执行后必须清商户缓存，否则 merchant:appid:* / merchant:id:* 里的
-- 旧快照没有这两个 key，反序列化回来是 null（promoter_enabled 上线时踩过同一个坑）。
-- 后端已对 null 兜底成 '1'，但仍建议执行：
--   redis-cli -n <db> --scan --pattern 'merchant:*' | xargs -r redis-cli -n <db> DEL

-- 自检
select type_code, type_name, type_tips from biz_product_type order by sort;
select merchant_id, merchant_name, show_sales, show_stock from biz_merchant order by merchant_id limit 10;
