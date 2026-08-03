-- ----------------------------
-- 预约报名新增员工审核字段（幂等）
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_booking_staff_review.sql
--
-- 改造要点：
-- 1) biz_booking_member 增加 confirm_user / confirm_time / review_remark
-- 2) status 字典扩展：0=已报名 1=已取消 2=已确认到店 3=已拒绝
--    （原本是 char(1)，单字符够用）
-- ----------------------------
drop procedure if exists biz_add_column;
delimiter $$
create procedure biz_add_column(in p_table varchar(64), in p_column varchar(64), in p_ddl varchar(500))
begin
  if not exists (select 1 from information_schema.columns
                 where table_schema = database() and table_name = p_table and column_name = p_column) then
    set @sql = concat('alter table `', p_table, '` add column ', p_ddl);
    prepare stmt from @sql; execute stmt; deallocate prepare stmt;
  end if;
end $$
delimiter ;

call biz_add_column('biz_booking_member', 'confirm_user',
  "confirm_user varchar(64) default null comment '确认员工用户名' after status");
call biz_add_column('biz_booking_member', 'confirm_time',
  "confirm_time datetime default null comment '确认/拒绝时间' after confirm_user");
call biz_add_column('biz_booking_member', 'review_remark',
  "review_remark varchar(255) default null comment '员工审核备注' after confirm_time");

drop procedure if exists biz_add_column;
