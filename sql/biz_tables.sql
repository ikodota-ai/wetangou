-- ----------------------------
-- 多店铺到店自取小程序 业务表 (biz_*)
-- 基于 RuoYi-Vue 二次开发，遵循 RuoYi 建表规范，便于代码生成器识别
-- 字符集 utf8mb4，主键 bigint auto_increment，含标准审计字段
-- ----------------------------

-- ----------------------------
-- 1. 门店表
-- ----------------------------
drop table if exists biz_store;
create table biz_store (
  store_id        bigint(20)      not null auto_increment    comment '门店ID',
  store_name      varchar(100)    not null                   comment '门店名称',
  logo            varchar(255)    default ''                 comment '门店Logo',
  province        varchar(50)     default ''                 comment '省',
  city            varchar(50)     default ''                 comment '市',
  district        varchar(50)     default ''                 comment '区',
  address         varchar(255)    default ''                 comment '详细地址',
  longitude       decimal(10,6)   default null               comment '经度',
  latitude        decimal(10,6)   default null               comment '纬度',
  phone           varchar(20)     default ''                 comment '门店电话',
  service_phone   varchar(20)     default ''                 comment '客服电话',
  service_qrcode  varchar(255)    default ''                 comment '客服二维码',
  business_hours  varchar(100)    default ''                 comment '营业时间',
  intro           varchar(500)    default ''                 comment '门店简介',
  services        varchar(255)    default ''                 comment '服务设置（字典biz_store_service，多选逗号分隔）',
  sort            int(4)          default 0                  comment '显示顺序',
  status          char(1)         default '0'                comment '状态（0正常 1停用）',
  del_flag        char(1)         default '0'                comment '删除标志（0存在 2删除）',
  create_by       varchar(64)     default ''                 comment '创建者',
  create_time     datetime                                   comment '创建时间',
  update_by       varchar(64)     default ''                 comment '更新者',
  update_time     datetime                                   comment '更新时间',
  remark          varchar(255)    default null               comment '备注',
  primary key (store_id)
) engine=innodb auto_increment=100 comment = '门店表';

-- ----------------------------
-- 2. 后台账号-门店映射表（数据权限隔离）
-- ----------------------------
drop table if exists biz_store_user;
create table biz_store_user (
  id              bigint(20)      not null auto_increment    comment '主键',
  store_id        bigint(20)      not null                   comment '门店ID',
  user_id         bigint(20)      not null                   comment '系统用户ID',
  create_time     datetime                                   comment '创建时间',
  primary key (id),
  unique key uk_store_user (store_id, user_id)
) engine=innodb comment = '账号门店关联表';

-- ----------------------------
-- 3. 门店相册表
-- ----------------------------
drop table if exists biz_store_album;
create table biz_store_album (
  album_id        bigint(20)      not null auto_increment    comment '相册ID',
  store_id        bigint(20)      not null                   comment '门店ID',
  image_url       varchar(255)    not null                   comment '图片地址',
  album_type      char(1)         default '0'                comment '类型（0环境 1菜品 2门面）',
  sort            int(4)          default 0                  comment '显示顺序',
  create_by       varchar(64)     default ''                 comment '创建者',
  create_time     datetime                                   comment '创建时间',
  update_by       varchar(64)     default ''                 comment '更新者',
  update_time     datetime                                   comment '更新时间',
  primary key (album_id),
  key idx_store (store_id)
) engine=innodb comment = '门店相册表';

-- ----------------------------
-- 4. 会员表
-- ----------------------------
drop table if exists biz_member;
create table biz_member (
  member_id       bigint(20)      not null auto_increment    comment '会员ID',
  openid          varchar(64)     not null                   comment '微信openid',
  unionid         varchar(64)     default ''                 comment '微信unionid',
  nickname        varchar(64)     default ''                 comment '昵称',
  avatar          varchar(255)    default ''                 comment '头像',
  phone           varchar(20)     default ''                 comment '手机号',
  gender          char(1)         default '0'                comment '性别（0未知 1男 2女）',
  birthday        date            default null               comment '生日',
  status          char(1)         default '0'                comment '状态（0正常 1停用）',
  last_login_time datetime                                   comment '最后登录时间',
  invite_by       bigint(20)      default null               comment '邀请人 member_id',
  invite_time     datetime                                   comment '邀请绑定时间',
  create_time     datetime                                   comment '创建时间',
  update_time     datetime                                   comment '更新时间',
  remark          varchar(255)    default null               comment '备注',
  primary key (member_id),
  unique key uk_openid (openid)
) engine=innodb auto_increment=1000 comment = '会员表';

