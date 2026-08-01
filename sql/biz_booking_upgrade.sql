-- ----------------------------
-- 预约改造：主表(场次) + 报名明细子表
-- 主表 biz_booking 不再直接挂会员；会员报名写入 biz_booking_member
-- 一个场次可被多个会员报名，每条报名保留各自人数
-- ----------------------------

-- 1) 报名明细子表
drop table if exists biz_booking_member;
create table biz_booking_member (
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

-- 2) 主表调整为「场次」：迁移旧数据到明细，再删除个人字段
--    先把已有单人预约迁移为一条报名明细
insert into biz_booking_member (booking_id, member_id, contact, phone, people, status, remark, create_time, update_time)
select booking_id, member_id, contact, phone, ifnull(people,1),
       case when status = '3' then '1' else '0' end, remark, create_time, update_time
from biz_booking
where member_id is not null;

-- 3) 删除主表上的个人报名字段（存在才删；如报错可忽略对应行）
alter table biz_booking drop column member_id;
alter table biz_booking drop column people;
alter table biz_booking drop column contact;
alter table biz_booking drop column phone;
