-- ============================================================================
-- 商品字段缺口补落库（v4）
--
-- 背景：后台商品编辑页有 12 个输入框填了存不下 —— 前端 form 上有字段，
--      提交后 Jackson 因 Product/ProductExt 域无对应属性直接丢弃。
--      运营以为配好了，实际库里什么都没有（357 个商品中只有 2 个有 extra_fee_desc，
--      35 个有 sale_start_date，正是「这两个框从没生效」的证据）。
--
-- 本脚本做两件事：
--   1) 新建 biz_sale_channel 投放渠道字典（+ 5 行种子）
--   2) biz_product_ext 幂等加 7 列，承接原先丢弃的字段
--
-- 为什么放 ext 不放 biz_product：主表 DEFAULT 会架空 null 校验
--   （price/stock/validity_days 已因 DEFAULT 逼 ProductValidator 用 requirePositive 特判），
--   新字段全是可选配置项，放 ext 不引入新的 DEFAULT 陷阱。
--
-- 导入：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_product_field_gap_v4.sql
-- 幂等：可重复执行
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. 投放渠道字典 biz_sale_channel
--
-- 为什么要建表而不是硬编码：抖音来客的「投放渠道」是独立子页，
-- 每个渠道有自己的投放规则说明、分组、可用性 —— 是有业务语义的实体，不是装饰字段。
-- 硬编码在 create.vue 里的 DOUPIN/TOUTIAO/OTHER 是照抄抖音来客的渠道名，
-- 与本项目（微信小程序生态）根本不匹配，所以这里按我们自己的分发场景重定义。
-- ----------------------------------------------------------------------------
create table if not exists biz_sale_channel (
  channel_code   varchar(30)  not null                comment '渠道代码',
  channel_name   varchar(50)  not null                comment '渠道名称',
  channel_group  varchar(30)  default ''              comment '渠道分组（用于前端分组展示）',
  channel_desc   varchar(500) default ''              comment '投放规则说明（前端字段级灰字）',
  icon           varchar(255) default ''              comment '渠道图标',
  sort           int(4)       default 0               comment '显示顺序',
  is_default     tinyint(1)   default 0               comment '新建商品是否默认勾选 0否 1是',
  status         char(1)      default '0'             comment '状态（0启用 1停用）',
  create_time    datetime     default current_timestamp,
  update_time    datetime     default current_timestamp on update current_timestamp,
  primary key (channel_code)
) engine=innodb default charset=utf8mb4 comment='投放渠道字典';

-- 种子：按本项目真实分发场景定义（小程序自有生态），不照抄抖音来客
replace into biz_sale_channel
  (channel_code, channel_name, channel_group, channel_desc, sort, is_default, status)
values
  ('MINI_HOME',   '小程序首页',   'SELF',    '商品出现在小程序首页推荐流，是默认的主要曝光位',                    10, 1, '0'),
  ('MINI_STORE',  '门店详情页',   'SELF',    '顾客进入适用门店主页时可见；不勾选则只能通过直接链接购买',            20, 1, '0'),
  ('DISTRIBUTOR', '推客分享',     'SOCIAL',  '允许推客生成带参二维码/海报分享，成交后计佣金；不勾选则推客看不到该商品', 30, 1, '0'),
  ('GROUP_SHARE', '社群/朋友圈',  'SOCIAL',  '允许顾客分享商品卡片到微信会话与朋友圈',                          40, 1, '0'),
  ('OFFLINE_QR',  '门店物料码',   'OFFLINE', '用于印制门店台卡/海报的静态码，扫码直达该商品详情',                 50, 0, '0');

-- ----------------------------------------------------------------------------
-- 2. biz_product_ext 幂等加列（7 列，承接原先被丢弃的字段）
-- ----------------------------------------------------------------------------
drop procedure if exists biz_ext_add_col;
delimiter $$
create procedure biz_ext_add_col(in col varchar(64), in ddl varchar(1000))
begin
  if not exists(select 1 from information_schema.columns
                where table_schema = database()
                  and table_name = 'biz_product_ext'
                  and column_name = col) then
    set @s := concat('alter table biz_product_ext add column ', ddl);
    prepare st from @s; execute st; deallocate prepare st;
  end if;
end $$
delimiter ;

-- 售卖信息
call biz_ext_add_col('sale_channels',
  'sale_channels varchar(500) default '''' comment ''投放渠道代码集合（逗号分隔，见 biz_sale_channel）''');
