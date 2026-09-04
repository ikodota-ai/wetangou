-- ===========================================================================
-- 买单补「支付完成」态字段：pay_time / pay_no
--
-- 背景：biz_pay_bill 的 status 有 2=已完成，但表里压根没有支付时间和微信交易号
-- 两列。后台看到一笔「已完成」的买单，既不知道什么时候付的，也拿不到
-- transaction_id 去微信商户平台对账，更没法发起退款。
--
-- 幂等：可重复执行。
-- ===========================================================================

-- pay_time
set @sql = (select if(
  (select count(*) from information_schema.columns
    where table_schema = database() and table_name = 'biz_pay_bill' and column_name = 'pay_time') = 0,
  'alter table biz_pay_bill add column pay_time datetime null comment ''支付完成时间'' after confirm_time',
  'select ''biz_pay_bill.pay_time 已存在, skip'''));
prepare stmt from @sql; execute stmt; deallocate prepare stmt;

-- pay_no（微信 transaction_id）
set @sql = (select if(
  (select count(*) from information_schema.columns
    where table_schema = database() and table_name = 'biz_pay_bill' and column_name = 'pay_no') = 0,
  'alter table biz_pay_bill add column pay_no varchar(64) null comment ''微信支付订单号transaction_id'' after pay_time',
  'select ''biz_pay_bill.pay_no 已存在, skip'''));
prepare stmt from @sql; execute stmt; deallocate prepare stmt;

-- 存量已完成买单没有支付时间，用确认时间兜底（同一次操作里确认并支付，误差可忽略），
-- 好过在后台显示成空白让人以为没付款。
update biz_pay_bill
set pay_time = confirm_time
where status = '2' and pay_time is null and confirm_time is not null;