-- ----------------------------
-- 5. 商品分类表
-- ----------------------------
drop table if exists biz_category;
create table biz_category (
  category_id     bigint(20)      not null auto_increment    comment '分类ID',
  store_id        bigint(20)      default 0                  comment '门店ID（0=平台通用）',
  category_name   varchar(50)     not null                   comment '分类名称',
  icon            varchar(255)    default ''                 comment '分类图标',
  sort            int(4)          default 0                  comment '显示顺序',
  status          char(1)         default '0'                comment '状态（0正常 1停用）',
  create_by       varchar(64)     default ''                 comment '创建者',
  create_time     datetime                                   comment '创建时间',
  update_by       varchar(64)     default ''                 comment '更新者',
  update_time     datetime                                   comment '更新时间',
  primary key (category_id)
) engine=innodb auto_increment=100 comment = '商品分类表';

-- ----------------------------
-- 6. 商品表（套餐/买单/预约）
-- ----------------------------
drop table if exists biz_product;
create table biz_product (
  product_id      bigint(20)      not null auto_increment    comment '商品ID',
  store_id        bigint(20)      default 0                  comment '门店ID（0=平台商品，主门店）',
  store_ids       varchar(500)    default ''                 comment '适用门店ID集合（逗号分隔）',
  category_id     bigint(20)      default null               comment '分类ID',
  product_name    varchar(100)    not null                   comment '商品名称',
  subtitle        varchar(255)    default ''                 comment '副标题',
  cover           varchar(255)    default ''                 comment '封面图',
  images          varchar(2000)   default ''                 comment '轮播图（逗号分隔）',
  product_type    char(1)         default '0'                comment '类型（0到店自取 1到店买单 2预约服务）',
  price           decimal(10,2)   default 0.00               comment '售价',
  market_price    decimal(10,2)   default 0.00               comment '市场价',
  stock           int(11)         default 0                  comment '库存',
  sales           int(11)         default 0                  comment '销量',
  validity_days   int(4)          default 30                 comment '有效天数',
  detail          longtext                                   comment '图文详情',
  notice          longtext                                   comment '购买须知',
  sort            int(4)          default 0                  comment '显示顺序',
  status          char(1)         default '0'                comment '状态（0上架 1下架）',
  del_flag        char(1)         default '0'                comment '删除标志（0存在 2删除）',
  create_by       varchar(64)     default ''                 comment '创建者',
  create_time     datetime                                   comment '创建时间',
  update_by       varchar(64)     default ''                 comment '更新者',
  update_time     datetime                                   comment '更新时间',
  remark          varchar(255)    default null               comment '备注',
  primary key (product_id),
  key idx_store (store_id),
  key idx_category (category_id)
) engine=innodb auto_increment=1000 comment = '商品表';

-- ----------------------------
-- 7. 商品-门店上架关系表（平台商品被门店选用）
-- ----------------------------
drop table if exists biz_product_store;
create table biz_product_store (
  id              bigint(20)      not null auto_increment    comment '主键',
  product_id      bigint(20)      not null                   comment '商品ID',
  store_id        bigint(20)      not null                   comment '门店ID',
  price           decimal(10,2)   default null               comment '门店覆盖价格（空=用商品价）',
  stock           int(11)         default null               comment '门店库存',
  on_sale         char(1)         default '0'                comment '是否上架（0上架 1下架）',
  create_time     datetime                                   comment '创建时间',
  primary key (id),
  unique key uk_product_store (product_id, store_id)
) engine=innodb comment = '商品门店上架关系表';

