-- ----------------------------
-- 预约改造：主表(场次) + 报名明细子表
-- 主表 biz_booking 不再直接挂会员；会员报名写入 biz_booking_member
-- 一个场次可被多个会员报名，每条报名保留各自人数
--
-- 幂等说明（2026-08-21 修）：
--   本脚本是「存量库」迁移脚本。新版 sql/biz_tables.sql 建表时 biz_booking 已是场次结构、
--   且已建好 biz_booking_member，因此：
--     1) 明细表改 create table if not exists（原来是 drop + create，重复跑会丢报名数据）
--     2) 迁移与 drop column 全部包在「biz_booking.member_id 存在」判断里
--   → 新库跑它是 no-op，存量库跑它完成迁移，重复跑安全。
-- ----------------------------

-- 1) 报名明细子表（存在则跳过，绝不 drop —— 里面是真实报名数据）
create table if not exists biz_booking_member (
  id              bigint(20)      not null auto_increment    comment '报名ID',
  booking_id      bigint(20)      not null                   comment '预约场次ID',
  member_id       bigint(20)      not null                   comment '报名会员ID',
  contact         varchar(50)     default ''                 comment '联系人',
  phone           varchar(20)     default ''                 comment '联系电话',
  people          int(4)          default 1                  comment '本条报名人数',
  status          char(1)         default '0'                comment '状态（0已报名 1已取消）',
  remark          varchar(255)    default null               comment '备注',
  create_time     datetime                                   comment '报名时间',
  update_time     datetime                                   comment '更新时间',
  primary key (id),
  key idx_booking (booking_id),
  key idx_member (member_id)
) engine=innodb auto_increment=1 comment = '预约报名明细表';

-- 2) 判断主表是否还是「旧结构」（带 member_id 个人字段）
set @has_old := (select count(*) from information_schema.columns
                 where table_schema = database()
                   and table_name = 'biz_booking'
                   and column_name = 'member_id');

-- 3) 旧结构才迁移：已有单人预约转成一条报名明细
set @sql := if(@has_old > 0,
  'insert into biz_booking_member (booking_id, member_id, contact, phone, people, status, remark, create_time, update_time)
     select booking_id, member_id, contact, phone, ifnull(people,1),
            case when status = ''3'' then ''1'' else ''0'' end, remark, create_time, update_time
     from biz_booking where member_id is not null',
  'select ''biz_booking 已是场次结构，跳过数据迁移'' as msg');
prepare stmt from @sql; execute stmt; deallocate prepare stmt;

-- 4) 旧结构才删除主表上的个人报名字段
set @sql := if(@has_old > 0,
  'alter table biz_booking drop column member_id, drop column people, drop column contact, drop column phone',
  'select ''biz_booking 无个人报名字段，跳过 drop column'' as msg');
prepare stmt from @sql; execute stmt; deallocate prepare stmt;
