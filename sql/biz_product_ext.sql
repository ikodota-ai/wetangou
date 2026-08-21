-- ============================================================
-- biz_product_ext：商品扩展表（1:1 挂 biz_product，承载类型差异字段）
--
-- 背景：commit f99942c0「主表瘦身 + biz_product_ext 1:1 扩展表」把 13 个
--       类型差异字段从 biz_product 挪到本表，ProductMapper.xml 的
--       selectProductList 会 left join 它，但**当时漏了建表 SQL**。
--       结果：全新库跑完所有 sql/ 脚本后，打开「商品管理」列表直接 500
--       （Table 'xxx.biz_product_ext' doesn't exist）。
--       本脚本补齐建表，字段与 com.ruoyi.biz.domain.ProductExt 一一对应。
--
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p <库名> < sql/biz_product_ext.sql
-- 幂等：create table if not exists，可重复执行
-- ============================================================

create table if not exists biz_product_ext (
  product_id             bigint(20)     not null                comment '=biz_product.product_id',

  -- 代金券（VOUCHER）
  voucher_auto_name      tinyint(1)     default 1               comment '券名是否自动生成',
  voucher_min_consume    decimal(10,2)  default 0.00            comment '最低消费门槛',
  voucher_scope_type     varchar(20)    default 'ALL'           comment '适用范围类型（ALL/CATEGORY/STORE）',
  voucher_scope_ids      varchar(500)   default null            comment '适用范围 ID 集合（逗号分隔）',

  -- 组合券包（COMBO）
  combo_total_value      decimal(10,2)  default 0.00            comment '券包总价值（原价合计）',
  combo_sale_type        varchar(20)    default 'LIMIT'         comment '售卖方式（LIMIT 限量 / UNLIMIT 不限量）',
  combo_auto_extend_days int(11)        default 30              comment '到期自动延期天数',
  outer_subitem_id       varchar(100)   default null            comment '外部子品 ID（对接三方货架）',
  combo_items_json       text                                   comment '券包子项明细 JSON',

  -- 团购套餐（GROUPON）
  groupon_pick_rule      varchar(50)    default 'ALL'           comment '套餐选择规则（ALL 全选 / OPTIONAL 可选）',
  groupon_actual_count   int(11)        default 0               comment '实际可选份数',

  -- 公共
  daily_use_limit        int(11)        default 0               comment '每日可用次数上限（0=不限）',
  refund_rule_type       varchar(50)    default 'ANYTIME'       comment '退款规则（ANYTIME 随时退 / EXPIRE 过期退 / NONE 不可退）',

  create_time            datetime       default current_timestamp,
  update_time            datetime       default current_timestamp on update current_timestamp,
  primary key (product_id)
) engine=innodb default charset=utf8mb4 comment = '商品扩展表（类型差异字段 + 6tab 详细字段）';

-- 存量商品补一行空扩展记录（left join 本就容错，这里只是让编辑页有默认值可读）
insert into biz_product_ext (product_id)
select p.product_id from biz_product p
where not exists (select 1 from biz_product_ext e where e.product_id = p.product_id);
