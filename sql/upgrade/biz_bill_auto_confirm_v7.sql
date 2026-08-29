-- ============================================================================
-- 到店买单：门店级「自动确认」开关（v7）
--
-- 背景：买单的业务场景是顾客在店员面前输入消费金额后直接付款，
--      不存在「店员在后台点一下确认」这个动作。但代码从项目基线
--      （f44e63cd）起就是 create() 落 status='0' 待确认，
--      要等 POST /api/bill/confirm/{billId} 才能付。
--
-- 之前唯一的「跳过确认」是挂在支付 mock 开关上的：
--   ApiBillController.create() 里 if (wxPayService.isMock()) status='1'
-- 而 WxPayConfig.isMockEnabled() 在 prod profile 下硬编码返回 false，
-- 于是本地（druid，mockEnabled=true）建单即可付、生产（prod）必须等确认 ——
-- 同一份代码两种行为，看起来像「功能被改回去了」，实际是环境差异。
--
-- 更要紧的是：生产上这个确认根本没人能完成。
--   confirm 端点要求 @StoreStaffRequired + userType=='store'，
--   而商家端登录签发的是 merchant/owner/manager/staff，进不去；
--   商家端账单页（pages/merchant/bill）的「确认买单」按钮
--   bindtap="onConfirm" 在 index.js 里根本没有实现这个方法。
--   结果：会员发起买单 → 弹「请门店确认」→ 轮询 120 秒 → 超时失败。
--
-- 本脚本把「要不要确认」从 mock 开关改成门店级业务配置，默认开启自动确认，
-- 让买单回到「输入金额直接付」；个别需要人工核对金额的门店可以关掉。
--
-- 导入：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/upgrade/biz_bill_auto_confirm_v7.sql
-- 幂等：可重复执行
-- ============================================================================

-- ----------------------------------------------------------------------------
-- biz_store 加列 bill_auto_confirm
--
-- 默认 '1'（自动确认）：这是买单的常态场景，新建门店不用记得去开。
-- 存量门店同样按 DEFAULT 落 '1' —— 它们现在的「待确认」状态是走不通的死路，
-- 迁移到自动确认才是修复而不是行为变更。
-- ----------------------------------------------------------------------------
set @exists := (
  select count(*) from information_schema.columns
  where table_schema = database() and table_name = 'biz_store'
    and column_name = 'bill_auto_confirm'
);
set @sql := if(@exists > 0,
  'select ''biz_store.bill_auto_confirm already exists'' as msg',
  'alter table biz_store add column bill_auto_confirm char(1) default ''1''
     comment ''买单自动确认（1自动确认免店员操作 0需店员确认金额）'' after services');
prepare stmt from @sql; execute stmt; deallocate prepare stmt;

-- 存量行可能是 null（部分 MySQL 版本加列不回填），统一补成 '1'
update biz_store set bill_auto_confirm = '1'
where bill_auto_confirm is null or bill_auto_confirm = '';

-- ----------------------------------------------------------------------------
-- 校验
-- ----------------------------------------------------------------------------
select bill_auto_confirm, count(*) as store_count
from biz_store group by bill_auto_confirm;