call biz_ext_add_col('staff_promote',
  'staff_promote tinyint(1) default 0 comment ''职人带货 0否 1是''');

-- 交易规则
call biz_ext_add_col('code_type',
  'code_type varchar(20) default ''MERCHANT'' comment ''券码类型 MERCHANT商家券/PLATFORM平台券''');
call biz_ext_add_col('consume_start_date',
  'consume_start_date datetime default null comment ''顾客可消费开始时间''');
call biz_ext_add_col('consume_end_date',
  'consume_end_date datetime default null comment ''顾客可消费结束时间''');
call biz_ext_add_col('exclude_dates',
  'exclude_dates varchar(1000) default '''' comment ''顾客不可消费日期段 JSON 数组，如 [["2026-01-01","2026-01-03"]]''');
call biz_ext_add_col('daily_time_start',
  'daily_time_start varchar(8) default '''' comment ''每日可消费时段开始 HH:mm:ss''');
call biz_ext_add_col('daily_time_end',
  'daily_time_end varchar(8) default '''' comment ''每日可消费时段结束 HH:mm:ss''');

-- 商品资质（代金券）
call biz_ext_add_col('voucher_rules',
  'voucher_rules varchar(500) default '''' comment ''代金券适用规则集合（逗号分隔 ALL_CATEGORY/ALL_BRAND/...）''');

drop procedure if exists biz_ext_add_col;

-- ----------------------------------------------------------------------------
-- 3. 存量商品：给 ext 补默认投放渠道
--    没有这一步，存量 357 个商品的 sale_channels 为空，
--    等顾客端真按渠道过滤时会全部消失。
-- ----------------------------------------------------------------------------
update biz_product_ext
   set sale_channels = 'MINI_HOME,MINI_STORE,DISTRIBUTOR,GROUP_SHARE'
 where sale_channels is null or sale_channels = '';

-- 没有 ext 行的商品补一行（否则编辑页读不到默认渠道）
insert into biz_product_ext (product_id, sale_channels)
select p.product_id, 'MINI_HOME,MINI_STORE,DISTRIBUTOR,GROUP_SHARE'
  from biz_product p
  left join biz_product_ext e on e.product_id = p.product_id
 where e.product_id is null;

-- ----------------------------------------------------------------------------
-- 4. 渠道字典菜单 + 权限（沿用 biz_product_type 的 perms 风格）
-- ----------------------------------------------------------------------------
set @parent := (select menu_id from sys_menu where menu_name = '商品管理' and menu_type = 'M' limit 1);

delete from sys_role_menu where menu_id in (select menu_id from sys_menu where perms like 'biz:saleChannel:%');
delete from sys_menu where perms like 'biz:saleChannel:%';

insert into sys_menu
 (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
values
 ('投放渠道', ifnull(@parent, 0), 90, 'saleChannel', 'biz/saleChannel/index', 1, '0', 'C', '0', '0', 'biz:saleChannel:list', 'guide', 'admin', sysdate(), '投放渠道字典');

set @m := last_insert_id();
insert into sys_menu
 (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
values
 ('渠道查询', @m, 1, '', '', 1, '0', 'F', '0', '0', 'biz:saleChannel:query',  '#', 'admin', sysdate(), ''),
 ('渠道新增', @m, 2, '', '', 1, '0', 'F', '0', '0', 'biz:saleChannel:add',    '#', 'admin', sysdate(), ''),
 ('渠道修改', @m, 3, '', '', 1, '0', 'F', '0', '0', 'biz:saleChannel:edit',   '#', 'admin', sysdate(), ''),
 ('渠道删除', @m, 4, '', '', 1, '0', 'F', '0', '0', 'biz:saleChannel:remove', '#', 'admin', sysdate(), '');

-- 平台管理员角色授权（渠道是平台级保底设置，商户不改）
insert into sys_role_menu (role_id, menu_id)
select 1, menu_id from sys_menu where perms like 'biz:saleChannel:%'
   and not exists (select 1 from sys_role_menu rm where rm.role_id = 1 and rm.menu_id = sys_menu.menu_id);

select 'biz_product_field_gap_v4 done' as msg,
       (select count(*) from biz_sale_channel) as channels,
       (select count(*) from information_schema.columns
         where table_schema = database() and table_name = 'biz_product_ext') as ext_cols;
