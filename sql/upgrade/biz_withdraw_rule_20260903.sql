-- ============================================================================
-- 提现规则（withdraw.* 系列 sys_config + 后台「提现规则」菜单）
--
-- 背景（微信小程序审核驳回原文）：
--   「小程序服务涉及提现服务，需在提现页面清晰展示相关提现规则，包括但不限于
--     可提现额度、每日提现次数、提现时间、到账时间等，请补充完善提现规则
--     再提交代码审核。」
--
-- 光在提现页贴一段文案是过不了的：原本 POST /api/distributor/withdraw 只校验
-- 「金额>0 且不超可提现余额」，起提金额、每日次数、受理时段这些规则压根不存在。
-- 页面写「单笔最低 10 元」而实际提 0.01 元照样成功，属于展示与实际不符，
-- 二审一样会被打回，用户也会当成 bug。所以规则先在服务端真实生效
-- （WithdrawRuleService.validate），展示接口 GET /api/distributor/withdraw/rules
-- 再从同一处读，两边不可能对不上。
--
-- 默认值选取理由：
--   起提 10 元 / 单笔上限 5000 元 / 每日 3 次 / 9:00-21:00 受理 / 免手续费 /
--   1-3 个工作日到账 —— 与代码里的 DEFAULT_* 常量逐一对齐，
--   这样「库里没有这条配置」和「库里配了默认值」两种情况行为完全一致。
--
-- 导入：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/upgrade/biz_withdraw_rule_20260903.sql
--       ↑ 必须带 --default-character-set=utf8mb4，否则中文配置名/菜单名会存成乱码
-- 幂等：可重复执行
-- ============================================================================

-- ---------------------------------------------------------------- 1) 配置种子
insert into sys_config (config_name, config_key, config_value, config_type, create_by, create_time, remark)
select '单笔最低提现金额', 'withdraw.minAmount', '10', 'N', 'admin', sysdate(), '提现规则：低于该金额不允许提交申请（元）'
 where not exists (select 1 from sys_config c where c.config_key = 'withdraw.minAmount');

insert into sys_config (config_name, config_key, config_value, config_type, create_by, create_time, remark)
select '单笔最高提现金额', 'withdraw.maxAmount', '5000', 'N', 'admin', sysdate(), '提现规则：单笔上限（元），0=不限'
 where not exists (select 1 from sys_config c where c.config_key = 'withdraw.maxAmount');

insert into sys_config (config_name, config_key, config_value, config_type, create_by, create_time, remark)
select '每日提现次数上限', 'withdraw.dailyTimes', '3', 'N', 'admin', sysdate(), '提现规则：每账号每日申请次数，0=不限；已驳回的不占次数'
 where not exists (select 1 from sys_config c where c.config_key = 'withdraw.dailyTimes');

insert into sys_config (config_name, config_key, config_value, config_type, create_by, create_time, remark)
select '提现受理开始小时', 'withdraw.startHour', '9', 'N', 'admin', sysdate(), '提现规则：受理时段起点（0-23）'
 where not exists (select 1 from sys_config c where c.config_key = 'withdraw.startHour');

insert into sys_config (config_name, config_key, config_value, config_type, create_by, create_time, remark)
select '提现受理结束小时', 'withdraw.endHour', '21', 'N', 'admin', sysdate(), '提现规则：受理时段终点（1-24）；与起点相同表示全天受理'
 where not exists (select 1 from sys_config c where c.config_key = 'withdraw.endHour');

insert into sys_config (config_name, config_key, config_value, config_type, create_by, create_time, remark)
select '提现手续费率(%)', 'withdraw.feeRate', '0', 'N', 'admin', sysdate(), '提现规则：手续费百分比，0=不收取'
 where not exists (select 1 from sys_config c where c.config_key = 'withdraw.feeRate');

insert into sys_config (config_name, config_key, config_value, config_type, create_by, create_time, remark)
select '到账时效说明', 'withdraw.arrivalDesc', '审核通过后 1-3 个工作日到账', 'N', 'admin', sysdate(), '提现规则：原样展示在小程序提现页的「到账时间」'
 where not exists (select 1 from sys_config c where c.config_key = 'withdraw.arrivalDesc');

-- ---------------------------------------------------------------- 2) 后台菜单
-- 挂在「平台配置」目录下，与「微信配置」同级。
-- 不写死 menu_id：menu_id 由各脚本插入顺序决定、不同库不一致，
-- 手工指定会改到别人的菜单（sql/upgrade/biz_mpauth_menu_fix.sql 里记着一次真实错授）。
-- 父目录按 path='setting' 现查，缺目录时整段不插。
insert into sys_menu (menu_name, parent_id, order_num, path, component, query, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
select '提现规则', p.menu_id, 2, 'withdrawRule', 'biz/withdrawRule/index', '', 1, 0, 'C', '0', '0', 'biz:withdrawRule:query', 'money', 'admin', sysdate(), '提现起提额/每日次数/受理时段/到账时效'
  from (select menu_id from sys_menu where path = 'setting' and menu_type = 'M' limit 1) p
 where not exists (select 1 from (select menu_id from sys_menu where perms = 'biz:withdrawRule:query' and menu_type = 'C') t);

insert into sys_menu (menu_name, parent_id, order_num, path, component, query, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
select '提现规则查询', p.menu_id, 1, '#', '', '', 1, 0, 'F', '0', '0', 'biz:withdrawRule:query', '#', 'admin', sysdate(), ''
  from (select menu_id from sys_menu where perms = 'biz:withdrawRule:query' and menu_type = 'C' limit 1) p
 where not exists (select 1 from (select menu_id from sys_menu where perms = 'biz:withdrawRule:query' and menu_type = 'F') t);

insert into sys_menu (menu_name, parent_id, order_num, path, component, query, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
select '提现规则修改', p.menu_id, 2, '#', '', '', 1, 0, 'F', '0', '0', 'biz:withdrawRule:edit', '#', 'admin', sysdate(), ''
  from (select menu_id from sys_menu where perms = 'biz:withdrawRule:query' and menu_type = 'C' limit 1) p
 where not exists (select 1 from (select menu_id from sys_menu where perms = 'biz:withdrawRule:edit') t);

-- ---------------------------------------------------------------- 3) 角色绑定
-- 提现规则是平台级资金规则，只给 admin(1) 与平台角色(3)；
-- 代理商/商户不得自行放宽起提额与次数限制。
insert ignore into sys_role_menu(role_id, menu_id)
select r.role_id, m.menu_id
  from sys_menu m
  join (select 1 as role_id union all select 3) r
 where m.perms in ('biz:withdrawRule:query', 'biz:withdrawRule:edit');

select concat('withdraw config rows = ', count(*)) as result
  from sys_config where config_key like 'withdraw.%';
select concat('withdrawRule menu rows = ', count(*)) as result
  from sys_menu where perms like 'biz:withdrawRule:%';