-- ----------------------------
-- 8. 订单表（到店自取/买单，含核销码）
-- ----------------------------
drop table if exists biz_order;
create table biz_order (
  order_id        bigint(20)      not null auto_increment    comment '订单ID',
  order_no        varchar(32)     not null                   comment '订单编号',
  store_id        bigint(20)      not null                   comment '门店ID',
  member_id       bigint(20)      not null                   comment '会员ID',
  product_id      bigint(20)      default null               comment '商品ID',
  product_name    varchar(100)    default ''                 comment '商品名称快照',
  product_cover   varchar(255)    default ''                 comment '商品封面快照',
  order_type      char(1)         default '0'                comment '类型（0到店自取 1到店买单）',
  price           decimal(10,2)   default 0.00               comment '单价',
  num             int(11)         default 1                  comment '数量',
  total_amount    decimal(10,2)   default 0.00               comment '订单金额',
  discount_amount decimal(10,2)   default 0.00               comment '优惠金额（代金券）',
  pay_amount      decimal(10,2)   default 0.00               comment '实付金额',
  member_voucher_id bigint(20)    default null               comment '使用的会员代金券ID',
  distributor_id  bigint(20)      default null               comment '推客ID（分销来源）',
  status          char(1)         default '0'                comment '状态（0待付款 1待使用 2已完成 3已退款 4已取消）',
  verify_code     varchar(32)     default null               comment '核销码（支付后生成，未支付为NULL以避开唯一索引）',
  verify_time     datetime                                   comment '核销时间',
  verify_user     varchar(64)     default ''                 comment '核销人',
  pay_time        datetime                                   comment '支付时间',
  pay_no          varchar(64)     default ''                 comment '微信支付单号',
  expire_time     datetime                                   comment '核销有效期',
  create_by       varchar(64)     default ''                 comment '创建者',
  create_time     datetime                                   comment '创建时间',
  update_by       varchar(64)     default ''                 comment '更新者',
  update_time     datetime                                   comment '更新时间',
  remark          varchar(255)    default null               comment '备注',
  primary key (order_id),
  unique key uk_order_no (order_no),
  unique key uk_verify_code (verify_code),
  key idx_store (store_id),
  key idx_member (member_id)
) engine=innodb auto_increment=100000 comment = '订单表';

-- ----------------------------
-- 9. 在线预约表
-- ----------------------------
drop table if exists biz_booking;
create table biz_booking (
  booking_id      bigint(20)      not null auto_increment    comment '预约场次ID',
  booking_no      varchar(32)     not null                   comment '预约场次编号',
  store_id        bigint(20)      not null                   comment '门店ID',
  product_id      bigint(20)      default null               comment '预约服务/商品ID',
  service_name    varchar(100)    default ''                 comment '服务名称',
  booking_date    date            not null                   comment '预约日期',
  time_slot       varchar(50)     default ''                 comment '预约时段',
  status          char(1)         default '0'                comment '状态（0开放中 1已确认 2已完成 3已关闭）',
  remark          varchar(255)    default null               comment '备注',
  create_by       varchar(64)     default ''                 comment '创建者',
  create_time     datetime                                   comment '创建时间',
  update_by       varchar(64)     default ''                 comment '更新者',
  update_time     datetime                                   comment '更新时间',
  primary key (booking_id),
  unique key uk_booking_no (booking_no),
  key idx_store (store_id)
) engine=innodb auto_increment=100000 comment = '在线预约场次表';

-- ----------------------------
-- 9.1 预约报名明细表（一个场次可多会员报名，各自保留人数）
-- ----------------------------
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

-- ----------------------------
-- 10. 买单流水表（店员现场确认+代金券）
-- ----------------------------
drop table if exists biz_pay_bill;
create table biz_pay_bill (
  bill_id         bigint(20)      not null auto_increment    comment '买单ID',
  bill_no         varchar(32)     not null                   comment '买单编号',
  order_id        bigint(20)      default null               comment '关联订单ID',
  store_id        bigint(20)      not null                   comment '门店ID',
  member_id       bigint(20)      not null                   comment '会员ID',
  amount          decimal(10,2)   default 0.00               comment '消费金额',
  member_voucher_id bigint(20)    default null               comment '使用的会员代金券ID',
  discount_amount decimal(10,2)   default 0.00               comment '优惠金额',
  pay_amount      decimal(10,2)   default 0.00               comment '实付金额',
  confirm_user    varchar(64)     default ''                 comment '确认店员',
  confirm_time    datetime                                   comment '确认时间',
  status          char(1)         default '0'                comment '状态（0待确认 1待支付 2已完成 3已取消）',
  create_time     datetime                                   comment '创建时间',
  update_time     datetime                                   comment '更新时间',
  primary key (bill_id),
  unique key uk_bill_no (bill_no),
  key idx_store (store_id),
  key idx_member (member_id)
) engine=innodb auto_increment=100000 comment = '买单流水表';

