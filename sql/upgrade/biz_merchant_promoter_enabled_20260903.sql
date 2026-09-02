-- ============================================================================
-- 商户级「推客功能」总开关
--
-- 背景：推客（分销）入口此前对所有商户无条件显示。但推客涉及佣金/提现，
-- 不是每个商户都开这块业务 —— 没开的商户，顾客在「我的」页看到「推客中心」
-- 点进去只能看到 403「您还不是推客，请先申请加入」，等于把一个用不上的
-- 功能摆在最显眼的位置。改成后台「商户管理 → 编辑 → 推客功能」控制：
-- 关闭时小程序「我的」页不渲染该入口。
--
-- 默认 '1'（启用）而不是 '0'：这是给存量商户加列，默认关会让已经在跑
-- 推客业务的商户入口在升级瞬间消失。新建商户的默认值同样是 '1'
-- （前端 reset() 也置 "1"，两边保持一致）。
--
-- ⚠ 加完列记得清商户缓存：merchant:appid:* / merchant:id:* 是 fastjson
-- 序列化的 Merchant 对象且**没有 TTL**，只有编辑商户时才 evict。老快照里
-- 没有 promoterEnabled 这个 key，反序列化回来是 null。后端已在
-- ApiMerchantController 对空值兜底成 '1'，所以不清也不会出错，
-- 但清一下能让后台的改动立刻生效：
--   redis-cli --scan --pattern 'merchant:*' | xargs -r redis-cli DEL
--
-- 导入：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/upgrade/biz_merchant_promoter_enabled_20260903.sql
-- 幂等：可重复执行
-- ============================================================================

-- ----------------------------------------------------------------------------
-- biz_merchant 加列 promoter_enabled
--
-- 用 information_schema 先判存在再拼 alter：MySQL 5.7 不支持
-- `add column if not exists`，直接 alter 重跑会报 1060 Duplicate column，
-- 整个 init-all.sh 会在这里中断。
-- ----------------------------------------------------------------------------
set @exists := (
  select count(*) from information_schema.columns
  where table_schema = database() and table_name = 'biz_merchant'
    and column_name = 'promoter_enabled'
);
set @sql := if(@exists > 0,
  'select ''biz_merchant.promoter_enabled already exists'' as msg',
  'alter table biz_merchant add column promoter_enabled char(1) default ''1''
     comment ''推客功能是否启用（1=启用 0=关闭）'' after mock_enabled');
prepare stmt from @sql;
execute stmt;
deallocate prepare stmt;

-- 回填：存量商户一律按「已启用」处理（理由见上）。
-- 空串也一起洗掉 —— char(1) 允许写 ''，那种值前端判断不出来。
update biz_merchant set promoter_enabled = '1'
 where promoter_enabled is null or promoter_enabled = '';

select concat('promoter_enabled 启用=',
              sum(promoter_enabled = '1'),
              ' 关闭=', sum(promoter_enabled = '0')) as result
  from biz_merchant where del_flag = '0';
