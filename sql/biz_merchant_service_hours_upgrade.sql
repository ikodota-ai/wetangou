-- 商家档案：客服服务时间（弹窗显示"客服工作时间 xxx"那行）
-- biz_merchant 和 biz_store 都加；merchant 是商家级缺省，store 是门店级覆盖
--
-- 幂等说明（2026-08-21 修）：
--   新版 sql/biz_tenant_tables.sql / biz_tables.sql 建表时已含 service_hours，
--   本脚本只为存量库补列。原来是裸 ALTER，新库跑会报
--   ERROR 1054 Unknown column 'business_hours'（AFTER 的锚点列不存在）/ 1060 Duplicate column。
--   现改为按 information_schema 判断，缺列才 ADD，且不依赖 AFTER 锚点。

drop procedure if exists biz_add_col_tmp;
delimiter $$
create procedure biz_add_col_tmp(in p_table varchar(64), in p_column varchar(64), in p_ddl varchar(500))
begin
  if not exists (select 1 from information_schema.columns
                 where table_schema = database() and table_name = p_table and column_name = p_column) then
    set @sql = concat('alter table `', p_table, '` add column ', p_ddl);
    prepare stmt from @sql; execute stmt; deallocate prepare stmt;
  end if;
end $$
delimiter ;

call biz_add_col_tmp('biz_merchant', 'business_hours', "business_hours varchar(100) DEFAULT '' COMMENT '营业时间'");
call biz_add_col_tmp('biz_merchant', 'service_hours',  "service_hours varchar(100) DEFAULT '' COMMENT '客服服务时间'");
call biz_add_col_tmp('biz_store',    'business_hours', "business_hours varchar(100) DEFAULT '' COMMENT '营业时间'");
call biz_add_col_tmp('biz_store',    'service_hours',  "service_hours varchar(100) DEFAULT '' COMMENT '客服服务时间'");

drop procedure if exists biz_add_col_tmp;