-- ----------------------------
-- 11. 推客表
-- ----------------------------
drop table if exists biz_distributor;
create table biz_distributor (
  distributor_id  bigint(20)      not null auto_increment    comment '推客ID',
  member_id       bigint(20)      not null                   comment '会员ID',
  level           int(4)          default 1                  comment '推客等级',
  total_commission decimal(12,2)  default 0.00               comment '累计佣金',
  available_amount decimal(12,2)  default 0.00               comment '可提现金额',
  frozen_amount   decimal(12,2)   default 0.00               comment '冻结金额',
  withdraw_amount decimal(12,2)   default 0.00               comment '已提现金额',
  status          char(1)         default '0'                comment '状态（0正常 1停用）',
  join_time       datetime                                   comment '成为推客时间',
  create_time     datetime                                   comment '创建时间',
  update_time     datetime                                   comment '更新时间',
  primary key (distributor_id),
  unique key uk_member (member_id)
) engine=innodb auto_increment=1000 comment = '推客表';

-- ----------------------------
-- 12. 佣金明细表
-- ----------------------------
drop table if exists biz_commission;
create table biz_commission (
  commission_id   bigint(20)      not null auto_increment    comment '佣金ID',
  distributor_id  bigint(20)      not null                   comment '推客ID',
  order_id        bigint(20)      default null               comment '订单ID',
  store_id        bigint(20)      default null               comment '门店ID',
  amount          decimal(10,2)   default 0.00               comment '佣金金额',
  rate            decimal(5,2)    default 0.00               comment '佣金比例(%)',
  status          char(1)         default '0'                comment '状态（0待结算 1已结算 2已失效）',
  settle_time     datetime                                   comment '结算时间',
  create_time     datetime                                   comment '创建时间',
  primary key (commission_id),
  key idx_distributor (distributor_id)
) engine=innodb comment = '佣金明细表';

-- ----------------------------
-- 13. 佣金规则表（后台可配）
-- ----------------------------
drop table if exists biz_commission_rule;
create table biz_commission_rule (
  rule_id         bigint(20)      not null auto_increment    comment '规则ID',
  rule_name       varchar(50)     not null                   comment '规则名称',
  store_id        bigint(20)      default 0                  comment '门店ID（0=全平台）',
  category_id     bigint(20)      default null               comment '分类ID',
  product_id      bigint(20)      default null               comment '商品ID',
  level           int(4)          default 1                  comment '适用推客等级',
  rate            decimal(5,2)    default 0.00               comment '佣金比例(%)',
  settle_days     int(4)          default 7                  comment '结算冷静期(天)',
  status          char(1)         default '0'                comment '状态（0启用 1停用）',
  create_by       varchar(64)     default ''                 comment '创建者',
  create_time     datetime                                   comment '创建时间',
  update_by       varchar(64)     default ''                 comment '更新者',
  update_time     datetime                                   comment '更新时间',
  primary key (rule_id)
) engine=innodb comment = '佣金规则表';

-- ----------------------------
-- 14. 提现记录表
-- ----------------------------
drop table if exists biz_withdraw;
create table biz_withdraw (
  withdraw_id     bigint(20)      not null auto_increment    comment '提现ID',
  withdraw_no     varchar(32)     not null                   comment '提现单号',
  distributor_id  bigint(20)      not null                   comment '推客ID',
  amount          decimal(10,2)   default 0.00               comment '提现金额',
  withdraw_type   char(1)         default '0'                comment '方式（0微信 1支付宝 2银行卡）',
  account         varchar(100)    default ''                 comment '收款账户',
  account_name    varchar(50)     default ''                 comment '收款人姓名',
  status          char(1)         default '0'                comment '状态（0处理中 1成功 2失败）',
  apply_time      datetime                                   comment '申请时间',
  finish_time     datetime                                   comment '完成时间',
  fail_reason     varchar(255)    default ''                 comment '失败原因',
  create_time     datetime                                   comment '创建时间',
  primary key (withdraw_id),
  unique key uk_withdraw_no (withdraw_no),
  key idx_distributor (distributor_id)
) engine=innodb auto_increment=100000 comment = '提现记录表';

-- ----------------------------
-- 15. 代金券模板表
-- ----------------------------
drop table if exists biz_voucher;
create table biz_voucher (
  voucher_id      bigint(20)      not null auto_increment    comment '代金券ID',
  store_id        bigint(20)      default 0                  comment '门店ID（0=全平台通用）',
  voucher_name    varchar(50)     not null                   comment '代金券名称',
  face_value      decimal(10,2)   default 0.00               comment '面额',
  threshold       decimal(10,2)   default 0.00               comment '使用门槛（满减）',
  total           int(11)         default 0                  comment '发放总量（0=不限）',
  received        int(11)         default 0                  comment '已领取数量',
  valid_from      datetime                                   comment '有效期开始',
  valid_to        datetime                                   comment '有效期结束',
  valid_days      int(4)          default 0                  comment '领取后有效天数（0=用固定日期）',
  status          char(1)         default '0'                comment '状态（0启用 1停用）',
  create_by       varchar(64)     default ''                 comment '创建者',
  create_time     datetime                                   comment '创建时间',
  update_by       varchar(64)     default ''                 comment '更新者',
  update_time     datetime                                   comment '更新时间',
  primary key (voucher_id)
) engine=innodb auto_increment=100 comment = '代金券模板表';

-- ----------------------------
-- 16. 会员代金券表
-- ----------------------------
drop table if exists biz_member_voucher;
create table biz_member_voucher (
  id              bigint(20)      not null auto_increment    comment '主键',
  voucher_id      bigint(20)      not null                   comment '代金券模板ID',
  member_id       bigint(20)      not null                   comment '会员ID',
  face_value      decimal(10,2)   default 0.00               comment '面额快照',
  threshold       decimal(10,2)   default 0.00               comment '门槛快照',
  status          char(1)         default '0'                comment '状态（0未使用 1已使用 2已过期）',
  use_order_id    bigint(20)      default null               comment '使用订单ID',
  expire_time     datetime                                   comment '过期时间',
  get_time        datetime                                   comment '领取时间',
  use_time        datetime                                   comment '使用时间',
  primary key (id),
  key idx_member (member_id)
) engine=innodb comment = '会员代金券表';

-- ----------------------------
-- 17. 微信分账接收方表
-- ----------------------------
drop table if exists biz_settle_account;
create table biz_settle_account (
  account_id      bigint(20)      not null auto_increment    comment '账户ID',
  owner_type      char(1)         default '0'                comment '归属类型（0门店 1推客 2平台）',
  owner_id        bigint(20)      default null               comment '归属ID',
  receiver_type   varchar(20)     default 'MERCHANT_ID'      comment '分账接收方类型',
  receiver_account varchar(64)    default ''                 comment '分账接收方账号',
  receiver_name   varchar(64)     default ''                 comment '接收方名称',
  rate            decimal(5,2)    default 0.00               comment '分账比例(%)',
  status          char(1)         default '0'                comment '状态（0正常 1停用）',
  create_time     datetime                                   comment '创建时间',
  update_time     datetime                                   comment '更新时间',
  primary key (account_id)
) engine=innodb comment = '分账接收方表';

-- ----------------------------
-- 18. 分账明细表
-- ----------------------------
drop table if exists biz_settle_record;
create table biz_settle_record (
  record_id       bigint(20)      not null auto_increment    comment '分账记录ID',
  order_id        bigint(20)      not null                   comment '订单ID',
  out_order_no    varchar(64)     default ''                 comment '分账单号',
  receiver_account varchar(64)    default ''                 comment '接收方账号',
  amount          decimal(10,2)   default 0.00               comment '分账金额',
  status          char(1)         default '0'                comment '状态（0处理中 1成功 2失败）',
  finish_time     datetime                                   comment '完成时间',
  create_time     datetime                                   comment '创建时间',
  primary key (record_id),
  key idx_order (order_id)
) engine=innodb comment = '分账明细表';

-- ----------------------------
-- 19. 协议表
-- ----------------------------
drop table if exists biz_agreement;
create table biz_agreement (
  agreement_id    bigint(20)      not null auto_increment    comment '协议ID',
  agreement_type  varchar(20)     not null                   comment '类型（user用户 privacy隐私 distributor推客）',
  title           varchar(100)    default ''                 comment '标题',
  content         longtext                                   comment '协议内容',
  store_id        bigint(20)      default 0                  comment '门店ID（0=全平台）',
  status          char(1)         default '0'                comment '状态（0启用 1停用）',
  create_by       varchar(64)     default ''                 comment '创建者',
  create_time     datetime                                   comment '创建时间',
  update_by       varchar(64)     default ''                 comment '更新者',
  update_time     datetime                                   comment '更新时间',
  primary key (agreement_id)
) engine=innodb auto_increment=100 comment = '协议表';
