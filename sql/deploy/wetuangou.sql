-- ============================================================
-- Wetangou 业务库初始化（合并版）
--
-- 用法（在 ry_20260417.sql + quartz.sql 之后执行）：
--   mysql --default-character-set=utf8mb4 -uroot -p 库名 < sql/deploy/wetuangou.sql
--   或 Navicat：右键库 → 运行 SQL 文件 → 选本文件（编码选 utf8mb4）
--
-- 幂等：可重复执行
-- 内容：业务建表 + v2 商品模型 + 代理商/会员/预约 + 261 个菜单 + 字典种子
--
-- 生成方式：由 sql/deploy/build-merged.py 从 sql/*.sql 按实测顺序合并
--            （不要手改本文件，改源脚本后重新生成）
-- 生成时间：2026-08-22
-- ============================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================
-- 助手过程（整个脚本只在这里定义一次）
--
-- 原本 6 个业务 SQL 各自用 DELIMITER 定义一份同名/近名的「幂等加列」过程，
-- 而 Navicat / 部分 GUI 客户端不支持 DELIMITER。这里统一定义一次，
-- 后续 80+ 处 CALL 共用，脚本末尾统一清理。
-- ============================================================
DROP PROCEDURE IF EXISTS biz_add_column;
DROP PROCEDURE IF EXISTS biz_add_index;
DROP PROCEDURE IF EXISTS biz_drop_index;
DROP PROCEDURE IF EXISTS add_column_if_missing;

DELIMITER $$

CREATE PROCEDURE biz_add_column(IN p_table VARCHAR(64), IN p_column VARCHAR(64), IN p_ddl VARCHAR(500))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = p_table AND column_name = p_column) THEN
    SET @sql = CONCAT('alter table `', p_table, '` add column ', p_ddl);
    PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
  END IF;
END $$

CREATE PROCEDURE biz_add_index(IN p_table VARCHAR(64), IN p_index VARCHAR(64), IN p_ddl VARCHAR(500))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.statistics
                 WHERE table_schema = DATABASE() AND table_name = p_table AND index_name = p_index) THEN
    SET @sql = CONCAT('alter table `', p_table, '` add ', p_ddl);
    PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
  END IF;
END $$

CREATE PROCEDURE biz_drop_index(IN p_table VARCHAR(64), IN p_index VARCHAR(64))
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.statistics
             WHERE table_schema = DATABASE() AND table_name = p_table AND index_name = p_index) THEN
    SET @sql = CONCAT('alter table `', p_table, '` drop index `', p_index, '`');
    PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
  END IF;
END $$

-- 与 biz_add_column 的区别：第 3 个参数**不含列名**（只有类型和属性）
CREATE PROCEDURE add_column_if_missing(IN p_table VARCHAR(64), IN p_column VARCHAR(64), IN p_definition VARCHAR(500))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = p_table AND column_name = p_column) THEN
    SET @sql = CONCAT('alter table `', p_table, '` add column `', p_column, '` ', p_definition);
    PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
  END IF;
END $$

DELIMITER ;


-- ############################################################
-- 源文件：sql/biz_tables.sql
-- ############################################################

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


-- ############################################################
-- 源文件：sql/biz_tenant_tables.sql
-- ############################################################

-- ----------------------------
-- 多商户 + 代理商 体系新增表（biz_agent / biz_merchant / 小程序代发布）
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_tenant_tables.sql
-- 说明：本脚本只新建表，不改动已有 biz_* 表；存量改造见 sql/biz_tenant_upgrade.sql
-- 层级：平台 → 代理商(biz_agent) → 商户(biz_merchant) → 门店(biz_store)
--       一个商户仅一个小程序 appid，一个商户可有多个门店
-- ----------------------------

-- ----------------------------
-- 1. 代理商表
-- ----------------------------
drop table if exists biz_agent;
create table biz_agent (
  agent_id        bigint(20)      not null auto_increment    comment '代理商ID',
  agent_no        varchar(32)     not null                   comment '代理商编号',
  agent_name      varchar(100)    not null                   comment '代理商名称',
  dept_id         bigint(20)      default null               comment '对应部门ID（sys_dept，用于后台数据权限）',
  contact         varchar(50)     default ''                 comment '联系人',
  phone           varchar(20)     default ''                 comment '联系电话',
  email           varchar(50)     default ''                 comment '邮箱',
  region          varchar(100)    default ''                 comment '代理区域',
  merchant_quota  int(11)         default 0                  comment '可开通商户额度（已向平台购买）',
  used_quota      int(11)         default 0                  comment '已使用商户额度',
  paid_amount     decimal(12,2)   default 0.00               comment '累计向平台缴费金额',
  expire_time     datetime                                   comment '代理资格到期时间（空=不限期）',
  status          char(1)         default '0'                comment '状态（0正常 1停用）',
  del_flag        char(1)         default '0'                comment '删除标志（0存在 2删除）',
  create_by       varchar(64)     default ''                 comment '创建者',
  create_time     datetime                                   comment '创建时间',
  update_by       varchar(64)     default ''                 comment '更新者',
  update_time     datetime                                   comment '更新时间',
  remark          varchar(255)    default null               comment '备注',
  primary key (agent_id),
  unique key uk_agent_no (agent_no),
  key idx_dept (dept_id)
) engine=innodb auto_increment=100 comment = '代理商表';

-- ----------------------------
-- 2. 代理商缴费记录表（平台向代理商收费：加盟费/商户额度/续费）
-- ----------------------------
drop table if exists biz_agent_fee;
create table biz_agent_fee (
  fee_id          bigint(20)      not null auto_increment    comment '缴费ID',
  fee_no          varchar(32)     not null                   comment '缴费单号',
  agent_id        bigint(20)      not null                   comment '代理商ID',
  fee_type        char(1)         default '0'                comment '费用类型（0加盟费 1商户额度 2资格续费 3其他）',
  amount          decimal(12,2)   default 0.00               comment '缴费金额',
  quota_add       int(11)         default 0                  comment '本次增加商户额度',
  months          int(4)          default 0                  comment '本次延长月数',
  pay_channel     char(1)         default '0'                comment '收款方式（0线下转账 1微信 2支付宝 3其他）',
  pay_voucher     varchar(255)    default ''                 comment '付款凭证图片',
  pay_time        datetime                                   comment '到账时间',
  status          char(1)         default '0'                comment '状态（0待确认 1已确认 2已驳回）',
  audit_by        varchar(64)     default ''                 comment '审核人',
  audit_time      datetime                                   comment '审核时间',
  create_by       varchar(64)     default ''                 comment '创建者',
  create_time     datetime                                   comment '创建时间',
  update_by       varchar(64)     default ''                 comment '更新者',
  update_time     datetime                                   comment '更新时间',
  remark          varchar(255)    default null               comment '备注',
  primary key (fee_id),
  unique key uk_fee_no (fee_no),
  key idx_agent (agent_id)
) engine=innodb auto_increment=100000 comment = '代理商缴费记录表';

-- ----------------------------
-- 3. 商户表（一商户一 appid，多门店）
-- ----------------------------
drop table if exists biz_merchant;
create table biz_merchant (
  merchant_id     bigint(20)      not null auto_increment    comment '商户ID',
  merchant_no     varchar(32)     not null                   comment '商户编号',
  merchant_name   varchar(100)    not null                   comment '商户名称',
  agent_id        bigint(20)      default 0                  comment '所属代理商ID（0=平台直营）',
  dept_id         bigint(20)      default null               comment '对应部门ID（sys_dept，用于后台数据权限）',
  logo            varchar(255)    default ''                 comment '商户Logo',
  contact         varchar(50)     default ''                 comment '联系人',
  phone           varchar(20)     default ''                 comment '联系电话',
  service_phone   varchar(20)     default ''                 comment '客服电话',
  service_qrcode  varchar(255)    default ''                 comment '客服二维码图片',
  business_hours  varchar(100)    default ''                 comment '营业时间',
  service_hours   varchar(100)    default ''                 comment '客服服务时间',
  intro           varchar(500)    default ''                 comment '商家简介',
  license_no      varchar(64)     default ''                 comment '营业执照号',
  license_img     varchar(255)    default ''                 comment '营业执照图片',
  appid           varchar(32)     default ''                 comment '小程序AppId（唯一，前台按此识别商户）',
  app_secret      varchar(64)     default ''                 comment '小程序AppSecret',
  mp_auth_mode    char(1)         default '0'                comment '小程序接入方式（0商户自有密钥 1第三方平台代管）',
  pay_mode        char(1)         default '0'                comment '支付方式（0商户自有商户号 1平台统一收款）',
  pay_mch_id      varchar(32)     default ''                 comment '微信支付商户号',
  pay_appid       varchar(32)     default ''                 comment '微信支付AppId（一般同appid）',
  pay_cert_serial varchar(64)     default ''                 comment '微信支付证书序列号',
  pay_key_path    varchar(255)    default ''                 comment '微信支付私钥路径',
  pay_api_v3_key  varchar(64)     default ''                 comment '微信支付APIv3密钥',
  pay_notify_url  varchar(255)    default ''                 comment '支付回调地址（含商户标识）',
  mock_enabled    char(1)         default '1'                comment '联调mock开关（0开启 1关闭）',
  service_expire  datetime                                   comment '服务到期时间（由代理商/平台设定）',
  status          char(1)         default '0'                comment '状态（0正常 1停用）',
  del_flag        char(1)         default '0'                comment '删除标志（0存在 2删除）',
  create_by       varchar(64)     default ''                 comment '创建者',
  create_time     datetime                                   comment '创建时间',
  update_by       varchar(64)     default ''                 comment '更新者',
  update_time     datetime                                   comment '更新时间',
  remark          varchar(255)    default null               comment '备注',
  primary key (merchant_id),
  unique key uk_merchant_no (merchant_no),
  unique key uk_appid (appid),
  key idx_agent (agent_id),
  key idx_dept (dept_id)
) engine=innodb auto_increment=100 comment = '商户表';

-- ----------------------------
-- 4. 商户收费记录表（代理商向其商户收费，平台仅记账不参与资金）
-- ----------------------------
drop table if exists biz_merchant_fee;
create table biz_merchant_fee (
  fee_id          bigint(20)      not null auto_increment    comment '收费ID',
  fee_no          varchar(32)     not null                   comment '收费单号',
  merchant_id     bigint(20)      not null                   comment '商户ID',
  agent_id        bigint(20)      default 0                  comment '收费代理商ID（0=平台直收）',
  fee_type        char(1)         default '0'                comment '费用类型（0开通费 1年费 2增值服务 3其他）',
  amount          decimal(12,2)   default 0.00               comment '收费金额',
  months          int(4)          default 0                  comment '服务月数',
  begin_time      datetime                                   comment '服务开始时间',
  end_time        datetime                                   comment '服务结束时间',
  status          char(1)         default '0'                comment '状态（0未收 1已收 2作废）',
  create_by       varchar(64)     default ''                 comment '创建者',
  create_time     datetime                                   comment '创建时间',
  update_by       varchar(64)     default ''                 comment '更新者',
  update_time     datetime                                   comment '更新时间',
  remark          varchar(255)    default null               comment '备注',
  primary key (fee_id),
  unique key uk_mfee_no (fee_no),
  key idx_merchant (merchant_id),
  key idx_agent (agent_id)
) engine=innodb auto_increment=100000 comment = '商户收费记录表';

-- ----------------------------
-- 5. 后台账号归属表（登录后确定租户上下文：平台/代理商/商户）
-- ----------------------------
drop table if exists biz_merchant_user;
create table biz_merchant_user (
  id              bigint(20)      not null auto_increment    comment '主键',
  user_id         bigint(20)      not null                   comment '系统用户ID（sys_user）',
  user_type       char(1)         default '2'                comment '账号类型（0平台 1代理商 2商户）',
  agent_id        bigint(20)      default 0                  comment '代理商ID（user_type=1/2时有值）',
  merchant_id     bigint(20)      default 0                  comment '商户ID（user_type=2时有值）',
  create_by       varchar(64)     default ''                 comment '创建者',
  create_time     datetime                                   comment '创建时间',
  primary key (id),
  unique key uk_user (user_id),
  key idx_merchant (merchant_id),
  key idx_agent (agent_id)
) engine=innodb comment = '后台账号租户归属表';

-- ----------------------------
-- 6. 小程序授权表（微信第三方平台代管，用于后台代上传/代发布）
-- ----------------------------
drop table if exists biz_mp_auth;
create table biz_mp_auth (
  auth_id         bigint(20)      not null auto_increment    comment '授权ID',
  merchant_id     bigint(20)      not null                   comment '商户ID',
  appid           varchar(32)     not null                   comment '授权方小程序AppId',
  nick_name       varchar(64)     default ''                 comment '小程序名称',
  head_img        varchar(255)    default ''                 comment '小程序头像',
  principal_name  varchar(100)    default ''                 comment '主体名称',
  verify_type     varchar(10)     default ''                 comment '认证类型（-1未认证 0微信认证等）',
  refresh_token   varchar(512)    default ''                 comment '授权方刷新令牌（长期有效，需加密存储）',
  func_info       varchar(255)    default ''                 comment '已授权权限集ID列表',
  auth_status     char(1)         default '0'                comment '授权状态（0已授权 1已取消 2已过期）',
  auth_time       datetime                                   comment '授权时间',
  create_time     datetime                                   comment '创建时间',
  update_time     datetime                                   comment '更新时间',
  primary key (auth_id),
  unique key uk_mp_appid (appid),
  key idx_merchant (merchant_id)
) engine=innodb comment = '小程序第三方平台授权表';

-- ----------------------------
-- 7. 小程序发布记录表（上传代码 → 提审 → 发布 全流程留痕）
-- ----------------------------
drop table if exists biz_mp_release;
create table biz_mp_release (
  release_id      bigint(20)      not null auto_increment    comment '发布ID',
  merchant_id     bigint(20)      not null                   comment '商户ID',
  appid           varchar(32)     not null                   comment '小程序AppId',
  template_id     varchar(32)     default ''                 comment '代码模板ID（第三方平台草稿箱/模板库）',
  user_version    varchar(32)     default ''                 comment '版本号',
  user_desc       varchar(255)    default ''                 comment '版本描述',
  ext_json        text                                       comment '提交时使用的ext.json',
  audit_id        varchar(64)     default ''                 comment '微信审核单号',
  audit_status    char(1)         default '0'                comment '审核状态（0待提交 1审核中 2审核通过 3审核失败 4已撤回）',
  audit_reason    varchar(500)    default ''                 comment '审核失败原因',
  release_status  char(1)         default '0'                comment '发布状态（0未发布 1已发布 2已回退）',
  release_time    datetime                                   comment '发布时间',
  qrcode_url      varchar(255)    default ''                 comment '体验版二维码',
  create_by       varchar(64)     default ''                 comment '创建者',
  create_time     datetime                                   comment '创建时间',
  update_by       varchar(64)     default ''                 comment '更新者',
  update_time     datetime                                   comment '更新时间',
  remark          varchar(255)    default null               comment '备注',
  primary key (release_id),
  key idx_merchant (merchant_id),
  key idx_appid (appid)
) engine=innodb auto_increment=1000 comment = '小程序发布记录表';


-- ############################################################
-- 源文件：sql/biz_tenant_upgrade.sql
-- ############################################################

-- ----------------------------
-- 存量业务表多商户化改造（幂等，可重复执行）
-- 执行顺序：sql/biz_tenant_tables.sql → 本脚本 → sql/biz_tenant_menu.sql
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_tenant_upgrade.sql
--
-- 改造要点：
-- 1) 门店及门店下属业务表增加 merchant_id 并回填为默认商户
-- 2) 会员唯一键 openid → (merchant_id, openid)，不同 appid 的 openid 互不冲突
-- 3) 推客/佣金/提现按商户独立（推客唯一键改为 merchant_id + member_id）
-- 4) 商品分类、代金券、协议保留平台级：merchant_id=0 表示全平台通用
-- ----------------------------

-- ----------------------------
-- 工具：幂等加列 / 加索引 / 删索引
-- ----------------------------


-- ----------------------------
-- 步骤1：门店归属商户
-- ----------------------------
call biz_add_column('biz_store', 'merchant_id', "merchant_id bigint(20) default 0 comment '商户ID' after store_id");
call biz_add_index('biz_store', 'idx_merchant', 'key idx_merchant (merchant_id)');

-- ----------------------------
-- 步骤2：商户强隔离表（merchant_id 必填，0 视为脏数据）
-- ----------------------------
call biz_add_column('biz_store_album', 'merchant_id', "merchant_id bigint(20) default 0 comment '商户ID' after album_id");
call biz_add_index('biz_store_album', 'idx_merchant', 'key idx_merchant (merchant_id)');

call biz_add_column('biz_member', 'merchant_id', "merchant_id bigint(20) default 0 comment '商户ID（会员按商户隔离）' after member_id");
call biz_add_index('biz_member', 'idx_merchant', 'key idx_merchant (merchant_id)');

call biz_add_column('biz_product', 'merchant_id', "merchant_id bigint(20) default 0 comment '商户ID' after product_id");
call biz_add_index('biz_product', 'idx_merchant', 'key idx_merchant (merchant_id)');

call biz_add_column('biz_product_store', 'merchant_id', "merchant_id bigint(20) default 0 comment '商户ID' after id");
call biz_add_index('biz_product_store', 'idx_merchant', 'key idx_merchant (merchant_id)');

call biz_add_column('biz_order', 'merchant_id', "merchant_id bigint(20) default 0 comment '商户ID' after order_id");
call biz_add_index('biz_order', 'idx_merchant', 'key idx_merchant (merchant_id)');

call biz_add_column('biz_booking', 'merchant_id', "merchant_id bigint(20) default 0 comment '商户ID' after booking_id");
call biz_add_index('biz_booking', 'idx_merchant', 'key idx_merchant (merchant_id)');

call biz_add_column('biz_booking_member', 'merchant_id', "merchant_id bigint(20) default 0 comment '商户ID' after id");
call biz_add_index('biz_booking_member', 'idx_merchant', 'key idx_merchant (merchant_id)');

call biz_add_column('biz_pay_bill', 'merchant_id', "merchant_id bigint(20) default 0 comment '商户ID' after bill_id");
call biz_add_index('biz_pay_bill', 'idx_merchant', 'key idx_merchant (merchant_id)');

call biz_add_column('biz_member_voucher', 'merchant_id', "merchant_id bigint(20) default 0 comment '商户ID' after id");
call biz_add_index('biz_member_voucher', 'idx_merchant', 'key idx_merchant (merchant_id)');

call biz_add_column('biz_settle_account', 'merchant_id', "merchant_id bigint(20) default 0 comment '商户ID' after account_id");
call biz_add_index('biz_settle_account', 'idx_merchant', 'key idx_merchant (merchant_id)');

call biz_add_column('biz_settle_record', 'merchant_id', "merchant_id bigint(20) default 0 comment '商户ID' after record_id");
call biz_add_index('biz_settle_record', 'idx_merchant', 'key idx_merchant (merchant_id)');

-- 推客体系：商户内独立
call biz_add_column('biz_distributor', 'merchant_id', "merchant_id bigint(20) default 0 comment '商户ID（推客按商户独立）' after distributor_id");
call biz_add_index('biz_distributor', 'idx_merchant', 'key idx_merchant (merchant_id)');

call biz_add_column('biz_commission', 'merchant_id', "merchant_id bigint(20) default 0 comment '商户ID' after commission_id");
call biz_add_index('biz_commission', 'idx_merchant', 'key idx_merchant (merchant_id)');

call biz_add_column('biz_withdraw', 'merchant_id', "merchant_id bigint(20) default 0 comment '商户ID' after withdraw_id");
call biz_add_index('biz_withdraw', 'idx_merchant', 'key idx_merchant (merchant_id)');

-- ----------------------------
-- 步骤3：允许平台级共享的表（merchant_id=0 表示全平台通用）
-- ----------------------------
call biz_add_column('biz_category', 'merchant_id', "merchant_id bigint(20) default 0 comment '商户ID（0=全平台通用）' after category_id");
call biz_add_index('biz_category', 'idx_merchant', 'key idx_merchant (merchant_id)');

call biz_add_column('biz_voucher', 'merchant_id', "merchant_id bigint(20) default 0 comment '商户ID（0=全平台通用）' after voucher_id");
call biz_add_index('biz_voucher', 'idx_merchant', 'key idx_merchant (merchant_id)');

call biz_add_column('biz_agreement', 'merchant_id', "merchant_id bigint(20) default 0 comment '商户ID（0=全平台通用）' after agreement_id");
call biz_add_index('biz_agreement', 'idx_merchant', 'key idx_merchant (merchant_id)');

call biz_add_column('biz_commission_rule', 'merchant_id', "merchant_id bigint(20) default 0 comment '商户ID（0=全平台默认规则）' after rule_id");
call biz_add_index('biz_commission_rule', 'idx_merchant', 'key idx_merchant (merchant_id)');

-- ----------------------------
-- 步骤4：初始化默认代理商与默认商户（承接全部存量数据）
-- ----------------------------
-- 4.1 组织部门：平台(100 若依科技) 下建「平台直营」代理商部门与默认商户部门
insert into sys_dept (dept_id, parent_id, ancestors, dept_name, order_num, leader, status, del_flag, create_by, create_time)
select 900, 100, '0,100', '平台直营', 90, 'admin', '0', '0', 'admin', sysdate()
where not exists (select 1 from sys_dept d where d.dept_id = 900);

insert into sys_dept (dept_id, parent_id, ancestors, dept_name, order_num, leader, status, del_flag, create_by, create_time)
select 901, 900, '0,100,900', '洞天团购（默认商户）', 1, 'admin', '0', '0', 'admin', sysdate()
where not exists (select 1 from sys_dept d where d.dept_id = 901);

-- 4.2 默认代理商（平台直营，额度不限）
insert into biz_agent (agent_id, agent_no, agent_name, dept_id, contact, phone, region, merchant_quota, used_quota, status, create_by, create_time)
select 1, 'AG000001', '平台直营', 900, '平台运营', '', '全国', 9999, 1, '0', 'admin', sysdate()
where not exists (select 1 from biz_agent a where a.agent_id = 1);

-- 4.2.5 把 sys_config 缺失的微信配置补齐（项目硬编码默认 appid，匹配 miniprogram7/project.config.json）
insert into sys_config (config_name, config_key, config_value, config_type, create_by, create_time, remark)
select '微信小程序AppId', 'wx.miniapp.appId', 'wx9e147c4e2151b123', 'N', 'admin', sysdate(), '升级脚本兜底：与 miniprogram7/project.config.json 保持一致'
where not exists (select 1 from sys_config c where c.config_key = 'wx.miniapp.appId');

insert into sys_config (config_name, config_key, config_value, config_type, create_by, create_time, remark)
select '微信小程序密钥', 'wx.miniapp.secret', '', 'N', 'admin', sysdate(), '升级脚本兜底'
where not exists (select 1 from sys_config c where c.config_key = 'wx.miniapp.secret');

-- 4.3 默认商户，appid/支付凭证从 sys_config 现有全局配置迁移过来
insert into biz_merchant (merchant_id, merchant_no, merchant_name, agent_id, dept_id, contact,
  appid, app_secret, mp_auth_mode, pay_mode, pay_mch_id, pay_appid, pay_cert_serial,
  pay_key_path, pay_api_v3_key, pay_notify_url, mock_enabled, status, create_by, create_time)
select 1, 'MC000001', '洞天团购（默认商户）', 1, 901, '平台运营',
  ifnull((select config_value from sys_config where config_key = 'wx.miniapp.appId'), ''),
  ifnull((select config_value from sys_config where config_key = 'wx.miniapp.secret'), ''),
  '0', '0',
  ifnull((select config_value from sys_config where config_key = 'wx.pay.mchId'), ''),
  ifnull((select config_value from sys_config where config_key = 'wx.pay.appId'), ''),
  ifnull((select config_value from sys_config where config_key = 'wx.pay.certSerialNo'), ''),
  ifnull((select config_value from sys_config where config_key = 'wx.pay.privateKeyPath'), ''),
  ifnull((select config_value from sys_config where config_key = 'wx.pay.apiV3Key'), ''),
  ifnull((select config_value from sys_config where config_key = 'wx.pay.notifyUrl'), ''),
  case when ifnull((select config_value from sys_config where config_key = 'wx.pay.mockEnabled'), 'false') = 'true'
       then '0' else '1' end,
  '0', 'admin', sysdate()
where not exists (select 1 from biz_merchant m where m.merchant_id = 1);

-- 4.3.1 兜底：即使 sys_config 被外部清空，也保证默认商户 appid 不为空
update biz_merchant
   set appid = 'wx9e147c4e2151b123'
 where merchant_id = 1
   and (appid is null or appid = '');

-- 4.4 admin 归属平台账号
insert into biz_merchant_user (user_id, user_type, agent_id, merchant_id, create_by, create_time)
select 1, '0', 0, 0, 'admin', sysdate()
where not exists (select 1 from biz_merchant_user u where u.user_id = 1);

-- ----------------------------
-- 步骤5：存量数据回填 merchant_id = 1
-- ----------------------------
update biz_store           set merchant_id = 1 where merchant_id = 0 or merchant_id is null;
update biz_store_album     set merchant_id = 1 where merchant_id = 0 or merchant_id is null;
update biz_member          set merchant_id = 1 where merchant_id = 0 or merchant_id is null;
update biz_product         set merchant_id = 1 where merchant_id = 0 or merchant_id is null;
update biz_product_store   set merchant_id = 1 where merchant_id = 0 or merchant_id is null;
update biz_order           set merchant_id = 1 where merchant_id = 0 or merchant_id is null;
update biz_booking         set merchant_id = 1 where merchant_id = 0 or merchant_id is null;
update biz_booking_member  set merchant_id = 1 where merchant_id = 0 or merchant_id is null;
update biz_pay_bill        set merchant_id = 1 where merchant_id = 0 or merchant_id is null;
update biz_member_voucher  set merchant_id = 1 where merchant_id = 0 or merchant_id is null;
update biz_settle_account  set merchant_id = 1 where merchant_id = 0 or merchant_id is null;
update biz_settle_record   set merchant_id = 1 where merchant_id = 0 or merchant_id is null;
update biz_distributor     set merchant_id = 1 where merchant_id = 0 or merchant_id is null;
update biz_commission      set merchant_id = 1 where merchant_id = 0 or merchant_id is null;
update biz_withdraw        set merchant_id = 1 where merchant_id = 0 or merchant_id is null;

-- 平台级共享表：store_id=0 的记录保持 merchant_id=0（全平台通用），其余按门店归属回填
update biz_category c
  left join biz_store s on s.store_id = c.store_id
set c.merchant_id = ifnull(s.merchant_id, 1)
where ifnull(c.store_id, 0) <> 0 and c.merchant_id = 0;

update biz_voucher v
  left join biz_store s on s.store_id = v.store_id
set v.merchant_id = ifnull(s.merchant_id, 1)
where ifnull(v.store_id, 0) <> 0 and v.merchant_id = 0;

update biz_agreement a
  left join biz_store s on s.store_id = a.store_id
set a.merchant_id = ifnull(s.merchant_id, 1)
where ifnull(a.store_id, 0) <> 0 and a.merchant_id = 0;

update biz_commission_rule r
  left join biz_store s on s.store_id = r.store_id
set r.merchant_id = ifnull(s.merchant_id, 1)
where ifnull(r.store_id, 0) <> 0 and r.merchant_id = 0;

-- ----------------------------
-- 步骤6：唯一键改造（回填完成后执行，避免误判冲突）
-- ----------------------------
-- 6.1 会员：openid 全局唯一 → 商户内唯一
call biz_drop_index('biz_member', 'uk_openid');
call biz_add_index('biz_member', 'uk_merchant_openid', 'unique key uk_merchant_openid (merchant_id, openid)');

-- 6.2 推客：会员全局唯一 → 商户内唯一
call biz_drop_index('biz_distributor', 'uk_member');
call biz_add_index('biz_distributor', 'uk_merchant_member', 'unique key uk_merchant_member (merchant_id, member_id)');

-- ----------------------------
-- 步骤7：账号-门店关联表补商户字段（后台店长账号仍按门店授权）
-- ----------------------------
call biz_add_column('biz_store_user', 'merchant_id', "merchant_id bigint(20) default 0 comment '商户ID' after id");
update biz_store_user su
  join biz_store s on s.store_id = su.store_id
set su.merchant_id = s.merchant_id
where su.merchant_id = 0;

-- 步骤 5.5：代理商门店配额（agent.store_quota）
-- 业务规则：代理商名下所有商户的门店总数 ≤ agent.store_quota。
-- store_quota=0 表示不限制（兼容平台直营/历史数据）。
CALL biz_add_column('biz_agent', 'store_quota',
  "store_quota int(11) default 0 comment '可开门店额度（0=不限）' after merchant_quota");
CALL biz_add_index('biz_agent', 'idx_store_quota', 'key idx_store_quota (store_quota)');

-- ----------------------------
-- 清理临时过程
-- ----------------------------


-- ############################################################
-- 源文件：sql/biz_product_model_v2.sql
-- ############################################################

-- =====================================================================
-- 商品模型 v2 迁移脚本
-- 基于 doc/PRD-抖音来客商品模型.md
-- 决策：品类全量 + 通用字段加列 + biz_category 合并到 biz_product_category
-- =====================================================================

-- 1) 重命名 biz_category → biz_product_category
drop table if exists biz_product_category;
create table biz_product_category (
  category_id     bigint(20)      not null auto_increment    comment '品类ID',
  merchant_id     bigint(20)      default 0                  comment '商户ID（0=平台通用）',
  parent_id       bigint(20)      default 0                  comment '父级ID（0=顶级）',
  category_name   varchar(50)     not null                   comment '品类名称',
  full_path       varchar(200)    default ''                 comment '完整路径（如：购物·服饰鞋帽·服装）',
  level           tinyint(1)      default 1                  comment '层级 1/2/3',
  industry_code   varchar(50)     default ''                 comment '行业编码（CATERING/EDUCATION/BEAUTY/HOTEL/SHOPPING...）',
  deposit_amount  bigint(20)      default 0                  comment '行业保证金（分）',
  allowed_types   varchar(100)    default ''                 comment '允许的商品类型（逗号分隔，如 GROUPON,VOUCHER）',
  license_required text                                      comment '必填资质（JSON：[{name,required}]）',
  compliance_notice text                                    comment '平台统一说明模板',
  icon            varchar(255)    default ''                 comment '品类图标',
  sort            int(4)          default 0                  comment '显示顺序',
  status          char(1)         default '0'                comment '状态（0正常 1停用）',
  del_flag        char(1)         default '0'                comment '删除标志（0存在 2删除）',
  create_by       varchar(64)     default ''                 comment '创建者',
  create_time     datetime                                   comment '创建时间',
  update_by       varchar(64)     default ''                 comment '更新者',
  update_time     datetime                                   comment '更新时间',
  primary key (category_id),
  key idx_parent (parent_id),
  key idx_industry (industry_code)
) engine=innodb auto_increment=100 comment = '商品品类表（合并原店内分类 + 抖音来客行业品类）';

-- 2) 商品类型字典表
drop table if exists biz_product_type;
create table biz_product_type (
  type_code       varchar(30)     not null                   comment '类型代码（GROUPON/VOUCHER/TIMECARD/...）',
  type_name       varchar(50)     not null                   comment '类型名称',
  type_desc       varchar(200)    default ''                 comment '业务说明',
  field_config    text                                      comment '字段配置 JSON（哪些字段必填/选填/隐藏）',
  icon            varchar(255)    default ''                 comment '类型图标',
  sort            int(4)          default 0                  comment '显示顺序',
  app_can_create  tinyint(1)      default 1                  comment 'App端是否可创建 0否 1是',
  need_license    tinyint(1)      default 0                  comment '是否需要放心付/冷静期 0否 1是',
  status          char(1)         default '0'                comment '状态（0启用 1停用）',
  create_time     datetime                                   comment '创建时间',
  update_time     datetime                                   comment '更新时间',
  primary key (type_code)
) engine=innodb comment = '商品类型字典表';

-- 3) 商品表加列（v2 通用字段）
-- 现有 biz_product 保留，加以下列：
alter table biz_product
  add column type_code         varchar(30)     default 'GROUPON'        comment '类型代码（关联 biz_product_type.type_code）' after product_type,
  add column industry_code     varchar(50)     default ''               comment '行业编码' after type_code,
  add column face_value        decimal(10,2)   default 0.00             comment '面值/划线价（代金券面值/次卡总价值）' after market_price,
  add column min_consume       decimal(10,2)   default 0.00             comment '最低消费门槛（代金券用，满 X 减 Y 的 X）' after face_value,
  add column total_times       int(11)         default 0                comment '总次数（次卡用）' after min_consume,
  add column period_type       varchar(20)     default ''               comment '周期类型 MONTH/QUARTER/YEAR（周期卡用）' after total_times,
  add column period_count      int(11)         default 0                comment '周期数（周期卡用）' after period_type,
  add column sale_start_date   datetime        default null             comment '商品售卖开始时间（限时售卖）' after period_count,
  add column sale_end_date     datetime        default null             comment '商品售卖结束时间（null=不限）' after sale_start_date,
  add column consume_start_days int(4)         default 1                comment '顾客可消费起始天数（自购买次日起）' after sale_end_date,
  add column consume_valid_days int(4)        default 360              comment '顾客可消费有效天数（默认 360）' after consume_start_days,
  add column consume_start_today tinyint(1)    default 1                comment '购买当天是否可用 0否 1是' after consume_valid_days,
  add column limit_per_user    int(11)         default 0                comment '每人限购件数（0=不限）' after consume_start_today,
  add column max_per_order     int(11)         default 1                comment '单次消费最多使用张数' after limit_per_user,
  add column max_persons       int(11)         default 0                comment '每张券最多使用人数（团购用，0=不限）' after max_per_order,
  add column refund_policy     varchar(500)    default ''               comment '售后政策' after max_persons,
  add column booking_required  tinyint(1)      default 0                comment '是否需要预约 0否 1是' after refund_policy,
  add column booking_workday_only tinyint(1)   default 0                comment '预约是否仅工作日 0否 1是' after booking_required,
  add column collect_method    varchar(20)     default 'PLATFORM'      comment '券码类型 PLATFORM/THIRD_PARTY/MERCHANT_OWN' after booking_workday_only,
  add column mutex_with_store_promotion tinyint(1) default 1             comment '是否与店内优惠互斥 0否 1是' after collect_method,
  add column extra_fee_desc    varchar(500)    default ''               comment '额外费用说明' after mutex_with_store_promotion,
  add column other_notice      varchar(2000)   default ''               comment '其他说明（500字内，禁止美团点评字样）' after extra_fee_desc,
  add column commission_rate   decimal(5,2)    default 0.00             comment '推客佣金比例（%）' after other_notice,
  add column total_value       decimal(10,2)   default 0.00             comment '组合券包总价值（划线价）' after commission_rate,
  add column subitem_pick_rule varchar(50)     default 'ALL'            comment '子品 N 选 M 规则：1选1/2选2/ALL（全部可享）' after total_value,
  add column require_xiaoxin   tinyint(1)      default 0                comment '是否需要开通冷静期（次卡/储值卡/周期卡/惠享卡=1）' after subitem_pick_rule;

-- 4) 商品-门店上架关系表加列
alter table biz_product_store
  add column subitem_pick_rule varchar(50)     default 'ALL'             comment '子品选择规则' after on_sale,
  add column require_xiaoxin   tinyint(1)      default 0                 comment '是否需要冷静期' after subitem_pick_rule;

-- 5) 子品商品组表（一对多：商品 → 多个商品组）
drop table if exists biz_product_subitem_group;
create table biz_product_subitem_group (
  group_id        bigint(20)      not null auto_increment    comment '商品组ID',
  product_id      bigint(20)      not null                   comment '商品ID',
  group_name      varchar(50)     default ''                 comment '商品组名称（如"体恤"）',
  pick_rule       varchar(50)     default 'ALL'              comment '选择规则 1选1/2选2/3选2/ALL（全部可享）',
  sort            int(4)          default 0                  comment '组内排序',
  create_time     datetime                                   comment '创建时间',
  primary key (group_id),
  key idx_product (product_id)
) engine=innodb comment = '商品搭配-商品组表';

-- 6) 子品（单品）表
drop table if exists biz_product_subitem;
create table biz_product_subitem (
  subitem_id      bigint(20)      not null auto_increment    comment '子品ID',
  group_id        bigint(20)      not null                   comment '商品组ID',
  product_id      bigint(20)      not null                   comment '商品ID（冗余便于查询）',
  subitem_name    varchar(100)    not null                   comment '子品名称（如"连衣裙裤子套装衬衣T恤"）',
  quantity        int(11)         default 1                  comment '数量（份）',
  price           decimal(10,2)   default 0.00               comment '单价',
  sort            int(4)          default 0                  comment '排序',
  create_time     datetime                                   comment '创建时间',
  primary key (subitem_id),
  key idx_group (group_id),
  key idx_product (product_id)
) engine=innodb comment = '商品搭配-子品表';

-- 7) 商品类型字典 seed
insert into biz_product_type (type_code, type_name, type_desc, sort, app_can_create, need_license) values
  ('GROUPON',       '团购套餐', '套餐商品，搭配自由，快速吸引顾客',          1, 1, 0),
  ('VOUCHER',       '代金券',   '现金抵扣券，出单快，便于引流增收',          2, 1, 0),
  ('TIMECARD',      '次卡',     '一次购买分次核销，增加用户粘性',            3, 1, 1),
  ('STORED_CARD',   '储值卡',   '通过存储金额，引导顾客多次到店消费',        4, 1, 1),
  ('PERIOD_CARD',   '周期卡',   '月/季/年卡等长周期商品，方便锁客',          5, 1, 1),
  ('HUIXIANG_CARD', '惠享卡',   '大额分次核销，提前锁客',                    6, 1, 1),
  ('PRESALE',       '预售券',   '先买后约，方便用户直播及短视频囤货',        7, 0, 0),
  ('PICKUP_VOUCHER','提货券',   '支持多规格管理和门店库存设置',              8, 0, 0),
  ('COMBO',         '组合券包', '团购、代金券、实物自由组合，一次购买分次核销', 9, 1, 0),
  ('BILL',          '到店买单', '顾客自助输入金额付款（当前 product_type=1）', 10, 1, 0),
  ('BOOKING',       '预约服务', '预约类商品（当前 product_type=2）',         11, 1, 0);

-- 8) 数据迁移：将 biz_category 现有数据迁到 biz_product_category（作为店内分类挂在某品类下）
-- 默认挂在 "购物·美食·堂食套餐"（category_id=10000）下，level=1
insert into biz_product_category
  (category_id, merchant_id, parent_id, category_name, full_path, level, industry_code, allowed_types, sort, status, create_by, create_time)
values
  (10000, 0, 0, '美食',      '美食',                   1, 'CATERING',  'GROUPON,VOUCHER,BILL,BOOKING', 1, '0', 'system', now());

-- 现有店内分类（category_id 100-200）作为美食的子分类
insert into biz_product_category
  (category_id, merchant_id, parent_id, category_name, full_path, level, industry_code, allowed_types, sort, status, create_by, create_time)
select
  category_id + 10000,  -- 避开原 ID 段
  0,
  10000,
  category_name,
  concat('美食·', category_name),
  2,
  'CATERING',
  'GROUPON,VOUCHER,BILL,BOOKING',
  sort,
  status,
  create_by,
  create_time
from biz_category;
-- 注：biz_category 无 del_flag 列（见 sql/biz_tables.sql），迁移全部数据

-- 9) 同步商品表的 industry_code（基于其原 category_id 反查）
update biz_product p
  join biz_product_category c on c.category_id = p.category_id + 10000
set p.industry_code = c.industry_code
where p.industry_code = '' or p.industry_code is null;

-- 10) 同步 product_type → type_code
-- 当前映射：0(到店自取)→GROUPON  1(到店买单)→BILL  2(预约服务)→BOOKING
update biz_product set type_code = 'GROUPON' where product_type = '0' and (type_code is null or type_code = '' or type_code = 'GROUPON');
update biz_product set type_code = 'BILL'     where product_type = '1' and (type_code is null or type_code = '' or type_code = 'GROUPON');
update biz_product set type_code = 'BOOKING'  where product_type = '2' and (type_code is null or type_code = '' or type_code = 'GROUPON');

-- 11) 行业品类 seed（全量覆盖抖音来客 8 大类）
-- 一级品类
insert into biz_product_category (category_id, merchant_id, parent_id, category_name, full_path, level, industry_code, deposit_amount, allowed_types, sort, status, create_by, create_time) values
  (1,  0, 0, '购物',         '购物',           1, 'SHOPPING',     500000,  'GROUPON,VOUCHER,HUIXIANG_CARD,COMBO,PRESALE,PICKUP_VOUCHER',  1, '0', 'system', now()),
  (2,  0, 0, '美食',         '美食',           1, 'CATERING',     100000,  'GROUPON,VOUCHER,BILL,BOOKING',                                2, '0', 'system', now()),
  (3,  0, 0, '丽人',         '丽人',           1, 'BEAUTY',       200000,  'GROUPON,VOUCHER,TIMECARD,STORED_CARD,PERIOD_CARD,HUIXIANG_CARD,COMBO,BOOKING', 3, '0', 'system', now()),
  (4,  0, 0, '住宿',         '住宿',           1, 'HOTEL',        300000,  'GROUPON,VOUCHER,PERIOD_CARD,HUIXIANG_CARD,COMBO',              4, '0', 'system', now()),
  (5,  0, 0, '教培',         '教培',           1, 'EDUCATION',    300000,  'GROUPON,VOUCHER,TIMECARD,PERIOD_CARD,HUIXIANG_CARD,COMBO',     5, '0', 'system', now()),
  (6,  0, 0, '休闲娱乐',     '休闲娱乐',       1, 'LEISURE',      150000,  'GROUPON,VOUCHER,TIMECARD,PERIOD_CARD,COMBO',                  6, '0', 'system', now()),
  (7,  0, 0, '生活服务',     '生活服务',       1, 'LIFE_SERVICE', 100000,  'GROUPON,VOUCHER,PERIOD_CARD,COMBO,BOOKING',                   7, '0', 'system', now()),
  (8,  0, 0, '汽车',         '汽车',           1, 'AUTO',         300000,  'GROUPON,VOUCHER,STORED_CARD,PERIOD_CARD,HUIXIANG_CARD,COMBO',  8, '0', 'system', now()),
  (9,  0, 0, '医疗健康',     '医疗健康',       1, 'MEDICAL',      500000,  'GROUPON,VOUCHER,TIMECARD,PERIOD_CARD,HUIXIANG_CARD,COMBO,BOOKING', 9, '0', 'system', now()),
  (10, 0, 0, '宠物',         '宠物',           1, 'PET',           50000,  'GROUPON,VOUCHER,STORED_CARD,COMBO',                          10, '0', 'system', now()),
  (11, 0, 0, '亲子',         '亲子',           1, 'PARENT_CHILD', 200000,  'GROUPON,VOUCHER,TIMECARD,PERIOD_CARD,COMBO',                 11, '0', 'system', now());

-- 二级品类（每个一级下挂常见二级）
insert into biz_product_category (merchant_id, parent_id, category_name, full_path, level, industry_code, deposit_amount, allowed_types, sort, status, create_by, create_time) values
  -- 购物（id=1）下
  (0, 1, '服饰鞋帽',  '购物·服饰鞋帽',  2, 'SHOPPING', 500000, 'GROUPON,VOUCHER,HUIXIANG_CARD,COMBO',                       1, '0', 'system', now()),
  (0, 1, '母婴用品',  '购物·母婴用品',  2, 'SHOPPING', 200000, 'GROUPON,VOUCHER,COMBO,HUIXIANG_CARD',                       2, '0', 'system', now()),
  (0, 1, '美妆个护',  '购物·美妆个护',  2, 'SHOPPING', 300000, 'GROUPON,VOUCHER,HUIXIANG_CARD,COMBO',                       3, '0', 'system', now()),
  (0, 1, '数码家电',  '购物·数码家电',  2, 'SHOPPING', 500000, 'GROUPON,VOUCHER,COMBO',                                     4, '0', 'system', now()),
  (0, 1, '日用百货',  '购物·日用百货',  2, 'SHOPPING', 100000, 'GROUPON,VOUCHER',                                           5, '0', 'system', now()),
  -- 美食（id=2）下
  (0, 2, '火锅',      '美食·火锅',      2, 'CATERING', 100000, 'GROUPON,VOUCHER,BILL,BOOKING',                              1, '0', 'system', now()),
  (0, 2, '中餐',      '美食·中餐',      2, 'CATERING', 100000, 'GROUPON,VOUCHER,BILL,BOOKING',                              2, '0', 'system', now()),
  (0, 2, '西餐',      '美食·西餐',      2, 'CATERING', 100000, 'GROUPON,VOUCHER,BILL,BOOKING',                              3, '0', 'system', now()),
  (0, 2, '小吃快餐',  '美食·小吃快餐',  2, 'CATERING',  50000, 'GROUPON,VOUCHER,BILL',                                      4, '0', 'system', now()),
  (0, 2, '甜品饮品',  '美食·甜品饮品',  2, 'CATERING',  50000, 'GROUPON,VOUCHER,BILL',                                      5, '0', 'system', now()),
  -- 丽人（id=3）下
  (0, 3, '美发',      '丽人·美发',      2, 'BEAUTY',   200000, 'GROUPON,VOUCHER,TIMECARD,STORED_CARD,PERIOD_CARD',          1, '0', 'system', now()),
  (0, 3, '美甲',      '丽人·美甲',      2, 'BEAUTY',   100000, 'GROUPON,VOUCHER,TIMECARD,STORED_CARD',                      2, '0', 'system', now()),
  (0, 3, '美容',      '丽人·美容',      2, 'BEAUTY',   200000, 'GROUPON,VOUCHER,TIMECARD,PERIOD_CARD,HUIXIANG_CARD',        3, '0', 'system', now()),
  (0, 3, '美睫',      '丽人·美睫',      2, 'BEAUTY',   100000, 'GROUPON,VOUCHER,TIMECARD',                                  4, '0', 'system', now()),
  (0, 3, '美体',      '丽人·美体',      2, 'BEAUTY',   200000, 'GROUPON,VOUCHER,PERIOD_CARD',                               5, '0', 'system', now()),
  -- 住宿（id=4）下
  (0, 4, '酒店',      '住宿·酒店',      2, 'HOTEL',    300000, 'GROUPON,VOUCHER,PERIOD_CARD,HUIXIANG_CARD',                 1, '0', 'system', now()),
  (0, 4, '民宿',      '住宿·民宿',      2, 'HOTEL',    200000, 'GROUPON,VOUCHER,PERIOD_CARD',                               2, '0', 'system', now()),
  (0, 4, '公寓',      '住宿·公寓',      2, 'HOTEL',    200000, 'GROUPON,VOUCHER,PERIOD_CARD',                               3, '0', 'system', now()),
  -- 教培（id=5）下
  (0, 5, '学科教育',  '教培·学科教育',  2, 'EDUCATION', 300000, 'GROUPON,VOUCHER,TIMECARD,PERIOD_CARD',                     1, '0', 'system', now()),
  (0, 5, '兴趣教育',  '教培·兴趣教育',  2, 'EDUCATION', 200000, 'GROUPON,VOUCHER,TIMECARD,PERIOD_CARD,COMBO',               2, '0', 'system', now()),
  (0, 5, '职业培训',  '教培·职业培训',  2, 'EDUCATION', 300000, 'GROUPON,VOUCHER,TIMECARD,PERIOD_CARD',                     3, '0', 'system', now()),
  -- 休闲娱乐（id=6）下
  (0, 6, 'KTV',       '休闲娱乐·KTV',   2, 'LEISURE',  150000, 'GROUPON,VOUCHER,TIMECARD,COMBO',                          1, '0', 'system', now()),
  (0, 6, '密室',      '休闲娱乐·密室',  2, 'LEISURE',  150000, 'GROUPON,VOUCHER,TIMECARD,COMBO',                          2, '0', 'system', now()),
  (0, 6, '桌游',      '休闲娱乐·桌游',  2, 'LEISURE',   50000, 'GROUPON,VOUCHER,TIMECARD',                                3, '0', 'system', now()),
  (0, 6, '网吧',      '休闲娱乐·网吧',  2, 'LEISURE',  100000, 'GROUPON,VOUCHER,STORED_CARD,PERIOD_CARD',                 4, '0', 'system', now()),
  (0, 6, '运动健身',  '休闲娱乐·运动健身', 2, 'LEISURE', 100000, 'GROUPON,VOUCHER,PERIOD_CARD,TIMECARD,COMBO',              5, '0', 'system', now()),
  -- 生活服务（id=7）下
  (0, 7, '家政',      '生活服务·家政',  2, 'LIFE_SERVICE', 100000, 'GROUPON,VOUCHER,PERIOD_CARD',                            1, '0', 'system', now()),
  (0, 7, '洗护',      '生活服务·洗护',  2, 'LIFE_SERVICE', 100000, 'GROUPON,VOUCHER,STORED_CARD,PERIOD_CARD',               2, '0', 'system', now()),
  (0, 7, '维修',      '生活服务·维修',  2, 'LIFE_SERVICE', 100000, 'GROUPON,VOUCHER,BOOKING',                                3, '0', 'system', now()),
  -- 汽车（id=8）下
  (0, 8, '保养',      '汽车·保养',      2, 'AUTO',     200000, 'GROUPON,VOUCHER,PERIOD_CARD,HUIXIANG_CARD,COMBO',          1, '0', 'system', now()),
  (0, 8, '洗车',      '汽车·洗车',      2, 'AUTO',     100000, 'GROUPON,VOUCHER,PERIOD_CARD',                              2, '0', 'system', now()),
  (0, 8, '维修',      '汽车·维修',      2, 'AUTO',     300000, 'GROUPON,VOUCHER,BOOKING',                                  3, '0', 'system', now()),
  -- 医疗健康（id=9）下
  (0, 9, '口腔',      '医疗健康·口腔',  2, 'MEDICAL',  500000, 'GROUPON,VOUCHER,TIMECARD,COMBO,BOOKING',                   1, '0', 'system', now()),
  (0, 9, '中医',      '医疗健康·中医',  2, 'MEDICAL',  500000, 'GROUPON,VOUCHER,PERIOD_CARD,COMBO,BOOKING',                2, '0', 'system', now()),
  (0, 9, '医美',      '医疗健康·医美',  2, 'MEDICAL',  500000, 'GROUPON,VOUCHER,TIMECARD,PERIOD_CARD,HUIXIANG_CARD,COMBO,BOOKING', 3, '0', 'system', now()),
  -- 宠物（id=10）下
  (0,10, '宠物美容',  '宠物·宠物美容',  2, 'PET',       50000, 'GROUPON,VOUCHER,STORED_CARD,COMBO',                        1, '0', 'system', now()),
  (0,10, '宠物医疗',  '宠物·宠物医疗',  2, 'PET',       50000, 'GROUPON,VOUCHER,BOOKING',                                  2, '0', 'system', now()),
  (0,10, '宠物寄养',  '宠物·宠物寄养',  2, 'PET',       50000, 'GROUPON,VOUCHER,PERIOD_CARD,COMBO',                        3, '0', 'system', now()),
  -- 亲子（id=11）下
  (0,11, '儿童摄影',  '亲子·儿童摄影',  2, 'PARENT_CHILD', 200000, 'GROUPON,VOUCHER,COMBO',                                  1, '0', 'system', now()),
  (0,11, '儿童乐园',  '亲子·儿童乐园',  2, 'PARENT_CHILD', 200000, 'GROUPON,VOUCHER,COMBO',                                  2, '0', 'system', now()),
  (0,11, '亲子游泳',  '亲子·亲子游泳',  2, 'PARENT_CHILD', 200000, 'GROUPON,VOUCHER,PERIOD_CARD,COMBO',                      3, '0', 'system', now());


-- ############################################################
-- 源文件：sql/biz_product_model_v2_safe.sql
-- ############################################################

-- ============================================
-- biz_product_model_v2.sql 安全版（无 PREPARE）
-- 26 段 v2 字段 IF 检测 + 只在缺失时 ADD
-- 适用任何 MySQL 客户端 / 重复跑安全
-- ============================================

-- 0) 创建通用"加列助手"存储过程（永久，反复可用）


-- 1) sys_user 加 v2 字段（缺失才加）
CALL add_column_if_missing('sys_user', 'user_type', "varchar(20) DEFAULT '00' COMMENT '00系统 10代理 20商户 30会员 40员工' AFTER avatar");
CALL add_column_if_missing('sys_user', 'merchant_id', "bigint(20) DEFAULT 0 COMMENT '所属商户ID' AFTER user_type");

-- 2) biz_product 加 26 个 v2 字段
CALL add_column_if_missing('biz_product', 'type_code', "varchar(30) DEFAULT 'GROUPON' COMMENT '类型代码' AFTER product_type");
CALL add_column_if_missing('biz_product', 'industry_code', "varchar(50) DEFAULT '' COMMENT '行业编码' AFTER type_code");
CALL add_column_if_missing('biz_product', 'face_value', "decimal(10,2) DEFAULT 0.00 COMMENT '面值/划线价' AFTER market_price");
CALL add_column_if_missing('biz_product', 'min_consume', "decimal(10,2) DEFAULT 0.00 COMMENT '最低消费门槛' AFTER face_value");
CALL add_column_if_missing('biz_product', 'total_times', "int(11) DEFAULT 0 COMMENT '总次数（次卡）' AFTER min_consume");
CALL add_column_if_missing('biz_product', 'period_type', "varchar(20) DEFAULT '' COMMENT '周期类型' AFTER total_times");
CALL add_column_if_missing('biz_product', 'period_count', "int(11) DEFAULT 0 COMMENT '周期数' AFTER period_type");
CALL add_column_if_missing('biz_product', 'sale_start_date', "datetime DEFAULT NULL COMMENT '售卖开始' AFTER period_count");
CALL add_column_if_missing('biz_product', 'sale_end_date', "datetime DEFAULT NULL COMMENT '售卖结束' AFTER sale_start_date");
CALL add_column_if_missing('biz_product', 'consume_start_days', "int(4) DEFAULT 1 COMMENT '可消费起始天数' AFTER sale_end_date");
CALL add_column_if_missing('biz_product', 'consume_valid_days', "int(4) DEFAULT 360 COMMENT '可消费有效天数' AFTER consume_start_days");
CALL add_column_if_missing('biz_product', 'consume_start_today', "tinyint(1) DEFAULT 1 COMMENT '购买当天是否可用' AFTER consume_valid_days");
CALL add_column_if_missing('biz_product', 'limit_per_user', "int(11) DEFAULT 0 COMMENT '每人限购' AFTER consume_start_today");
CALL add_column_if_missing('biz_product', 'max_per_order', "int(11) DEFAULT 1 COMMENT '单次最多使用张数' AFTER limit_per_user");
CALL add_column_if_missing('biz_product', 'max_persons', "int(11) DEFAULT 0 COMMENT '每张最多使用人数' AFTER max_per_order");
CALL add_column_if_missing('biz_product', 'refund_policy', "varchar(500) DEFAULT '' COMMENT '售后政策' AFTER max_persons");
CALL add_column_if_missing('biz_product', 'booking_required', "tinyint(1) DEFAULT 0 COMMENT '需要预约' AFTER refund_policy");
CALL add_column_if_missing('biz_product', 'booking_workday_only', "tinyint(1) DEFAULT 0 COMMENT '预约仅工作日' AFTER booking_required");
CALL add_column_if_missing('biz_product', 'collect_method', "varchar(20) DEFAULT 'PLATFORM' COMMENT '券码类型' AFTER booking_workday_only");
CALL add_column_if_missing('biz_product', 'mutex_with_store_promotion', "tinyint(1) DEFAULT 1 COMMENT '与店内优惠互斥' AFTER collect_method");
CALL add_column_if_missing('biz_product', 'extra_fee_desc', "varchar(500) DEFAULT '' COMMENT '额外费用说明' AFTER mutex_with_store_promotion");
CALL add_column_if_missing('biz_product', 'other_notice', "varchar(2000) DEFAULT '' COMMENT '其他说明' AFTER extra_fee_desc");
CALL add_column_if_missing('biz_product', 'commission_rate', "decimal(5,2) DEFAULT 0.00 COMMENT '推客佣金比例' AFTER other_notice");
CALL add_column_if_missing('biz_product', 'total_value', "decimal(10,2) DEFAULT 0.00 COMMENT '组合券包总价值' AFTER commission_rate");
CALL add_column_if_missing('biz_product', 'subitem_pick_rule', "varchar(50) DEFAULT 'ALL' COMMENT '子品选择规则' AFTER total_value");
CALL add_column_if_missing('biz_product', 'require_xiaoxin', "tinyint(1) DEFAULT 0 COMMENT '需要冷静期' AFTER subitem_pick_rule");

-- 3) biz_product_store 加 2 字段
CALL add_column_if_missing('biz_product_store', 'subitem_pick_rule', "varchar(50) DEFAULT 'ALL' COMMENT '子品选择规则' AFTER on_sale");
CALL add_column_if_missing('biz_product_store', 'require_xiaoxin', "tinyint(1) DEFAULT 0 COMMENT '需要冷静期' AFTER subitem_pick_rule");

-- 4) 验证：列出现有 v2 字段
SELECT TABLE_NAME, COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND (
    (TABLE_NAME = 'biz_product' AND COLUMN_NAME IN (
      'type_code','industry_code','face_value','min_consume','total_times',
      'period_type','period_count','sale_start_date','sale_end_date',
      'consume_start_days','consume_valid_days','consume_start_today',
      'limit_per_user','max_per_order','max_persons','refund_policy',
      'booking_required','booking_workday_only','collect_method',
      'mutex_with_store_promotion','extra_fee_desc','other_notice',
      'commission_rate','total_value','subitem_pick_rule','require_xiaoxin'
    ))
    OR (TABLE_NAME = 'biz_product_store' AND COLUMN_NAME IN ('subitem_pick_rule','require_xiaoxin'))
    OR (TABLE_NAME = 'sys_user' AND COLUMN_NAME IN ('user_type','merchant_id','openid','openid_bound'))
  )
ORDER BY TABLE_NAME, COLUMN_NAME;


-- ############################################################
-- 源文件：sql/biz_merchant_v2.sql
-- ############################################################

-- =====================================================================
-- 商家端 v2 迁移脚本
-- 1) sys_user 加 openid 列（员工/会员登录复用）
-- 2) biz_merchant_staff 表（替代 biz_store_user，保留旧表 + 视图）
-- 3) biz_merchant_staff_invite 邀请码表
-- =====================================================================

-- 1) sys_user 加 openid（idempotent：已存在则跳过）
-- 改用 DEFAULT NULL 而非 ''：MySQL UNIQUE KEY 允许多个 NULL，但不允许多个空字符串
-- 业务代码 selectUserByOpenId 已兼容 NULL（if (openid == null || openid.isEmpty()) return null;）

-- 1.1 加 openid 列（若已存在则跳过）
SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_SCHEMA = DATABASE()
                      AND TABLE_NAME = 'sys_user'
                      AND COLUMN_NAME = 'openid');
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE sys_user ADD COLUMN openid varchar(64) DEFAULT NULL COMMENT ''微信 openid（绑定后唯一）'' AFTER avatar',
  'SELECT ''openid 列已存在，跳过'' AS msg');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 1.2 加 openid_bound 列（若已存在则跳过）
SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_SCHEMA = DATABASE()
                      AND TABLE_NAME = 'sys_user'
                      AND COLUMN_NAME = 'openid_bound');
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE sys_user ADD COLUMN openid_bound tinyint(1) DEFAULT 0 COMMENT ''openid 绑定状态 0未绑 1已绑'' AFTER openid',
  'SELECT ''openid_bound 列已存在，跳过'' AS msg');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 1.3 修已有 openid 列的默认值为 NULL（若已是 NULL 跳过）
SET @col_default := (SELECT COLUMN_DEFAULT FROM INFORMATION_SCHEMA.COLUMNS
                     WHERE TABLE_SCHEMA = DATABASE()
                       AND TABLE_NAME = 'sys_user'
                       AND COLUMN_NAME = 'openid');
SET @sql := IF(@col_default IS NULL OR @col_default != 'NULL',
  'ALTER TABLE sys_user MODIFY COLUMN openid varchar(64) DEFAULT NULL COMMENT ''微信 openid（绑定后唯一）''',
  'SELECT ''openid 默认值已是 NULL，跳过'' AS msg');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 1.4 加 UNIQUE KEY uk_sys_user_openid（若已存在则跳过）
SET @idx_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
                    WHERE TABLE_SCHEMA = DATABASE()
                      AND TABLE_NAME = 'sys_user'
                      AND INDEX_NAME = 'uk_sys_user_openid');
SET @sql := IF(@idx_exists = 0,
  'ALTER TABLE sys_user ADD UNIQUE KEY uk_sys_user_openid (openid)',
  'SELECT ''uk_sys_user_openid 索引已存在，跳过'' AS msg');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 2) 新建 biz_merchant_staff 表（商家员工关联）
-- 2) 新建 biz_merchant_staff 表（商家员工关联）
DROP TABLE IF EXISTS biz_merchant_staff;
CREATE TABLE biz_merchant_staff (
  id            bigint(20)    NOT NULL AUTO_INCREMENT          COMMENT '主键',
  merchant_id   bigint(20)    NOT NULL                          COMMENT '商户ID',
  store_id      bigint(20)    NOT NULL                          COMMENT '门店ID',
  user_id       bigint(20)    NOT NULL                          COMMENT '员工 sys_user_id',
  role          varchar(20)   DEFAULT 'STAFF'                   COMMENT '角色 STAFF/MANAGER/OWNER',
  staff_no      varchar(32)   DEFAULT ''                        COMMENT '员工编号（人工补录）',
  real_name     varchar(32)   DEFAULT ''                        COMMENT '员工姓名（人工补录）',
  phone         varchar(20)   DEFAULT ''                        COMMENT '员工手机号（人工补录）',
  hired_at      datetime      DEFAULT NULL                      COMMENT '入职时间',
  status        char(1)       DEFAULT '0'                       COMMENT '0在职 1离职',
  create_by     varchar(64)   DEFAULT '',
  create_time   datetime,
  update_by     varchar(64)   DEFAULT '',
  update_time   datetime,
  PRIMARY KEY (id),
  UNIQUE KEY uk_merchant_staff (merchant_id, store_id, user_id),
  KEY idx_merchant_staff_user (user_id),
  KEY idx_merchant_staff_store (store_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT = '商家员工表';

-- 3) 视图：旧 biz_store_user 仍能查询（兼容期）
DROP VIEW IF EXISTS biz_store_user_v;
CREATE VIEW biz_store_user_v AS
  SELECT id, merchant_id, store_id, user_id, status, create_time
  FROM biz_merchant_staff;

-- 4) 数据迁移：把现有 biz_store_user 数据同步到 biz_merchant_staff
INSERT INTO biz_merchant_staff (merchant_id, store_id, user_id, role, status, create_time)
SELECT IFNULL(merchant_id, 0), store_id, user_id, 'STAFF', '0', create_time
FROM biz_store_user
ON DUPLICATE KEY UPDATE update_time = NOW();

-- 5) biz_merchant_staff_invite 邀请码表
DROP TABLE IF EXISTS biz_merchant_staff_invite;
CREATE TABLE biz_merchant_staff_invite (
  invite_id     bigint(20)    NOT NULL AUTO_INCREMENT          COMMENT '主键',
  invite_code   varchar(8)    NOT NULL                          COMMENT '邀请短码（6-8位）',
  scene         varchar(128)  NOT NULL                          COMMENT '微信小程序码 scene（invite:MID:SID:CODE）',
  wxacode_url   varchar(500)  DEFAULT ''                        COMMENT '已生成的微信小程序码 base64',
  merchant_id   bigint(20)    NOT NULL,
  store_id      bigint(20)    NOT NULL,
  role          varchar(20)   DEFAULT 'STAFF'                   COMMENT 'STAFF/MANAGER',
  expire_at     datetime      NOT NULL,
  used_at       datetime      DEFAULT NULL,
  used_by       bigint(20)    DEFAULT NULL                      COMMENT '使用的 sys_user_id',
  status        char(1)       DEFAULT '0'                       COMMENT '0有效 1已用 2过期 3作废',
  remark        varchar(255)  DEFAULT '',
  create_by     varchar(64)   DEFAULT '',
  create_time   datetime,
  PRIMARY KEY (invite_id),
  UNIQUE KEY uk_invite_code (invite_code),
  KEY idx_invite_merchant (merchant_id, store_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT = '商家员工邀请码表';

-- 6) 索引：提升查询效率
SET @idx := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_merchant_staff' AND INDEX_NAME = 'idx_staff_merchant');
SET @sql := IF(@idx = 0, 'ALTER TABLE biz_merchant_staff ADD INDEX idx_staff_merchant (merchant_id)', 'SELECT "idx_staff_merchant exists" AS msg');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
SET @idx := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_merchant_staff_invite' AND INDEX_NAME = 'idx_invite_status');
SET @sql := IF(@idx = 0, 'ALTER TABLE biz_merchant_staff_invite ADD INDEX idx_invite_status (status, expire_at)', 'SELECT "idx_invite_status exists" AS msg');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ============================================================
-- 商家员工/邀请码 admin 菜单（idempotent）
-- 路径：团购运营 / 门店商品 / 员工管理
-- 组件：biz/staffInvite/index
-- ============================================================

-- 1) 员工管理菜单（若已存在则忽略）
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '员工管理',
       -- 注（2026-08-22）：原来要求「门店商品」必须挂在「团购运营」下，但 biz_menu_flatten.sql
       -- 会把分组平铺成顶级 → 子查询取不到 → parent_id 落 NULL → getRouters 500。
       -- 改为按名字直接找，取不到落 0（顶级）。
       IFNULL((SELECT menu_id FROM (SELECT menu_id FROM sys_menu WHERE menu_name = '门店商品' AND menu_type='M' ORDER BY menu_id LIMIT 1) x), 0),
       6, 'staffInvite', 'biz/staffInvite/index', 1, 0, 'C', '0', '0', 'biz:staffInvite:list', 'peoples', 'admin', SYSDATE(), '商家员工邀请码 + 员工名单管理'
FROM (SELECT 1) t
WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE component = 'biz/staffInvite/index' LIMIT 1);

-- 2) 按钮权限（list / add / edit / remove / query / export）
--    按 ruoyi 习惯直接用 menu_id 拼 perms，这里用存储过程式逐行插入
SET @m_staff = (SELECT menu_id FROM sys_menu WHERE component = 'biz/staffInvite/index' LIMIT 1);

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '员工查询', @m_staff, 1, '', '', 1, 0, 'F', '0', '0', 'biz:staffInvite:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m_staff IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:staffInvite:query' LIMIT 1);

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '生成邀请码', @m_staff, 2, '', '', 1, 0, 'F', '0', '0', 'biz:staffInvite:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m_staff IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:staffInvite:add' LIMIT 1);

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '修改员工', @m_staff, 3, '', '', 1, 0, 'F', '0', '0', 'biz:staffInvite:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m_staff IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:staffInvite:edit' LIMIT 1);

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '删除员工', @m_staff, 4, '', '', 1, 0, 'F', '0', '0', 'biz:staffInvite:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m_staff IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:staffInvite:remove' LIMIT 1);

-- 3) 把菜单 + 按钮权限授予 admin 角色（其它角色按需自行分配）
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu
WHERE component = 'biz/staffInvite/index' OR perms IN ('biz:staffInvite:query','biz:staffInvite:add','biz:staffInvite:edit','biz:staffInvite:remove');


-- ############################################################
-- 源文件：sql/biz_product_columns_v3.sql
-- ############################################################

-- 续篇 9 · 方案 A：主表加列覆盖 3 类型差异字段 + 6 tab 详细字段
-- 放弃方案 B(3 张 _ext 子表 join)，所有扩展字段都加到 biz_product

-- ========== 3 类型独有字段（基础信息/商品信息/商品资质 tab）==========
ALTER TABLE biz_product
  ADD COLUMN voucher_auto_name     TINYINT(1)     DEFAULT 1     COMMENT '代金券自动按面值生成名称(0/1)' AFTER face_value,
  ADD COLUMN voucher_min_consume   DECIMAL(10,2)  DEFAULT 0     COMMENT '代金券最低消费门槛(满X减Y的X)' AFTER voucher_auto_name,
  -- 组合券包独有
  ADD COLUMN combo_total_value     DECIMAL(10,2)  DEFAULT 0     COMMENT '组合券包总价值(划线价, 商品信息tab自动算售价)' AFTER total_value,
  ADD COLUMN combo_sale_type       VARCHAR(20)    DEFAULT 'LIMIT' COMMENT '组合券包售卖类型(LIMIT=限时/LONG=不限时)',
  ADD COLUMN combo_auto_extend_days INT            DEFAULT 30    COMMENT '组合券包到期自动延期天数',
  ADD COLUMN outer_subitem_id      VARCHAR(100)   DEFAULT NULL  COMMENT '组合券包商家平台子品ID(售卖信息tab)',
  ADD COLUMN combo_items_json      TEXT           DEFAULT NULL  COMMENT '组合券包搭配明细 JSON(团购套餐/代金券/满减券/折扣券)',
  -- 代金券适用范围(消费规则)
  ADD COLUMN voucher_scope_type    VARCHAR(20)    DEFAULT 'ALL'  COMMENT '代金券适用范围(ALL=全场/CATEGORY=按品类/STORE=按门店)',
  ADD COLUMN voucher_scope_ids     VARCHAR(500)   DEFAULT NULL  COMMENT '代金券适用范围 ID 列表',
  -- 团购搭配规则
  ADD COLUMN groupon_pick_rule     VARCHAR(50)    DEFAULT 'ALL'  COMMENT '团购搭配规则(ALL=全部可享/PICK_1=1选1/PICK_2=2选2/PICK_3=3选2)',
  ADD COLUMN groupon_actual_count  INT            DEFAULT 0     COMMENT '团购实际可享数(缓存, 来自子品搭配统计)';

-- ========== 6 tab 详细字段（售卖信息/交易规则/消费规则）==========
-- 售卖信息：投放渠道/职人带货/商品售卖日期/券码类型 已有
-- 交易规则：消费时段/预约规则 已有；新增：每天使用限制
ALTER TABLE biz_product
  ADD COLUMN daily_use_limit       INT            DEFAULT 0     COMMENT '每天使用限制(0=不限制, 组合券包独有)' AFTER limit_per_user,
  ADD COLUMN refund_rule_type      VARCHAR(50)    DEFAULT 'ANYTIME' COMMENT '退款规则(ANYTIME=随时退/BEFORE_EXPIRE=过期前/NONE=不可退, 组合券包独有)';

-- 兜底
UPDATE biz_product SET voucher_auto_name = 1 WHERE voucher_auto_name IS NULL;
UPDATE biz_product SET voucher_min_consume = 0 WHERE voucher_min_consume IS NULL;
UPDATE biz_product SET combo_total_value = 0 WHERE combo_total_value IS NULL;
UPDATE biz_product SET combo_sale_type = 'LIMIT' WHERE combo_sale_type IS NULL;
UPDATE biz_product SET combo_auto_extend_days = 30 WHERE combo_auto_extend_days IS NULL;
UPDATE biz_product SET voucher_scope_type = 'ALL' WHERE voucher_scope_type IS NULL;
UPDATE biz_product SET groupon_pick_rule = 'ALL' WHERE groupon_pick_rule IS NULL;
UPDATE biz_product SET groupon_actual_count = 0 WHERE groupon_actual_count IS NULL;
UPDATE biz_product SET daily_use_limit = 0 WHERE daily_use_limit IS NULL;
UPDATE biz_product SET refund_rule_type = 'ANYTIME' WHERE refund_rule_type IS NULL;


-- ############################################################
-- 源文件：sql/biz_product_ext.sql
-- ############################################################

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


-- ############################################################
-- 源文件：sql/biz_product_stores.sql
-- ############################################################

-- ----------------------------
-- 商品「适用门店」：store_ids 存字典键值，多选逗号分隔（如 100,101）
-- 说明：保留 store_id 作为主门店（用于下单归属/兼容），store_ids 为适用门店集合
-- 导入：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_product_stores.sql
-- ----------------------------
-- 幂等加列：sql/biz_tables.sql 新版建表已含 store_ids，存量库才需要 ALTER
set @sql := (
  select if(
    exists(select 1 from information_schema.columns
           where table_schema = database() and table_name = 'biz_product' and column_name = 'store_ids'),
    'select ''store_ids already exists'' as msg',
    'alter table biz_product add column store_ids varchar(500) default '''' comment ''适用门店ID集合（逗号分隔）'' after store_id'
  )
);
prepare stmt from @sql; execute stmt; deallocate prepare stmt;

-- 已有数据：把主门店写进 store_ids（store_id>0 的）
update biz_product set store_ids = store_id where (store_ids is null or store_ids = '') and store_id is not null and store_id > 0;


-- ############################################################
-- 源文件：sql/biz_stored_card_v3.sql
-- ############################################################

-- =====================================================================
-- 储值卡闭环 · 业务表迁移
-- 基于 PRD §STORED_CARD · 文档 doc/PRD-抖音来客商品模型.md
-- 质量标准：表结构、索引、注释完整；幂等可重入。
-- =====================================================================

-- 1) 会员储值卡实例（每会员每卡一次）
DROP TABLE IF EXISTS biz_member_stored_card;
CREATE TABLE biz_member_stored_card (
  card_id         BIGINT(20)      NOT NULL AUTO_INCREMENT      COMMENT '储值卡ID',
  merchant_id     BIGINT(20)      NOT NULL                     COMMENT '商户ID（多租户）',
  member_id       BIGINT(20)      NOT NULL                     COMMENT '会员ID',
  product_id      BIGINT(20)      NOT NULL                     COMMENT '商品ID（biz_product.type_code=STORED_CARD）',
  order_id        BIGINT(20)      DEFAULT NULL                 COMMENT '购卡订单ID（biz_order）',
  face_value      DECIMAL(10,2)   NOT NULL DEFAULT 0.00        COMMENT '面值（元）',
  balance         DECIMAL(10,2)   NOT NULL DEFAULT 0.00        COMMENT '当前余额（元）',
  used_amount     DECIMAL(10,2)   NOT NULL DEFAULT 0.00        COMMENT '累计消费金额（元）',
  recharge_amount DECIMAL(10,2)   NOT NULL DEFAULT 0.00        COMMENT '累计充值金额（元）',
  refund_amount   DECIMAL(10,2)   NOT NULL DEFAULT 0.00        COMMENT '累计退款金额（元）',
  expire_at       DATETIME        DEFAULT NULL                 COMMENT '到期时间',
  status          CHAR(1)         NOT NULL DEFAULT '0'         COMMENT '状态 0=正常 1=已冻结 2=已退卡',
  del_flag        CHAR(1)         DEFAULT '0'                  COMMENT '删除标志 0=存在 2=删除',
  create_by       VARCHAR(64)     DEFAULT ''                   COMMENT '创建者',
  create_time     DATETIME        DEFAULT CURRENT_TIMESTAMP    COMMENT '创建时间',
  update_by       VARCHAR(64)     DEFAULT ''                   COMMENT '更新者',
  update_time     DATETIME        DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  remark          VARCHAR(500)    DEFAULT NULL                 COMMENT '备注',
  PRIMARY KEY (card_id),
  UNIQUE KEY uk_member_product (merchant_id, member_id, product_id, del_flag),
  KEY idx_member (merchant_id, member_id, status),
  KEY idx_order (order_id),
  KEY idx_expire (expire_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='会员储值卡实例表';

-- 2) 储值卡流水（充值/消费/退款/反冲）
DROP TABLE IF EXISTS biz_stored_card_transaction;
CREATE TABLE biz_stored_card_transaction (
  tx_id           BIGINT(20)      NOT NULL AUTO_INCREMENT      COMMENT '流水ID',
  card_id         BIGINT(20)      NOT NULL                     COMMENT '储值卡ID',
  merchant_id     BIGINT(20)      NOT NULL                     COMMENT '商户ID',
  member_id       BIGINT(20)      NOT NULL                     COMMENT '会员ID',
  tx_type         VARCHAR(20)     NOT NULL                     COMMENT 'RECHARGE/CONSUME/REFUND/REVERSAL',
  amount          DECIMAL(10,2)   NOT NULL                     COMMENT '本次金额（正负）',
  balance_before  DECIMAL(10,2)   NOT NULL DEFAULT 0.00        COMMENT '变动前余额',
  balance_after   DECIMAL(10,2)   NOT NULL DEFAULT 0.00        COMMENT '变动后余额',
  order_id        BIGINT(20)      DEFAULT NULL                 COMMENT '关联订单ID（核销/购卡/退款）',
  biz_no          VARCHAR(64)     DEFAULT NULL                 COMMENT '业务编号（幂等键）',
  operator_type   VARCHAR(20)     DEFAULT 'MEMBER'             COMMENT '操作者类型 MEMBER/STAFF/ADMIN/SYSTEM',
  operator_id     VARCHAR(64)     DEFAULT NULL                 COMMENT '操作者ID',
  remark          VARCHAR(500)    DEFAULT NULL                 COMMENT '备注',
  create_time     DATETIME        DEFAULT CURRENT_TIMESTAMP    COMMENT '创建时间',
  PRIMARY KEY (tx_id),
  UNIQUE KEY uk_biz_no (biz_no),
  KEY idx_card_time (card_id, create_time),
  KEY idx_member_type (member_id, tx_type, create_time),
  KEY idx_order (order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='储值卡余额流水表';


-- ############################################################
-- 源文件：sql/biz_combo_subitem_v2.sql
-- ############################################################

-- 续篇 7 · 组合券包子品类型字段
-- 抖音来客截图 271：组合券包"商品搭配"每条搭配有类型下拉：团购套餐/代金券/满减券/折扣券
-- 抖音来客截图 273：填好态（团购套餐·团购 + 代金券·代金券）

ALTER TABLE biz_product_subitem
  ADD COLUMN subitem_type VARCHAR(20) DEFAULT 'GROUPON' COMMENT '子品类型（团购套餐/代金券/满减券/折扣券；组合券包用）' AFTER group_id,
  ADD COLUMN pick_quantity INT DEFAULT 1 COMMENT '份数（组合券包每条搭配的份数）' AFTER quantity,
  ADD COLUMN total_value DECIMAL(10,2) DEFAULT NULL COMMENT '总价值/划线价（组合券包整体划线价）' AFTER price;

-- 历史数据兜底
UPDATE biz_product_subitem SET subitem_type = 'GROUPON' WHERE subitem_type IS NULL;
UPDATE biz_product_subitem SET pick_quantity = quantity WHERE pick_quantity IS NULL OR pick_quantity = 0;


-- ############################################################
-- 源文件：sql/biz_role_extension.sql
-- ############################################################

-- =============================================
-- 角色权限扩展 (小程序端 3 角色 + 平台 + 代理商 = 5 角色)
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p133301 ry-vue < sql/biz_role_extension.sql
-- 可重复执行（幂等）
-- 背景：之前小程序商家端只区分「店员」一种身份，老板/店长/平台/代理都走同一链路
--       现在需要：PLATFORM（平台）/ AGENT（代理商）/ OWNER（老板）/ MANAGER（店长）/ STAFF（店员）
--       注意：biz_merchant_staff.role 字段已存在（STAFF/MANAGER/OWNER），本脚本不破坏存量数据
-- =============================================

-- 1) biz_merchant_staff.role 字段扩展注释（不改字段类型，已有 STAFF/MANAGER/OWNER）
ALTER TABLE biz_merchant_staff MODIFY COLUMN role VARCHAR(20) DEFAULT 'STAFF'
  COMMENT 'STAFF=店员 / MANAGER=店长 / OWNER=老板';

-- 2) 5 角色测试账号 (smoke-c43 密码统一 admin123)
-- 2.1) PLATFORM (user_type=00, 无商家员工关联)
INSERT INTO sys_user (user_name, nick_name, password, status, user_type, merchant_id, create_by, create_time, remark)
SELECT 'platform_c43', '平台运营C43', '$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2',
       '0', '00', 0, 'system', NOW(), 'smoke-c43 平台账号 (小程序端可查跨店业绩)'
WHERE NOT EXISTS (SELECT 1 FROM sys_user WHERE user_name='platform_c43');


-- 兜底：清理旧 'AG_C43' agent 名字
UPDATE biz_agent SET agent_name='测试代理商', contact='陈代理', phone='13900139001' WHERE agent_no='AG_C43';

-- 2.2) AGENT (user_type=01, biz_agent 关联, 无商家员工关联)
INSERT INTO sys_user (user_name, nick_name, password, status, user_type, merchant_id, create_by, create_time, remark)
SELECT 'agent_c43', '代理商C43', '$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2',
       '0', '01', 0, 'system', NOW(), 'smoke-c43 代理商账号'
WHERE NOT EXISTS (SELECT 1 FROM sys_user WHERE user_name='agent_c43');

INSERT INTO biz_agent (agent_no, agent_name, contact, phone, region, status, create_by, create_time)
SELECT 'AG_C43', '测试代理商', '陈代理', '13900139001',
       '广东省', '0', 'system', NOW()
WHERE NOT EXISTS (SELECT 1 FROM biz_agent WHERE agent_no='AG_C43');

-- biz_merchant_user 兼容 TenantIdentityResolver (agent_id 必填)
INSERT INTO biz_merchant_user (user_id, agent_id, user_type)
SELECT u.user_id, a.agent_id, '1'
FROM sys_user u, biz_agent a
WHERE u.user_name='agent_c43' AND a.agent_no='AG_C43'
  AND NOT EXISTS (SELECT 1 FROM biz_merchant_user mu
                  JOIN sys_user u2 ON u2.user_id=mu.user_id
                  JOIN biz_agent a2 ON a2.agent_id=mu.agent_id
                  WHERE u2.user_name='agent_c43' AND a2.agent_no='AG_C43');

-- 2.3) OWNER (user_type=02, biz_merchant_staff.role=OWNER)
INSERT INTO sys_user (user_name, nick_name, password, status, user_type, merchant_id, create_by, create_time, remark)
SELECT 'owner_c43', '老板C43', '$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2',
       '0', '02', 1, 'system', NOW(), 'smoke-c43 老板测试账号'
WHERE NOT EXISTS (SELECT 1 FROM sys_user WHERE user_name='owner_c43');

INSERT INTO biz_merchant_staff (merchant_id, store_id, user_id, role, real_name, status, create_by, create_time)
SELECT 1, 100, user_id, 'OWNER', '王老板', '0', 'system', NOW()
FROM sys_user WHERE user_name='owner_c43'
  AND NOT EXISTS (SELECT 1 FROM biz_merchant_staff ms
                  JOIN sys_user u ON u.user_id=ms.user_id
                  WHERE u.user_name='owner_c43' AND ms.role='OWNER');

-- 2.4) MANAGER (user_type=02, role=MANAGER)
INSERT INTO sys_user (user_name, nick_name, password, status, user_type, merchant_id, create_by, create_time, remark)
SELECT 'manager_c43', '店长C43', '$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2',
       '0', '02', 1, 'system', NOW(), 'smoke-c43 店长测试账号'
WHERE NOT EXISTS (SELECT 1 FROM sys_user WHERE user_name='manager_c43');

INSERT INTO biz_merchant_staff (merchant_id, store_id, user_id, role, real_name, status, create_by, create_time)
SELECT 1, 100, user_id, 'MANAGER', '李店长', '0', 'system', NOW()
FROM sys_user WHERE user_name='manager_c43'
  AND NOT EXISTS (SELECT 1 FROM biz_merchant_staff ms
                  JOIN sys_user u ON u.user_id=ms.user_id
                  WHERE u.user_name='manager_c43' AND ms.role='MANAGER');

-- 2.5) STAFF (user_type=02, role=STAFF)
INSERT INTO sys_user (user_name, nick_name, password, status, user_type, merchant_id, create_by, create_time, remark)
SELECT 'staff_c43', '店员C43', '$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2',
       '0', '02', 1, 'system', NOW(), 'smoke-c43 店员测试账号'
WHERE NOT EXISTS (SELECT 1 FROM sys_user WHERE user_name='staff_c43');

INSERT INTO biz_merchant_staff (merchant_id, store_id, user_id, role, real_name, status, create_by, create_time)
SELECT 1, 100, user_id, 'STAFF', '赵店员', '0', 'system', NOW()
FROM sys_user WHERE user_name='staff_c43'
  AND NOT EXISTS (SELECT 1 FROM biz_merchant_staff ms
                  JOIN sys_user u ON u.user_id=ms.user_id
                  WHERE u.user_name='staff_c43' AND ms.role='STAFF');

-- 3) 5 角色密码统一 admin123 (兜底)
UPDATE sys_user SET password = '$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2'
WHERE user_name IN ('platform_c43','agent_c43','owner_c43','manager_c43','staff_c43');

-- 4) 验证
SELECT '--- smoke-c43 5 角色账号清单 ---' AS info;
SELECT u.user_name, u.user_type AS sys_user_type,
       ms.role AS staff_role, ms.real_name,
       a.agent_name
FROM sys_user u
LEFT JOIN biz_merchant_staff ms ON ms.user_id = u.user_id
LEFT JOIN biz_merchant_user mu ON mu.user_id = u.user_id
LEFT JOIN biz_agent a ON a.agent_id = mu.agent_id
WHERE u.user_name IN ('platform_c43','agent_c43','owner_c43','manager_c43','staff_c43')
ORDER BY FIELD(u.user_name,'platform_c43','agent_c43','owner_c43','manager_c43','staff_c43');


-- ############################################################
-- 源文件：sql/biz_agent_v25.sql
-- ############################################################

-- V5-3 代理商与登录用户绑定（user_type=01 → biz_agent.user_id）
-- 用于代理商 dashboard 自动取 agentId

ALTER TABLE biz_agent
  ADD COLUMN user_id BIGINT NULL COMMENT '绑定登录用户 (sys_user.user_id)';

CREATE INDEX idx_biz_agent_user_id ON biz_agent(user_id);

-- backfill：已知的 agent_c43 (user_id=63) → agent_id=102 (测试代理商)
UPDATE biz_agent SET user_id = 63 WHERE agent_id = 102;
UPDATE biz_agent SET user_id = 62 WHERE agent_id = 1;   -- 平台直营 (platform_c43)
UPDATE biz_agent SET user_id = 64 WHERE agent_id = 100; -- 代理平台1

SELECT agent_id, agent_no, agent_name, user_id, status FROM biz_agent ORDER BY agent_id;


-- ############################################################
-- 源文件：sql/biz_agent_store_quota_hotfix.sql
-- ############################################################

-- ============================================================
-- 紧急热修：biz_agent 加 store_quota 字段
-- 场景：点"代理商/商户管理"报
--   Unknown column 'store_quota' in 'field list'
-- 原因：sql/biz_agent_store_quota.sql 没跑过
-- 修复：本脚本一条 ALTER + 索引即可
-- ============================================================

-- 1. 加字段（已存在则忽略）
SET @sql = (
  SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_schema=DATABASE() AND table_name='biz_agent' AND column_name='store_quota'),
    'SELECT 1',
    'ALTER TABLE biz_agent ADD COLUMN store_quota int(11) DEFAULT 0 COMMENT ''可开门店额度（0=不限）'' AFTER merchant_quota'
  )
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 2. 加索引（已存在则忽略）
SET @sql = (
  SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.statistics
           WHERE table_schema=DATABASE() AND table_name='biz_agent' AND index_name='idx_store_quota'),
    'SELECT 1',
    'CREATE INDEX idx_store_quota ON biz_agent (store_quota)'
  )
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 3. 默认代理商（平台直营）置 0=不限
UPDATE biz_agent SET store_quota = 0 WHERE store_quota IS NULL;

-- 4. 自检
SELECT agent_id, agent_name, store_quota FROM biz_agent WHERE del_flag = '0';


-- ############################################################
-- 源文件：sql/biz_agent_role_permissions.sql
-- ############################################################

-- =============================================
-- 代理商（agent）角色业务权限补绑
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_agent_role_permissions.sql
-- 可重复执行（幂等）
-- 背景：plan 第 1 轮做完后，agent 角色只绑了 6 个 list 权限，看不到名下商户的订单/商品/会员/门店等
--       补充：让 agent 能"只读查看"名下商户的所有业务数据 + "增删改"门店（AGENTS.md 要求）
-- =============================================

-- 0) 备份
-- CREATE TABLE sys_role_menu_bak_YYYYMMDD AS SELECT * FROM sys_role_menu;

-- 1) 补绑：代理商角色 (role_id=4) 看/管名下商户业务
-- 找 menu_id 然后 INSERT IGNORE

INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 4, menu_id FROM sys_menu WHERE perms IN (
  'biz:agent:query','biz:agent:add','biz:agent:edit','biz:agent:remove','biz:agent:export',
  'biz:agentfee:export',
  'biz:merchant:export','biz:merchant:wxconfig','biz:merchantfee:export',
  'biz:order:list','biz:order:query','biz:order:export',
  'biz:product:list','biz:product:query','biz:product:export',
  'biz:member:list','biz:member:query','biz:member:export',
  'biz:store:list','biz:store:query','biz:store:export',
  'biz:store:add','biz:store:edit','biz:store:remove',
  'biz:category:list','biz:category:query',
  'biz:bill:list','biz:bill:query','biz:bill:export',
  'biz:booking:list','biz:booking:query','biz:booking:export',
  'biz:distributor:list','biz:distributor:query','biz:distributor:export',
  'biz:voucher:list','biz:voucher:query','biz:voucher:export',
  'biz:commission:list','biz:commission:query','biz:commission:export',
  'biz:rule:list','biz:rule:query','biz:rule:export',
  'biz:account:list','biz:account:query',
  'biz:record:list','biz:record:query','biz:record:export',
  'biz:withdraw:list','biz:withdraw:query','biz:withdraw:export',
  'biz:agreement:list','biz:agreement:query',
  'biz:album:list','biz:album:query',
  'biz:user:list','biz:user:query'
);

-- 2) 清 Redis 缓存
-- redis-cli -n 0 flushdb


-- ############################################################
-- 源文件：sql/biz_member_agent_identity.sql
-- ############################################################

-- 2026-08-15: 代理商身份字段
-- 解决 /api/distributor/agent/summary dead-end (C23):
--   LoginMember 原本不读 userType/agentId, biz_member 表无列
ALTER TABLE biz_member
  ADD COLUMN user_type varchar(2) DEFAULT '0' COMMENT '用户类型: 0=普通会员 1=代理商 2=员工' AFTER status,
  ADD COLUMN agent_id  bigint(20) DEFAULT NULL COMMENT '代理商ID(user_type=1 时)' AFTER user_type;
-- 索引
ALTER TABLE biz_member
  ADD INDEX idx_user_type_agent (user_type, agent_id);


-- ############################################################
-- 源文件：sql/biz_distributor_invite.sql
-- ############################################################

-- 推客粉丝邀请机制：biz_member 增加 invite_by
-- 邀请通过 wxacode.getUnlimited 的 scene 携带，登录时回写。
-- scene 格式：distributor:{merchantId}:{memberId}

-- 幂等：仅在字段不存在时新增
SET @sql_add_invite_by = (
  SELECT IF(
    EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_member' AND COLUMN_NAME = 'invite_by'),
    'SELECT 1',
    'ALTER TABLE biz_member ADD COLUMN invite_by bigint(20) DEFAULT NULL COMMENT ''邀请人 member_id'' AFTER last_login_time'
  )
);
PREPARE stmt FROM @sql_add_invite_by; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql_add_invite_time = (
  SELECT IF(
    EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_member' AND COLUMN_NAME = 'invite_time'),
    'SELECT 1',
    'ALTER TABLE biz_member ADD COLUMN invite_time datetime DEFAULT NULL COMMENT ''邀请绑定时间'' AFTER invite_by'
  )
);
PREPARE stmt FROM @sql_add_invite_time; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 索引：粉丝列表按 invite_by 查询
SET @sql_add_idx = (
  SELECT IF(
    EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_member' AND INDEX_NAME = 'idx_invite_by'),
    'SELECT 1',
    'ALTER TABLE biz_member ADD INDEX idx_invite_by (invite_by)'
  )
);
PREPARE stmt FROM @sql_add_idx; EXECUTE stmt; DEALLOCATE PREPARE stmt;


-- ############################################################
-- 源文件：sql/biz_booking_upgrade.sql
-- ############################################################

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


-- ############################################################
-- 源文件：sql/biz_booking_slot_config.sql
-- ############################################################

-- ----------------------------
-- 预约时段容量参数
-- 小程序预约页的可选时段由 GET /api/booking/slots 按门店营业时间切分，
-- 单时段可接受的预约人数上限由本参数控制，未配置时代码内默认 10 人。
-- 幂等：已存在则不重复插入（sys_config 无 config_key 唯一索引，故用 NOT EXISTS）
-- ----------------------------
insert into sys_config (config_name, config_key, config_value, config_type, create_by, create_time, remark)
select '预约单时段人数上限', 'biz.booking.slotLimit', '10', 'Y', 'admin', sysdate(), '在线预约每个时段可接受的总人数，超出后该时段显示已约满'
from dual
where not exists (select 1 from sys_config where config_key = 'biz.booking.slotLimit');


-- ############################################################
-- 源文件：sql/biz_booking_staff_review.sql
-- ############################################################

-- ----------------------------
-- 预约报名新增员工审核字段（幂等）
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_booking_staff_review.sql
--
-- 改造要点：
-- 1) biz_booking_member 增加 confirm_user / confirm_time / review_remark
-- 2) status 字典扩展：0=已报名 1=已取消 2=已确认到店 3=已拒绝
--    （原本是 char(1)，单字符够用）
-- ----------------------------


call biz_add_column('biz_booking_member', 'confirm_user',
  "confirm_user varchar(64) default null comment '确认员工用户名' after status");
call biz_add_column('biz_booking_member', 'confirm_time',
  "confirm_time datetime default null comment '确认/拒绝时间' after confirm_user");
call biz_add_column('biz_booking_member', 'review_remark',
  "review_remark varchar(255) default null comment '员工审核备注' after confirm_time");


-- ############################################################
-- 源文件：sql/biz_merchant_service_hours_upgrade.sql
-- ############################################################

-- 商家档案：客服服务时间（弹窗显示"客服工作时间 xxx"那行）
-- biz_merchant 和 biz_store 都加；merchant 是商家级缺省，store 是门店级覆盖
--
-- 幂等说明（2026-08-21 修）：
--   新版 sql/biz_tenant_tables.sql / biz_tables.sql 建表时已含 service_hours，
--   本脚本只为存量库补列。原来是裸 ALTER，新库跑会报
--   ERROR 1054 Unknown column 'business_hours'（AFTER 的锚点列不存在）/ 1060 Duplicate column。
--   现改为按 information_schema 判断，缺列才 ADD，且不依赖 AFTER 锚点。


call biz_add_column('biz_merchant', 'business_hours', "business_hours varchar(100) DEFAULT '' COMMENT '营业时间'");
call biz_add_column('biz_merchant', 'service_hours',  "service_hours varchar(100) DEFAULT '' COMMENT '客服服务时间'");
call biz_add_column('biz_store',    'business_hours', "business_hours varchar(100) DEFAULT '' COMMENT '营业时间'");
call biz_add_column('biz_store',    'service_hours',  "service_hours varchar(100) DEFAULT '' COMMENT '客服服务时间'");


-- ############################################################
-- 源文件：sql/biz_store_service.sql
-- ############################################################

-- 导入前请指定字符集，避免中文乱码：
--   mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_store_service.sql
-- ----------------------------
-- 门店「设置及服务」字典 + biz_store.services 字段
-- 说明：services 存字典键值，多选逗号分隔
-- ----------------------------

-- 1) 门店新增服务设置字段（存在则忽略，可手动执行一次）
-- 幂等加列：新版 sql/biz_tables.sql 建表已含 services，存量库才需要 ALTER
set @sql := (
  select if(
    exists(select 1 from information_schema.columns
           where table_schema = database() and table_name = 'biz_store' and column_name = 'services'),
    'select ''biz_store.services already exists'' as msg',
    'alter table biz_store add column services varchar(255) default '''' comment ''服务设置（字典biz_store_service，多选逗号分隔）'' after intro'
  )
);
prepare stmt from @sql; execute stmt; deallocate prepare stmt;

-- 2) 字典类型
delete from sys_dict_type where dict_type = 'biz_store_service';
insert into sys_dict_type (dict_name, dict_type, status, create_by, create_time, remark)
values ('门店服务设置', 'biz_store_service', '0', 'admin', sysdate(), '门店可堂食/可预约/独立空间/停车等服务标签');

-- 3) 字典数据
delete from sys_dict_data where dict_type = 'biz_store_service';
insert into sys_dict_data (dict_sort, dict_label, dict_value, dict_type, css_class, list_class, is_default, status, create_by, create_time, remark) values
(1, '可堂食',       'dine_in',          'biz_store_service', '', 'success', 'N', '0', 'admin', sysdate(), '可堂食'),
(2, '可预约',       'can_book',         'biz_store_service', '', 'primary', 'N', '0', 'admin', sysdate(), '可预约'),
(3, '提供独立空间', 'private_room',     'biz_store_service', '', 'warning', 'N', '0', 'admin', sysdate(), '提供独立空间'),
(4, '提供免费停车场', 'free_parking_lot', 'biz_store_service', '', 'info', 'N', '0', 'admin', sysdate(), '提供免费停车场'),
(5, '免费停车',     'free_parking',     'biz_store_service', '', 'info', 'N', '0', 'admin', sysdate(), '免费停车');


-- ############################################################
-- 源文件：sql/migration-2026-08-14-f1-category-store-id.sql
-- ############################################################

-- F1 修复 biz_product_category 表缺 store_id 列
-- 现象: CategoryController.getInfo 报 SQL 错 (Unknown column 'c.store_id' in 'field list')
-- 根因: v2 升级 (8-14) 表结构变更后, XML/Domain 引用 store_id 但 schema 未加列
-- 修法: ALTER TABLE biz_product_category ADD COLUMN store_id BIGINT(20) DEFAULT NULL
--       DEFAULT NULL 保证现有数据不受影响 (NULL=平台级/全门店)
-- 验证: E16 smoke Category 段 6/6 PASS (agent 别人 500 / 自己 200 / admin 200)
-- 注（2026-08-21）：原本这里是 `USE ry-vue;`。
-- `use` 是 mysql 客户端指令，会无视命令行上指定的库直接切到 ry-vue，
-- 导致「对着测试库执行、却写进生产库」。库名请在命令行给：
--   mysql --default-character-set=utf8mb4 -uroot -p <目标库> < 本文件
-- USE ry-vue;
-- 幂等：新版建表脚本已含 store_id，存量库才需要 ALTER
SET @sql := (
  SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_schema = DATABASE() AND table_name = 'biz_product_category' AND column_name = 'store_id'),
    'SELECT ''biz_product_category.store_id already exists'' AS msg',
    'ALTER TABLE biz_product_category ADD COLUMN store_id BIGINT(20) DEFAULT NULL COMMENT ''门店ID（NULL=平台级/全门店）'''
  )
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;


-- ############################################################
-- 源文件：sql/biz_menu_reorganization.sql
-- ############################################################

-- =============================================
-- 洞天「团购运营」菜单重新分组（5 大类）
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_menu_reorganization.sql
-- 说明：19 个平级菜单调整为 门店商品 / 交易订单 / 会员体系 / 推客分销 / 平台配置
--       脚本可重复执行（幂等），菜单ID由自增分配，不硬编码，避免与代码生成器冲突
-- =============================================

-- ----------------------------
-- 步骤0：定位「团购运营」一级目录（不存在则创建）
-- 注意：不能傅底到固定 ID，否则在缺少该目录的库上会撞上自增分配的菜单 ID
-- ----------------------------
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '团购运营', 0, 4, 'tuangou', '', '', '', 1, 0, 'M', '0', '0', '', 'shopping', 'admin', SYSDATE(), '洞天团购业务'
FROM (SELECT 1) t
WHERE NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE menu_name = '团购运营' AND parent_id = 0) x);

SET @biz_id = (SELECT menu_id FROM sys_menu WHERE menu_name = '团购运营' AND parent_id = 0 LIMIT 1);

-- ----------------------------
-- 步骤1：清理历史分组目录（重复执行时先复原层级，再删除旧目录）
-- ----------------------------
UPDATE sys_menu c
  JOIN sys_menu p ON c.parent_id = p.menu_id
SET c.parent_id = @biz_id
WHERE p.parent_id = @biz_id
  AND p.menu_type = 'M'
  AND p.menu_name IN ('门店商品', '交易订单', '会员体系', '推客分销', '平台配置');

DELETE rm FROM sys_role_menu rm
  JOIN sys_menu m ON rm.menu_id = m.menu_id
WHERE m.parent_id = @biz_id
  AND m.menu_type = 'M'
  AND m.menu_name IN ('门店商品', '交易订单', '会员体系', '推客分销', '平台配置');

DELETE FROM sys_menu
WHERE parent_id = @biz_id
  AND menu_type = 'M'
  AND menu_name IN ('门店商品', '交易订单', '会员体系', '推客分销', '平台配置');

-- ----------------------------
-- 步骤2：新增 5 个二级目录（menu_type=M，component 留空 → 前端 ParentView）
-- ----------------------------
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('门店商品', @biz_id, 1, 'goods', '', '', '', 1, 0, 'M', '0', '0', '', 'shopping', 'admin', SYSDATE(), '门店、分类、商品、相册、协议');
SET @dir_goods = LAST_INSERT_ID();

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('交易订单', @biz_id, 2, 'trade', '', '', '', 1, 0, 'M', '0', '0', '', 'money', 'admin', SYSDATE(), '团购订单、买单、预约');
SET @dir_trade = LAST_INSERT_ID();

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('会员体系', @biz_id, 3, 'membership', '', '', '', 1, 0, 'M', '0', '0', '', 'peoples', 'admin', SYSDATE(), '会员、会员用户、代金券、账户');
SET @dir_member = LAST_INSERT_ID();

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('推客分销', @biz_id, 4, 'promoter', '', '', '', 1, 0, 'M', '0', '0', '', 'people', 'admin', SYSDATE(), '推客、佣金规则与记录、提现');
SET @dir_promoter = LAST_INSERT_ID();

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('平台配置', @biz_id, 5, 'setting', '', '', '', 1, 0, 'M', '0', '0', '', 'tool', 'admin', SYSDATE(), '微信小程序/支付等平台配置');
SET @dir_setting = LAST_INSERT_ID();

-- ----------------------------
-- 步骤3：19 个业务菜单挂到新目录下（按 component 匹配，同时统一菜单名称与排序）
-- ----------------------------

-- 3.1 门店商品
UPDATE sys_menu SET parent_id = @dir_goods, order_num = 1, menu_name = '门店管理' WHERE component = 'biz/store/index';
UPDATE sys_menu SET parent_id = @dir_goods, order_num = 2, menu_name = '商品分类' WHERE component = 'biz/category/index';
UPDATE sys_menu SET parent_id = @dir_goods, order_num = 3, menu_name = '商品管理' WHERE component = 'biz/product/index';
UPDATE sys_menu SET parent_id = @dir_goods, order_num = 4, menu_name = '相册管理' WHERE component = 'biz/album/index';
UPDATE sys_menu SET parent_id = @dir_goods, order_num = 5, menu_name = '协议管理' WHERE component = 'biz/agreement/index';

-- 3.2 交易订单
UPDATE sys_menu SET parent_id = @dir_trade, order_num = 1, menu_name = '团购订单' WHERE component = 'biz/order/index';
UPDATE sys_menu SET parent_id = @dir_trade, order_num = 2, menu_name = '买单记录' WHERE component = 'biz/bill/index';
UPDATE sys_menu SET parent_id = @dir_trade, order_num = 3, menu_name = '预约管理' WHERE component = 'biz/booking/index';
UPDATE sys_menu SET parent_id = @dir_trade, order_num = 4, menu_name = '预约明细' WHERE component = 'biz/bookingmember/index';

-- 3.3 会员体系
UPDATE sys_menu SET parent_id = @dir_member, order_num = 1, menu_name = '会员管理' WHERE component = 'biz/member/index';
UPDATE sys_menu SET parent_id = @dir_member, order_num = 2, menu_name = '会员用户' WHERE component = 'biz/user/index';
UPDATE sys_menu SET parent_id = @dir_member, order_num = 3, menu_name = '代金券管理' WHERE component = 'biz/voucher/index';
UPDATE sys_menu SET parent_id = @dir_member, order_num = 4, menu_name = '会员账户' WHERE component = 'biz/account/index';

-- 3.4 推客分销
UPDATE sys_menu SET parent_id = @dir_promoter, order_num = 1, menu_name = '推客管理' WHERE component = 'biz/distributor/index';
UPDATE sys_menu SET parent_id = @dir_promoter, order_num = 2, menu_name = '佣金规则' WHERE component = 'biz/rule/index';
UPDATE sys_menu SET parent_id = @dir_promoter, order_num = 3, menu_name = '佣金记录' WHERE component = 'biz/commission/index';
UPDATE sys_menu SET parent_id = @dir_promoter, order_num = 4, menu_name = '提现申请' WHERE component = 'biz/withdraw/index';
UPDATE sys_menu SET parent_id = @dir_promoter, order_num = 5, menu_name = '提现记录' WHERE component = 'biz/record/index';

-- 3.5 平台配置
UPDATE sys_menu SET parent_id = @dir_setting, order_num = 1, menu_name = '微信配置' WHERE component = 'biz/wxconfig/index';
UPDATE sys_menu SET parent_id = @dir_setting, order_num = 2, menu_name = '小程序平台配置' WHERE component = 'biz/mpconfig/index';

-- ----------------------------
-- 步骤4：角色权限同步（凡拥有分组内任一菜单的角色，补授该分组目录）
-- ----------------------------
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT DISTINCT rm.role_id, c.parent_id
FROM sys_role_menu rm
  JOIN sys_menu c ON rm.menu_id = c.menu_id
WHERE c.parent_id IN (@dir_goods, @dir_trade, @dir_member, @dir_promoter, @dir_setting);

-- ----------------------------
-- 验证：查看分组结果
-- ----------------------------
SELECT p.menu_name AS 分组, c.order_num AS 排序, c.menu_name AS 菜单, c.path AS 路由, c.component AS 组件
FROM sys_menu p
  JOIN sys_menu c ON c.parent_id = p.menu_id
WHERE p.parent_id = @biz_id AND p.menu_type = 'M'
ORDER BY p.order_num, c.order_num;


-- ############################################################
-- 源文件：sql/biz_menu_business_pages.sql
-- ############################################################

-- ============================================================
-- 补齐 19 个业务菜单页 + 按钮权限（2026-08-22）
--
-- 背景：这 19 个业务菜单最初由 RuoYi 代码生成器直接写进开发库，
--       建表 SQL 从未入仓。sql/biz_menu_reorganization.sql 只做「重新分组」
--       （把已存在的菜单移到 5 个分组下），并不创建它们。
--       → 全新库跑完 init-all.sh 后，后台只有 14 个业务菜单，
--         订单/会员/商品/门店/推客/佣金等 18 个页面在侧边栏根本不出现。
--
-- 幂等：全部按 perms / menu_name 判断存在性，可重复执行
-- 注意：菜单 ID 由自增分配，父子关系一律按「菜单名」查找，不硬编码 ID
--       （本地库 2108=门店商品，脚本库 2108=首页轮播图，硬编码必错）
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p <库名> < sql/biz_menu_business_pages.sql
-- ============================================================

-- 0) 分组目录（门店商品/交易订单/会员体系/推客分销/平台配置）由
--    sql/biz_menu_reorganization.sql 创建，本脚本必须在它之后执行，
--    这里只按名字查找、绝不自建，否则会出现两套同名分组。

-- 1) 18 个业务菜单页（C 型）

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='商品管理' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品创建', @pid, 1, 'create', 'biz/product/create', NULL, '', 1, 0, 'C', '0', '0', 'biz:product:add', '#', 'admin', SYSDATE(), '商品创建路由（抖音来客风格）'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:add' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='商品管理' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品详情', @pid, 2, 'detail/:productId(d+)', 'biz/product/detail', NULL, '', 1, 0, 'C', '1', '0', 'biz:product:query', '#', 'admin', SYSDATE(), '商品详情路由'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:query' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='门店商品' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店管理', @pid, 1, 'store', 'biz/store/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:store:list', 'shopping', 'admin', SYSDATE(), '门店菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:store:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='门店商品' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品分类', @pid, 2, 'category', 'biz/category/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:category:list', 'list', 'admin', SYSDATE(), '商品分类菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:category:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='门店商品' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品管理', @pid, 3, 'product', 'biz/product/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:product:list', 'goods', 'admin', SYSDATE(), '商品菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='门店商品' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '相册管理', @pid, 4, 'album', 'biz/album/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:album:list', 'image', 'admin', SYSDATE(), '门店相册菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:album:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='门店商品' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '协议管理', @pid, 5, 'agreement', 'biz/agreement/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:agreement:list', 'documentation', 'admin', SYSDATE(), '协议菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='交易订单' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '团购订单', @pid, 1, 'order', 'biz/order/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:order:list', 'form', 'admin', SYSDATE(), '订单菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:order:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='交易订单' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单记录', @pid, 2, 'bill', 'biz/bill/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:bill:list', 'money', 'admin', SYSDATE(), '买单流水菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='会员体系' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员管理', @pid, 1, 'member', 'biz/member/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:member:list', 'peoples', 'admin', SYSDATE(), '会员菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:member:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='会员体系' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员用户', @pid, 2, 'user', 'biz/user/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:user:list', 'tree', 'admin', SYSDATE(), '账号门店关联菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:user:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='会员体系' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '代金券管理', @pid, 3, 'voucher', 'biz/voucher/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:voucher:list', 'star', 'admin', SYSDATE(), '代金券模板菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='会员体系' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员账户', @pid, 4, 'account', 'biz/account/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:account:list', 'validCode', 'admin', SYSDATE(), '分账接收方菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:account:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='推客分销' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '推客管理', @pid, 1, 'distributor', 'biz/distributor/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:distributor:list', 'user', 'admin', SYSDATE(), '推客菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='推客分销' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金规则', @pid, 2, 'rule', 'biz/rule/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:rule:list', 'edit', 'admin', SYSDATE(), '佣金规则菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='推客分销' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金记录', @pid, 3, 'commission', 'biz/commission/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:commission:list', 'money', 'admin', SYSDATE(), '佣金明细菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='推客分销' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '提现申请', @pid, 4, 'withdraw', 'biz/withdraw/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:withdraw:list', 'money', 'admin', SYSDATE(), '提现记录菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='推客分销' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '提现记录', @pid, 5, 'record', 'biz/record/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:record:list', 'documentation', 'admin', SYSDATE(), '分账明细菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:record:list' AND menu_type='C') x);

-- 2) 按钮权限（F 型），父菜单按 perms 定位

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:account:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账接收方查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:account:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:account:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:account:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账接收方新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:account:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:account:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:account:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账接收方修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:account:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:account:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:account:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账接收方删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:account:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:account:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:account:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账接收方导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:account:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:account:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '协议查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:agreement:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '协议新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:agreement:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '协议修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:agreement:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '协议删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:agreement:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '协议导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:agreement:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:album:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店相册查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:album:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:album:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:album:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店相册新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:album:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:album:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:album:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店相册修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:album:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:album:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:album:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店相册删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:album:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:album:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:album:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店相册导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:album:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:album:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单流水查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:bill:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单流水新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:bill:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单流水修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:bill:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单流水删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:bill:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单流水导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:bill:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单确认', @pid, 6, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:bill:confirm', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:confirm') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:category:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品分类查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:category:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:category:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:category:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品分类新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:category:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:category:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:category:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品分类修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:category:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:category:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:category:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品分类删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:category:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:category:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:category:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品分类导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:category:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:category:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金明细查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:commission:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金明细新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:commission:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金明细修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:commission:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金明细删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:commission:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金明细导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:commission:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '推客查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:distributor:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '推客新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:distributor:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '推客修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:distributor:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '推客删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:distributor:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '推客导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:distributor:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:member:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:member:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:member:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:member:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:member:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:member:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:member:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:member:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:member:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:member:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:member:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:member:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:member:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:member:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:member:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:order:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '订单查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:order:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:order:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:order:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '订单新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:order:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:order:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:order:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '订单修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:order:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:order:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:order:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '订单删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:order:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:order:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:order:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '订单导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:order:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:order:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:order:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '订单核销', @pid, 6, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:order:verify', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:order:verify') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:product:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:product:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:product:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:product:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:product:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:product:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:product:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:product:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:product:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:product:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:record:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账明细查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:record:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:record:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:record:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账明细新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:record:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:record:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:record:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账明细修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:record:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:record:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:record:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账明细删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:record:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:record:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:record:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账明细导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:record:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:record:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金规则查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:rule:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金规则新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:rule:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金规则修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:rule:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金规则删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:rule:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金规则导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:rule:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:store:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:store:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:store:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:store:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:store:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:store:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:store:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:store:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:store:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:store:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:store:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:store:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:store:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:store:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:store:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:user:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '账号门店关联查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:user:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:user:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:user:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '账号门店关联新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:user:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:user:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:user:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '账号门店关联修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:user:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:user:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:user:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '账号门店关联删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:user:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:user:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:user:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '账号门店关联导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:user:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:user:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '代金券模板查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:voucher:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '代金券模板新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:voucher:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '代金券模板修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:voucher:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '代金券模板删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:voucher:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '代金券模板导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:voucher:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '提现记录查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:withdraw:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:query') x);


-- ============================================================
-- 5) 延后建的按钮：biz:booking:* / biz:withdraw:* 的父菜单由本文件之后的
--    脚本创建（预约明细 / 提现申请），必须放在角色绑定之后再挂，否则 @pid 为空。
-- ============================================================
SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '在线预约查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:booking:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '在线预约新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:booking:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '在线预约修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:booking:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '在线预约删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:booking:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '在线预约导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:booking:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '提现记录新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:withdraw:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '提现记录修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:withdraw:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '提现记录删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:withdraw:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '提现记录导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:withdraw:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:export') x);

-- ============================================================
-- 4) 角色绑定：把业务菜单授予 admin(role_id=1) 与平台角色(role_id=3)
--    不绑的话菜单建了也不会出现在侧边栏（RuoYi 按 sys_role_menu 过滤）
-- ============================================================
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu WHERE perms LIKE 'biz:%';

INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu WHERE menu_type='M'
  AND menu_name IN ('团购运营','门店商品','交易订单','会员体系','推客分销','平台配置');

INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 3, menu_id FROM sys_menu
WHERE (perms LIKE 'biz:%'
       OR (menu_type='M' AND menu_name IN ('团购运营','门店商品','交易订单','会员体系','推客分销','平台配置')))
  AND EXISTS (SELECT 1 FROM sys_role WHERE role_id=3);

-- 补绑这些按钮到角色
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu WHERE perms IN
  ('biz:booking:query','biz:booking:add','biz:booking:edit','biz:booking:remove','biz:booking:export',
   'biz:withdraw:add','biz:withdraw:edit','biz:withdraw:remove','biz:withdraw:export');
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 3, menu_id FROM sys_menu WHERE perms IN
  ('biz:booking:query','biz:booking:add','biz:booking:edit','biz:booking:remove','biz:booking:export',
   'biz:withdraw:add','biz:withdraw:edit','biz:withdraw:remove','biz:withdraw:export')
  AND EXISTS (SELECT 1 FROM sys_role WHERE role_id=3);

-- ============================================================
-- 6) 兜底：sys_menu.parent_id 绝不允许 NULL
--    SysMenu.getParentId() 被 SysMenuServiceImpl 直接 longValue()，
--    任何一行 parent_id IS NULL 都会让 GET /getRouters 抛 500，
--    表现为「登录成功但后台侧边栏全空」。
--    历史上 biz_banner.sql（找不存在的「商城管理」）和 biz_merchant_v2.sql
--    （要求门店商品挂在团购运营下）都踩过，这里统一收敛为顶级 0。
-- ============================================================
UPDATE sys_menu SET parent_id = 0 WHERE parent_id IS NULL;

-- 6.1) 上面兜底会把这两个菜单变成「顶级但无分组标题」（侧边栏出现无名分组）。
--      归位：员工管理 → 门店商品；小程序授权 → 平台配置。
--      注：MySQL 不允许 UPDATE 的子查询引用同一张表（ERROR 1093），先用变量取出。
SET @goods_pid = (SELECT menu_id FROM sys_menu WHERE menu_name='门店商品' AND menu_type='M' ORDER BY menu_id LIMIT 1);
UPDATE sys_menu SET parent_id = @goods_pid
WHERE perms = 'biz:staffInvite:list' AND menu_type='C' AND parent_id = 0 AND @goods_pid IS NOT NULL;

SET @conf_pid = (SELECT menu_id FROM sys_menu WHERE menu_name='平台配置' AND menu_type='M' ORDER BY menu_id LIMIT 1);
UPDATE sys_menu SET parent_id = @conf_pid
WHERE perms = 'biz:mpauth:list' AND menu_type='C' AND parent_id = 0 AND @conf_pid IS NOT NULL;


-- ############################################################
-- 源文件：sql/biz_menu_flatten.sql
-- ############################################################

-- =============================================
-- 菜单平铺：去掉"团购运营"顶级，6 个子模块平铺为顶级 + 2215 改名"我的商户"
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_menu_flatten.sql
-- 可重复执行（幂等）
-- 前置：已完成 19 个业务页建表 + 5 大类二级分组（见 sql/biz_menu_reorganization.sql），
--       此时"团购运营"顶级 menu_id=2001，下挂 2108/2109/2110/2111/2112/2215
-- =============================================

-- 0) 备份（重演前先备份）
-- CREATE TABLE sys_menu_bak_YYYYMMDD AS SELECT * FROM sys_menu;
-- CREATE TABLE sys_role_menu_bak_YYYYMMDD AS SELECT * FROM sys_role_menu;

-- 1) 6 个二级菜单平铺为顶级（order_num 5 起步，避让 RuoYi 原生 1-4）
UPDATE sys_menu SET parent_id=0, order_num=5  WHERE menu_id=2108;
UPDATE sys_menu SET parent_id=0, order_num=6  WHERE menu_id=2109;
UPDATE sys_menu SET parent_id=0, order_num=7  WHERE menu_id=2110;
UPDATE sys_menu SET parent_id=0, order_num=8  WHERE menu_id=2111;
UPDATE sys_menu SET parent_id=0, order_num=9  WHERE menu_id=2112;
UPDATE sys_menu SET parent_id=0, order_num=10, menu_name='我的商户' WHERE menu_id=2215;

-- 2) 删"团购运营"顶级 2001 及其角色绑定
DELETE FROM sys_role_menu WHERE menu_id=2001;
DELETE FROM sys_menu       WHERE menu_id=2001;

-- 3) 角色重新绑顶级（admin=1, platform=3, agent=4, merchant=5）
--    admin / platform 看全部 6 个顶级
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) VALUES(1,2108),(1,2109),(1,2110),(1,2111),(1,2112),(1,2215);
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) VALUES(3,2108),(3,2109),(3,2110),(3,2111),(3,2112),(3,2215);
--    agent 只看"我的商户"
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) VALUES(4,2215);
--    merchant 看 5 个（不含 2112 平台配置）
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) VALUES(5,2108),(5,2109),(5,2110),(5,2111),(5,2215);

-- 4) 清理悬空绑定
DELETE rm FROM sys_role_menu rm LEFT JOIN sys_menu m ON rm.menu_id=m.menu_id WHERE m.menu_id IS NULL;

-- 5) 清 Redis 缓存（必须！否则 getRouters 返旧值）
-- redis-cli -n 0 flushdb

-- A3: 补 'biz:mpconfig:list' 菜单 + 绑 platform/admin/agent 角色
INSERT INTO sys_menu(menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark) 
SELECT '平台状态查询', 2112, 1, '#', '', 1, 0, 'F', '0', '0', 'biz:mpconfig:list', '#', 'admin', NOW(), '第三方平台状态'
FROM (SELECT 1) t
WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='biz:mpconfig:list');
SET @mp_list = (SELECT menu_id FROM sys_menu WHERE perms='biz:mpconfig:list' LIMIT 1);
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) SELECT 1, @mp_list;
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) SELECT 3, @mp_list;
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) SELECT 4, @mp_list;

-- 轮播图管理（在 平台配置 顶级下）
INSERT INTO sys_menu(menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '轮播图管理', 2112, 10, 'banner', 'biz/banner/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:banner:list', 'picture', 'admin', NOW(), '首页 banner 轮播图'
FROM (SELECT 1) t
WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='biz:banner:list');
SET @banner_id = (SELECT menu_id FROM sys_menu WHERE perms='biz:banner:list' LIMIT 1);
-- 5 个按钮权限
INSERT INTO sys_menu(menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT 'banner:query', @banner_id, 1, '#', NULL, NULL, '', 1, 0, 'F', '0', '0', 'biz:banner:query', '#', 'admin', NOW(), 'banner 按钮'
FROM (SELECT 1) t WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='biz:banner:query');
INSERT INTO sys_menu(menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT 'banner:add', @banner_id, 2, '#', NULL, NULL, '', 1, 0, 'F', '0', '0', 'biz:banner:add', '#', 'admin', NOW(), 'banner 按钮'
FROM (SELECT 1) t WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='biz:banner:add');
INSERT INTO sys_menu(menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT 'banner:edit', @banner_id, 3, '#', NULL, NULL, '', 1, 0, 'F', '0', '0', 'biz:banner:edit', '#', 'admin', NOW(), 'banner 按钮'
FROM (SELECT 1) t WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='biz:banner:edit');
INSERT INTO sys_menu(menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT 'banner:remove', @banner_id, 4, '#', NULL, NULL, '', 1, 0, 'F', '0', '0', 'biz:banner:remove', '#', 'admin', NOW(), 'banner 按钮'
FROM (SELECT 1) t WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='biz:banner:remove');
INSERT INTO sys_menu(menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT 'banner:export', @banner_id, 5, '#', NULL, NULL, '', 1, 0, 'F', '0', '0', 'biz:banner:export', '#', 'admin', NOW(), 'banner 按钮'
FROM (SELECT 1) t WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='biz:banner:export');
-- 绑 admin / platform 角色
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) SELECT 1, @banner_id;
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) SELECT 3, @banner_id;
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) 
  SELECT 1, menu_id FROM sys_menu WHERE parent_id=@banner_id;
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) 
  SELECT 3, menu_id FROM sys_menu WHERE parent_id=@banner_id;

-- 轮播图管理（商户自管）— 移到 门店商品 顶级下
-- 注：MySQL 5.7 的 DELETE 不允许子查询引用目标表（ERROR 1093），
--     即使包一层派生表也会被合并优化掉，所以先用变量取出 menu_id 再删。
SET @old_banner_id = (SELECT menu_id FROM sys_menu WHERE perms='biz:banner:list' LIMIT 1);
DELETE FROM sys_role_menu WHERE menu_id = @old_banner_id;
DELETE FROM sys_role_menu WHERE menu_id IN (SELECT menu_id FROM sys_menu WHERE parent_id = @old_banner_id);
DELETE FROM sys_menu WHERE parent_id = @old_banner_id AND @old_banner_id IS NOT NULL;
DELETE FROM sys_menu WHERE perms='biz:banner:list';
INSERT INTO sys_menu(menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '轮播图管理', 2108, 6, 'banner', 'biz/banner/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:banner:list', 'picture', 'admin', NOW(), '商户首页轮播图'
FROM (SELECT 1) t WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='biz:banner:list');
SET @banner_id = (SELECT menu_id FROM sys_menu WHERE perms='biz:banner:list' LIMIT 1);
INSERT INTO sys_menu(menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT 'banner:query', @banner_id, 1, '#', NULL, NULL, '', 1, 0, 'F', '0', '0', 'biz:banner:query', '#', 'admin', NOW(), 'banner 按钮'
FROM (SELECT 1) t WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='biz:banner:query');
INSERT INTO sys_menu(menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT 'banner:add', @banner_id, 2, '#', NULL, NULL, '', 1, 0, 'F', '0', '0', 'biz:banner:add', '#', 'admin', NOW(), 'banner 按钮'
FROM (SELECT 1) t WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='biz:banner:add');
INSERT INTO sys_menu(menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT 'banner:edit', @banner_id, 3, '#', NULL, NULL, '', 1, 0, 'F', '0', '0', 'biz:banner:edit', '#', 'admin', NOW(), 'banner 按钮'
FROM (SELECT 1) t WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='biz:banner:edit');
INSERT INTO sys_menu(menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT 'banner:remove', @banner_id, 4, '#', NULL, NULL, '', 1, 0, 'F', '0', '0', 'biz:banner:remove', '#', 'admin', NOW(), 'banner 按钮'
FROM (SELECT 1) t WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='biz:banner:remove');
INSERT INTO sys_menu(menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT 'banner:export', @banner_id, 5, '#', NULL, NULL, '', 1, 0, 'F', '0', '0', 'biz:banner:export', '#', 'admin', NOW(), 'banner 按钮'
FROM (SELECT 1) t WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='biz:banner:export');
-- 绑商户(5) 角色（商户自管 banner）
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) SELECT 5, @banner_id;
INSERT IGNORE INTO sys_role_menu(role_id, menu_id) SELECT 5, menu_id FROM sys_menu WHERE parent_id=@banner_id;


-- ############################################################
-- 源文件：sql/biz_tenant_menu.sql
-- ############################################################

-- =============================================
-- 多商户 + 代理商 菜单与角色初始化（幂等，可重复执行）
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_tenant_menu.sql
-- 内容：租户管理目录 + 代理商/商户/缴费/小程序发布菜单 + 平台/代理商/商户三类角色
-- 菜单ID由自增分配，不硬编码，避免与代码生成器冲突
-- =============================================

-- ----------------------------
-- 步骤0：定位「团购运营」一级目录（不存在则创建）
-- 注意：不能傅底到固定 ID，否则在缺少该目录的库上会撞上自增分配的菜单 ID
-- ----------------------------
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '团购运营', 0, 4, 'tuangou', '', '', '', 1, 0, 'M', '0', '0', '', 'shopping', 'admin', SYSDATE(), '洞天团购业务'
FROM (SELECT 1) t
WHERE NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE menu_name = '团购运营' AND parent_id = 0) x);

SET @biz_id = (SELECT menu_id FROM sys_menu WHERE menu_name = '团购运营' AND parent_id = 0 LIMIT 1);

-- ----------------------------
-- 步骤1：清理历史「租户管理」目录（重复执行时先复原层级再删除）
-- ----------------------------
UPDATE sys_menu c
  JOIN sys_menu p ON c.parent_id = p.menu_id
SET c.parent_id = @biz_id
WHERE p.parent_id = @biz_id AND p.menu_type = 'M' AND p.menu_name = '租户管理';

DELETE rm FROM sys_role_menu rm
  JOIN sys_menu m ON rm.menu_id = m.menu_id
WHERE m.parent_id = @biz_id AND m.menu_type = 'M' AND m.menu_name = '租户管理';

DELETE FROM sys_menu WHERE parent_id = @biz_id AND menu_type = 'M' AND menu_name = '租户管理';

-- 清理本脚本管理的业务菜单（按 component 定位，含其下按钮权限）
-- MySQL 不允许 DELETE 子查询直接引用目标表，先用临时表暂存菜单ID
DROP TEMPORARY TABLE IF EXISTS tmp_tenant_menu;
CREATE TEMPORARY TABLE tmp_tenant_menu (menu_id BIGINT(20) PRIMARY KEY);

INSERT INTO tmp_tenant_menu (menu_id)
SELECT menu_id FROM sys_menu WHERE component IN
  ('biz/agent/index', 'biz/merchant/index', 'biz/agentfee/index', 'biz/merchantfee/index', 'biz/mprelease/index');

-- 临时表在同一语句中不可重复打开，父子两级分两张临时表处理
DROP TEMPORARY TABLE IF EXISTS tmp_tenant_child;
CREATE TEMPORARY TABLE tmp_tenant_child (menu_id BIGINT(20) PRIMARY KEY);

INSERT IGNORE INTO tmp_tenant_child (menu_id)
SELECT m.menu_id FROM sys_menu m JOIN tmp_tenant_menu t ON m.parent_id = t.menu_id;

INSERT IGNORE INTO tmp_tenant_menu (menu_id)
SELECT menu_id FROM tmp_tenant_child;

DELETE rm FROM sys_role_menu rm JOIN tmp_tenant_menu t ON rm.menu_id = t.menu_id;
DELETE m FROM sys_menu m JOIN tmp_tenant_menu t ON m.menu_id = t.menu_id;

DROP TEMPORARY TABLE IF EXISTS tmp_tenant_child;
DROP TEMPORARY TABLE IF EXISTS tmp_tenant_menu;

-- ----------------------------
-- 步骤2：新增「租户管理」二级目录
-- ----------------------------
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('租户管理', @biz_id, 0, 'tenant', '', '', '', 1, 0, 'M', '0', '0', '', 'peoples', 'admin', SYSDATE(), '代理商、商户、缴费与小程序发布');
SET @dir_tenant = LAST_INSERT_ID();

-- ----------------------------
-- 步骤3：业务菜单（C）
-- ----------------------------
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('代理商管理', @dir_tenant, 1, 'agent', 'biz/agent/index', '', '', 1, 0, 'C', '0', '0', 'biz:agent:list', 'tree', 'admin', SYSDATE(), '平台管理代理商及商户额度');
SET @m_agent = LAST_INSERT_ID();

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('代理商缴费', @dir_tenant, 2, 'agentfee', 'biz/agentfee/index', '', '', 1, 0, 'C', '0', '0', 'biz:agentfee:list', 'money', 'admin', SYSDATE(), '代理商向平台缴费与额度充值');
SET @m_agentfee = LAST_INSERT_ID();

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('商户管理', @dir_tenant, 3, 'merchant', 'biz/merchant/index', '', '', 1, 0, 'C', '0', '0', 'biz:merchant:list', 'shopping', 'admin', SYSDATE(), '商户开通、小程序AppId与支付配置');
SET @m_merchant = LAST_INSERT_ID();

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('商户收费', @dir_tenant, 4, 'merchantfee', 'biz/merchantfee/index', '', '', 1, 0, 'C', '0', '0', 'biz:merchantfee:list', 'money', 'admin', SYSDATE(), '代理商向商户收费记录');
SET @m_merchantfee = LAST_INSERT_ID();

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('小程序发布', @dir_tenant, 5, 'mprelease', 'biz/mprelease/index', '', '', 1, 0, 'C', '0', '0', 'biz:mprelease:list', 'upload', 'admin', SYSDATE(), '小程序授权、代上传、提审与发布');
SET @m_release = LAST_INSERT_ID();

-- ----------------------------
-- 步骤4：按钮权限（F）
-- ----------------------------
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark) VALUES
('代理商查询', @m_agent, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:agent:query',  '#', 'admin', SYSDATE(), ''),
('代理商新增', @m_agent, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:agent:add',    '#', 'admin', SYSDATE(), ''),
('代理商修改', @m_agent, 3, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:agent:edit',   '#', 'admin', SYSDATE(), ''),
('代理商删除', @m_agent, 4, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:agent:remove', '#', 'admin', SYSDATE(), ''),
('代理商导出', @m_agent, 5, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:agent:export', '#', 'admin', SYSDATE(), '');

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark) VALUES
('缴费查询', @m_agentfee, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:agentfee:query',  '#', 'admin', SYSDATE(), ''),
('缴费登记', @m_agentfee, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:agentfee:add',    '#', 'admin', SYSDATE(), ''),
('缴费修改', @m_agentfee, 3, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:agentfee:edit',   '#', 'admin', SYSDATE(), ''),
('缴费审核', @m_agentfee, 4, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:agentfee:audit',  '#', 'admin', SYSDATE(), '确认到账并发放商户额度'),
('缴费删除', @m_agentfee, 5, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:agentfee:remove', '#', 'admin', SYSDATE(), '');

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark) VALUES
('商户查询',   @m_merchant, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:merchant:query',  '#', 'admin', SYSDATE(), ''),
('商户新增',   @m_merchant, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:merchant:add',    '#', 'admin', SYSDATE(), '代理商在额度内开通商户'),
('商户修改',   @m_merchant, 3, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:merchant:edit',   '#', 'admin', SYSDATE(), ''),
('商户删除',   @m_merchant, 4, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:merchant:remove', '#', 'admin', SYSDATE(), ''),
('商户导出',   @m_merchant, 5, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:merchant:export', '#', 'admin', SYSDATE(), ''),
('微信配置',   @m_merchant, 6, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:merchant:wxconfig', '#', 'admin', SYSDATE(), '维护商户小程序与支付凭证');

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark) VALUES
('收费查询', @m_merchantfee, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:merchantfee:query',  '#', 'admin', SYSDATE(), ''),
('收费登记', @m_merchantfee, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:merchantfee:add',    '#', 'admin', SYSDATE(), ''),
('收费修改', @m_merchantfee, 3, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:merchantfee:edit',   '#', 'admin', SYSDATE(), ''),
('收费删除', @m_merchantfee, 4, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:merchantfee:remove', '#', 'admin', SYSDATE(), '');

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark) VALUES
('发布记录查询', @m_release, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:mprelease:query',   '#', 'admin', SYSDATE(), ''),
('小程序授权',   @m_release, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:mprelease:auth',    '#', 'admin', SYSDATE(), '生成第三方平台授权链接'),
('代码上传',     @m_release, 3, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:mprelease:upload',  '#', 'admin', SYSDATE(), '按模板+ext.json代上传'),
('提交审核',     @m_release, 4, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:mprelease:audit',   '#', 'admin', SYSDATE(), ''),
('发布上线',     @m_release, 5, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:mprelease:release', '#', 'admin', SYSDATE(), ''),
('版本回退',     @m_release, 6, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:mprelease:rollback','#', 'admin', SYSDATE(), '');

-- ----------------------------
-- 步骤5：三类角色（平台管理员 / 代理商 / 商户管理员）
-- data_scope=1 全部数据，2 自定，4 本部门及以下
-- 业务数据隔离由 merchant_id 租户上下文强制过滤，部门数据权限只管账号与组织可见范围
-- ----------------------------
INSERT INTO sys_role (role_name, role_key, role_sort, data_scope, menu_check_strictly, dept_check_strictly, status, del_flag, create_by, create_time, remark)
SELECT '平台管理员', 'platform', 3, '1', 1, 1, '0', '0', 'admin', SYSDATE(), '平台侧：代理商与商户全局管理'
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM (SELECT role_id FROM sys_role WHERE role_key = 'platform') t);

INSERT INTO sys_role (role_name, role_key, role_sort, data_scope, menu_check_strictly, dept_check_strictly, status, del_flag, create_by, create_time, remark)
SELECT '代理商', 'agent', 4, '4', 1, 1, '0', '0', 'admin', SYSDATE(), '代理商侧：在额度内开通并管理自己的商户'
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM (SELECT role_id FROM sys_role WHERE role_key = 'agent') t);

INSERT INTO sys_role (role_name, role_key, role_sort, data_scope, menu_check_strictly, dept_check_strictly, status, del_flag, create_by, create_time, remark)
SELECT '商户管理员', 'merchant', 5, '4', 1, 1, '0', '0', 'admin', SYSDATE(), '商户侧：仅可见本商户门店与业务数据'
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM (SELECT role_id FROM sys_role WHERE role_key = 'merchant') t);

SET @role_platform = (SELECT role_id FROM sys_role WHERE role_key = 'platform' LIMIT 1);
SET @role_agent    = (SELECT role_id FROM sys_role WHERE role_key = 'agent'    LIMIT 1);
SET @role_merchant = (SELECT role_id FROM sys_role WHERE role_key = 'merchant' LIMIT 1);

-- ----------------------------
-- 步骤6：角色授权
-- ----------------------------
-- 6.1 超级管理员 + 平台管理员：租户管理全部菜单
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu WHERE menu_id = @dir_tenant OR parent_id = @dir_tenant
   OR parent_id IN (@m_agent, @m_agentfee, @m_merchant, @m_merchantfee, @m_release);

INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_platform, menu_id FROM sys_menu WHERE menu_id = @dir_tenant OR parent_id = @dir_tenant
   OR parent_id IN (@m_agent, @m_agentfee, @m_merchant, @m_merchantfee, @m_release);

-- 平台管理员额外拥有全部团购业务菜单（只读运营查看）
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_platform, menu_id FROM sys_menu WHERE menu_id = @biz_id OR parent_id = @biz_id;

-- 6.2 代理商：商户管理 + 商户收费 + 小程序发布（不含代理商管理与平台缴费审核）
INSERT IGNORE INTO sys_role_menu (role_id, menu_id) VALUES
(@role_agent, @dir_tenant), (@role_agent, @m_merchant), (@role_agent, @m_merchantfee), (@role_agent, @m_release);

INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_agent, menu_id FROM sys_menu
WHERE parent_id IN (@m_merchant, @m_merchantfee, @m_release)
  AND perms <> 'biz:merchant:remove';

-- 代理商可查看自己缴费记录（无审核权）
INSERT IGNORE INTO sys_role_menu (role_id, menu_id) VALUES (@role_agent, @m_agentfee);
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_agent, menu_id FROM sys_menu WHERE parent_id = @m_agentfee AND perms IN ('biz:agentfee:query', 'biz:agentfee:add');

-- 6.3 商户管理员：全部团购业务菜单 + 自己的小程序发布，不含租户管理与平台配置
-- 「平台配置」目录下是平台级参数（微信/支付兜底凭证、开放平台第三方参数），
-- 商户账号一律不可见，其自身小程序与支付凭证在「商户管理」的微信配置弹窗中维护
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_merchant, menu_id FROM sys_menu
WHERE menu_id = @biz_id
   OR (parent_id = @biz_id AND NOT (menu_type = 'M' AND menu_name = '平台配置'));

INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_merchant, c.menu_id FROM sys_menu p JOIN sys_menu c ON c.parent_id = p.menu_id
WHERE p.parent_id = @biz_id AND p.menu_type = 'M' AND p.menu_name NOT IN ('租户管理', '平台配置');

INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_merchant, f.menu_id FROM sys_menu p
  JOIN sys_menu c ON c.parent_id = p.menu_id
  JOIN sys_menu f ON f.parent_id = c.menu_id
WHERE p.parent_id = @biz_id AND p.menu_type = 'M' AND p.menu_name NOT IN ('租户管理', '平台配置');

-- 回收历史脚本可能已授予商户/代理商的平台配置权限（目录 + 页面 + 按钮）
DROP TEMPORARY TABLE IF EXISTS tmp_setting_menu;
CREATE TEMPORARY TABLE tmp_setting_menu (menu_id BIGINT(20) PRIMARY KEY);

INSERT IGNORE INTO tmp_setting_menu (menu_id)
SELECT menu_id FROM sys_menu WHERE parent_id = @biz_id AND menu_type = 'M' AND menu_name = '平台配置';

INSERT IGNORE INTO tmp_setting_menu (menu_id)
SELECT c.menu_id FROM sys_menu c JOIN sys_menu p ON c.parent_id = p.menu_id
WHERE p.parent_id = @biz_id AND p.menu_type = 'M' AND p.menu_name = '平台配置';

INSERT IGNORE INTO tmp_setting_menu (menu_id)
SELECT f.menu_id FROM sys_menu f
  JOIN sys_menu c ON f.parent_id = c.menu_id
  JOIN sys_menu p ON c.parent_id = p.menu_id
WHERE p.parent_id = @biz_id AND p.menu_type = 'M' AND p.menu_name = '平台配置';

DELETE rm FROM sys_role_menu rm JOIN tmp_setting_menu t ON rm.menu_id = t.menu_id
WHERE rm.role_id IN (@role_merchant, @role_agent);

DROP TEMPORARY TABLE IF EXISTS tmp_setting_menu;

INSERT IGNORE INTO sys_role_menu (role_id, menu_id) VALUES (@role_merchant, @dir_tenant), (@role_merchant, @m_release);
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_merchant, menu_id FROM sys_menu WHERE parent_id = @m_release;

-- 商户可只读查看代理商向自己开具的收费单（写操作由服务层拦截）
INSERT IGNORE INTO sys_role_menu (role_id, menu_id) VALUES (@role_merchant, @m_merchantfee);
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_merchant, menu_id FROM sys_menu
WHERE parent_id = @m_merchantfee AND perms IN ('biz:merchantfee:query');

-- ----------------------------
-- 步骤7：小程序第三方平台参数（代发布用，平台级唯一，保存在 sys_config）
-- ----------------------------
-- 注意：sys_config 无 config_key 唯一索引，INSERT IGNORE 无法去重，
-- 重复执行会产生多份同 key 配置，故一律用 NOT EXISTS 条件插入。
-- 先清理历史脚本可能造成的重复项（保留 config_id 最小的一条）
DELETE c FROM sys_config c
  JOIN (SELECT config_key, MIN(config_id) AS keep_id FROM sys_config
        WHERE config_key LIKE 'wx.open.%' GROUP BY config_key) k
    ON k.config_key = c.config_key AND c.config_id > k.keep_id;

INSERT INTO sys_config (config_name, config_key, config_value, config_type, create_by, create_time, remark)
SELECT t.* FROM (
  SELECT '开放平台第三方AppId' AS a,   'wx.open.componentAppId' AS b,  '' AS c, 'N' AS d, 'admin' AS e, SYSDATE() AS f, '小程序代发布' AS g
  UNION ALL SELECT '开放平台第三方Secret',  'wx.open.componentSecret',  '', 'N', 'admin', SYSDATE(), '小程序代发布'
  UNION ALL SELECT '开放平台消息校验Token', 'wx.open.componentToken',   '', 'N', 'admin', SYSDATE(), '小程序代发布'
  UNION ALL SELECT '开放平台消息加密Key',   'wx.open.componentAesKey',  '', 'N', 'admin', SYSDATE(), '小程序代发布'
  UNION ALL SELECT '小程序代码模板ID',      'wx.open.templateId',       '', 'N', 'admin', SYSDATE(), '小程序代发布'
  UNION ALL SELECT '授权回调域名',          'wx.open.redirectDomain',   '', 'N', 'admin', SYSDATE(), '小程序代发布'
  UNION ALL SELECT '小程序接口域名',        'wx.open.apiBaseUrl',       '', 'N', 'admin', SYSDATE(), '生成ext.json时注入各商户小程序的后端接口地址'
) t
WHERE NOT EXISTS (SELECT 1 FROM (SELECT config_key FROM sys_config) x WHERE x.config_key = t.b);

-- ----------------------------
-- 验证
-- ----------------------------
SELECT p.menu_name AS 分组, c.order_num AS 排序, c.menu_name AS 菜单, c.perms AS 权限, c.component AS 组件
FROM sys_menu p JOIN sys_menu c ON c.parent_id = p.menu_id
WHERE p.menu_id = @dir_tenant ORDER BY c.order_num;

SELECT r.role_name AS 角色, r.role_key AS 标识, COUNT(rm.menu_id) AS 菜单数
FROM sys_role r LEFT JOIN sys_role_menu rm ON rm.role_id = r.role_id
WHERE r.role_key IN ('platform', 'agent', 'merchant') GROUP BY r.role_id, r.role_name, r.role_key;


-- ############################################################
-- 源文件：sql/biz_mpconfig_menu.sql
-- ############################################################

-- =============================================
-- 小程序平台配置菜单（微信开放平台第三方平台参数集中维护）
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_mpconfig_menu.sql
-- 说明：wx.open.* 参数原先只能在「系统参数」逐条改，改为独立页面维护
--       脚本可重复执行（幂等），菜单ID由自增分配，不硬编码，避免与代码生成器冲突
-- =============================================

-- ----------------------------
-- 步骤0：定位「团购运营」一级目录与「平台配置」二级目录（不存在则创建）
-- ----------------------------
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '团购运营', 0, 4, 'tuangou', '', '', '', 1, 0, 'M', '0', '0', '', 'shopping', 'admin', SYSDATE(), '洞天团购业务'
FROM (SELECT 1) t
WHERE NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE menu_name = '团购运营' AND parent_id = 0) x);

SET @biz_id = (SELECT menu_id FROM sys_menu WHERE menu_name = '团购运营' AND parent_id = 0 LIMIT 1);

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '平台配置', @biz_id, 5, 'setting', '', '', '', 1, 0, 'M', '0', '0', '', 'tool', 'admin', SYSDATE(), '微信小程序/支付等平台配置'
FROM (SELECT 1) t
WHERE NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE menu_name = '平台配置' AND parent_id = @biz_id) x);

SET @dir_setting = (SELECT menu_id FROM sys_menu WHERE menu_name = '平台配置' AND parent_id = @biz_id LIMIT 1);

-- ----------------------------
-- 步骤1：清理本脚本管理的菜单（按 component 定位，含其下按钮权限）
-- MySQL 不允许 DELETE 子查询直接引用目标表，先用临时表暂存菜单ID
-- ----------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_mpconfig_menu;
CREATE TEMPORARY TABLE tmp_mpconfig_menu (menu_id BIGINT(20) PRIMARY KEY);

INSERT INTO tmp_mpconfig_menu (menu_id)
SELECT menu_id FROM sys_menu WHERE component = 'biz/mpconfig/index';

DROP TEMPORARY TABLE IF EXISTS tmp_mpconfig_child;
CREATE TEMPORARY TABLE tmp_mpconfig_child (menu_id BIGINT(20) PRIMARY KEY);

INSERT IGNORE INTO tmp_mpconfig_child (menu_id)
SELECT m.menu_id FROM sys_menu m JOIN tmp_mpconfig_menu t ON m.parent_id = t.menu_id;

INSERT IGNORE INTO tmp_mpconfig_menu (menu_id)
SELECT menu_id FROM tmp_mpconfig_child;

DELETE rm FROM sys_role_menu rm JOIN tmp_mpconfig_menu t ON rm.menu_id = t.menu_id;
DELETE m FROM sys_menu m JOIN tmp_mpconfig_menu t ON m.menu_id = t.menu_id;

DROP TEMPORARY TABLE IF EXISTS tmp_mpconfig_child;
DROP TEMPORARY TABLE IF EXISTS tmp_mpconfig_menu;

-- ----------------------------
-- 步骤2：菜单与按钮权限
-- ----------------------------
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('小程序平台配置', @dir_setting, 2, 'mpconfig', 'biz/mpconfig/index', '', '', 1, 0, 'C', '0', '0', 'biz:mpconfig:query', 'wechat', 'admin', SYSDATE(), '开放平台第三方平台参数、代码模板与接口域名');
SET @m_mpconfig = LAST_INSERT_ID();

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark) VALUES
('平台配置查询', @m_mpconfig, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:mpconfig:query', '#', 'admin', SYSDATE(), ''),
('平台配置修改', @m_mpconfig, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:mpconfig:edit',  '#', 'admin', SYSDATE(), '');

-- ----------------------------
-- 步骤3：授权（超级管理员 + 平台管理员；代理商与商户不可见）
-- ----------------------------
SET @role_platform = (SELECT role_id FROM sys_role WHERE role_key = 'platform' LIMIT 1);

INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu WHERE menu_id = @m_mpconfig OR parent_id = @m_mpconfig;
INSERT IGNORE INTO sys_role_menu (role_id, menu_id) VALUES (1, @dir_setting);

INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_platform, menu_id FROM sys_menu
WHERE @role_platform IS NOT NULL AND (menu_id = @m_mpconfig OR parent_id = @m_mpconfig);
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_platform, @dir_setting FROM (SELECT 1) t WHERE @role_platform IS NOT NULL;

-- 「平台配置」目录下的既有「微信配置」页面同样归平台管理员（历史脚本只授到目录级）
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT @role_platform, m.menu_id FROM sys_menu m
WHERE @role_platform IS NOT NULL
  AND (m.component = 'biz/wxconfig/index'
       OR m.parent_id IN (SELECT menu_id FROM (SELECT menu_id FROM sys_menu WHERE component = 'biz/wxconfig/index') x));

-- 「微信配置」页面语义调整：改为平台默认商户的兜底凭证，多商户凭证在商户管理中维护
UPDATE sys_menu SET remark = '平台默认商户的小程序/支付兜底凭证，各商户凭证在「商户管理」中维护'
WHERE component = 'biz/wxconfig/index';

-- ----------------------------
-- 验证
-- ----------------------------
SELECT p.menu_name AS 分组, c.order_num AS 排序, c.menu_name AS 菜单, c.perms AS 权限, c.component AS 组件
FROM sys_menu p JOIN sys_menu c ON c.parent_id = p.menu_id
WHERE p.menu_id = @dir_setting ORDER BY c.order_num;

SELECT config_key AS 参数键, config_name AS 参数名, config_value AS 当前值
FROM sys_config WHERE config_key LIKE 'wx.open.%' ORDER BY config_id;


-- ############################################################
-- 源文件：sql/biz_wxconfig_menu.sql
-- ############################################################

-- 微信配置菜单（独立维护页面，挂在"团购运营" 2001 下）
-- 权限：biz:wxconfig:query / biz:wxconfig:edit
-- menu_id 使用 2105，避免冲突

-- 父菜单（页面本身）
delete from sys_menu where menu_id in (2105, 2106, 2107);
insert into sys_menu
  (menu_id, menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
values
  (2105, '微信配置', 2001, 7, 'wxconfig', 'biz/wxconfig/index', '', '', 1, 0, 'C', '0', '0', 'biz:wxconfig:query', 'wechat', 'admin', sysdate(), '小程序/支付配置（AppId、AppSecret、支付证书等）');
-- 按钮权限
insert into sys_menu
  (menu_id, menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
values
  (2106, '微信配置查询', 2105, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:wxconfig:query', '#', 'admin', sysdate(), '');
insert into sys_menu
  (menu_id, menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
values
  (2107, '微信配置修改', 2105, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'biz:wxconfig:edit', '#', 'admin', sysdate(), '');

-- 授予超级管理员（role_id=1）
delete from sys_role_menu where menu_id in (2105, 2106, 2107);
insert into sys_role_menu (role_id, menu_id) values (1, 2105);
insert into sys_role_menu (role_id, menu_id) values (1, 2106);
insert into sys_role_menu (role_id, menu_id) values (1, 2107);


-- ############################################################
-- 源文件：sql/biz_wxconfig_init.sql
-- ############################################################

-- 微信配置初始值（首次部署时执行，菜单及已有值会跳过）
-- 行为：INSERT IGNORE，已存在则不覆盖（管理员后续在后台改）

-- 前置（2026-08-22 修）：RuoYi 原生 sys_config 的 config_key 上**没有唯一索引**，
-- 所以下面的 INSERT IGNORE 形同虚设 —— biz_tenant_upgrade.sql 和本脚本会各插一份
-- wx.miniapp.appId / wx.miniapp.secret，重复后
-- `(select config_value from sys_config where config_key='wx.miniapp.appId')`
-- 这类子查询会报 ERROR 1242 Subquery returns more than 1 row。
-- 这里先去重（保留最小 config_id），再补唯一索引，让 INSERT IGNORE 真正生效。
DELETE c1 FROM sys_config c1
JOIN (
  SELECT config_key, MIN(config_id) AS keep_id
  FROM sys_config GROUP BY config_key HAVING COUNT(*) > 1
) d ON c1.config_key = d.config_key AND c1.config_id <> d.keep_id;

SET @sql := (
  SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.statistics
           WHERE table_schema = DATABASE() AND table_name = 'sys_config'
             AND index_name = 'uk_sys_config_key'),
    'SELECT ''uk_sys_config_key already exists'' AS msg',
    'ALTER TABLE sys_config ADD UNIQUE KEY uk_sys_config_key (config_key)'
  )
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

insert ignore into sys_config (config_name, config_key, config_value, config_type, create_by, create_time, remark)
values
('小程序AppId',           'wx.miniapp.appId',         'wx08075ce2ff0d153e',           'N', 'admin', sysdate(), '微信配置'),
('小程序AppSecret',        'wx.miniapp.secret',        'c7a8bc9b02bfe0e3a56236961c8fd4da', 'N', 'admin', sysdate(), '微信配置'),
('小程序mock登录开关',     'wx.miniapp.mockEnabled',   'false',                         'N', 'admin', sysdate(), '微信配置'),
('微信支付商户号',         'wx.pay.mchId',             '',                              'N', 'admin', sysdate(), '微信配置'),
('微信支付AppId',          'wx.pay.appId',             '',                              'N', 'admin', sysdate(), '微信配置'),
('微信支付证书序列号',     'wx.pay.certSerialNo',      '',                              'N', 'admin', sysdate(), '微信配置'),
('微信支付私钥路径',       'wx.pay.privateKeyPath',    '',                              'N', 'admin', sysdate(), '微信配置'),
('微信支付APIv3密钥',      'wx.pay.apiV3Key',          '',                              'N', 'admin', sysdate(), '微信配置'),
('微信支付回调地址',       'wx.pay.notifyUrl',         'https://your-domain.com/api/pay/notify', 'N', 'admin', sysdate(), '微信配置'),
('微信支付mock开关',       'wx.pay.mockEnabled',       'false',                          'N', 'admin', sysdate(), '微信配置');


-- ############################################################
-- 源文件：sql/biz_banner.sql
-- ############################################################

-- ----------------------------
-- 首页轮播图 biz_banner
-- ----------------------------
DROP TABLE IF EXISTS biz_banner;
CREATE TABLE biz_banner (
  banner_id     BIGINT(20)      NOT NULL AUTO_INCREMENT         COMMENT 'Banner ID',
  merchant_id   BIGINT(20)      NOT NULL DEFAULT 0              COMMENT '商户ID（0=全平台）',
  title         VARCHAR(100)    DEFAULT ''                      COMMENT '标题',
  image_url     VARCHAR(500)    NOT NULL                        COMMENT '图片URL',
  link_url      VARCHAR(500)    DEFAULT NULL                    COMMENT '跳转链接',
  position      VARCHAR(32)     NOT NULL DEFAULT 'home'         COMMENT '位置（home/agent/distributor）',
  status        CHAR(1)         NOT NULL DEFAULT '0'            COMMENT '状态（0启用 1停用）',
  sort          INT(4)          NOT NULL DEFAULT 0              COMMENT '显示顺序',
  active_from   DATETIME        DEFAULT NULL                    COMMENT '生效时间',
  active_to     DATETIME        DEFAULT NULL                    COMMENT '失效时间',
  create_by     VARCHAR(64)     DEFAULT ''                      COMMENT '创建者',
  create_time   DATETIME        DEFAULT NULL                    COMMENT '创建时间',
  update_by     VARCHAR(64)     DEFAULT ''                      COMMENT '更新者',
  update_time   DATETIME        DEFAULT NULL                    COMMENT '更新时间',
  PRIMARY KEY (banner_id),
  KEY idx_merchant (merchant_id),
  KEY idx_position (position, status, sort)
) ENGINE=InnODB COMMENT = '首页轮播图';

-- 菜单 + 权限
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
-- 注（2026-08-22）：原来父菜单写死找 '商城管理'，该菜单在本项目并不存在 → parent_id 落 NULL，
-- 而 SysMenu.getParentId() 被 getRouters 直接 longValue() → 整个后台侧边栏 500。
-- 改为优先挂「门店商品」，取不到则落 0（顶级），用 IFNULL 兜死，绝不写 NULL。
VALUES ('首页轮播图', IFNULL((SELECT menu_id FROM (SELECT menu_id FROM sys_menu WHERE menu_name IN ('门店商品','商城管理') AND menu_type='M' ORDER BY FIELD(menu_name,'门店商品','商城管理') LIMIT 1) t), 0), 6, 'banner', 'biz/banner/index', 1, 0, 'C', '0', '0', 'biz:banner:list', 'picture', 'admin', NOW(), '首页轮播图管理')
ON DUPLICATE KEY UPDATE perms = VALUES(perms);

SET @pid = LAST_INSERT_ID();
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT m.menu_id, m.menu_id, 1, '', '', 1, 0, 'F', '0', '0', 'biz:banner:query',  '#', 'admin', NOW(), '查询' FROM sys_menu m WHERE m.menu_name='首页轮播图' LIMIT 1
ON DUPLICATE KEY UPDATE perms=VALUES(perms);


-- ############################################################
-- 源文件：sql/biz_commission_settle_job.sql
-- ############################################################

-- ----------------------------
-- 佣金冷静期自动结算定时任务
-- ----------------------------
-- 默认：每天 03:00 执行 settleCommissionTask.ryNoParams()，冷静期 7 天
INSERT INTO sys_job (job_name, job_group, invoke_target, cron_expression, misfire_policy, concurrent, status, create_by, create_time, remark)
SELECT 'settle_commission_task', 'DEFAULT', 'settleCommissionTask.ryNoParams()', '0 0 3 * * ?', '3', '1', '0', 'admin', NOW(), '佣金冷静期自动结算（待 review：需补 frozenAmount/availableAmount 联动）'
WHERE NOT EXISTS (SELECT 1 FROM sys_job WHERE job_name='settle_commission_task');


-- ############################################################
-- 源文件：sql/biz_commission_settle_link.sql
-- ############################################################

-- 佣金冷静期结算后联动推客冻结/可用金额：biz_commission 加 settled_to_distributor 标记
-- 工作流程：
--   1) Quartz 每天 03:00 跑 SettleCommissionTask
--   2) Phase 1：UPDATE biz_commission SET status=1, settle_time=NOW(), settled_to_distributor=0
--      WHERE status=0 AND create_time + 7d <= NOW()  (commissionMapper.settleExpiredCommissions)
--   3) Phase 2：SELECT distributor_id, SUM(amount) FROM biz_commission
--      WHERE settle_time = ? AND settled_to_distributor=0 GROUP BY distributor_id
--   4) Phase 3：逐 distributor UPDATE frozen_amount -X, available_amount +X
--   5) Phase 4：UPDATE biz_commission SET settled_to_distributor=1 WHERE settle_time = ?

SET @sql_add = (
  SELECT IF(
    EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_commission' AND COLUMN_NAME = 'settled_to_distributor'),
    'SELECT 1',
    'ALTER TABLE biz_commission ADD COLUMN settled_to_distributor TINYINT(1) DEFAULT 0 COMMENT ''已联动推客金额（0否 1是）'' AFTER settle_time'
  )
);
PREPARE stmt FROM @sql_add; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql_idx = (
  SELECT IF(
    EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'biz_commission' AND INDEX_NAME = 'idx_settle_link'),
    'SELECT 1',
    'CREATE INDEX idx_settle_link ON biz_commission (settle_time, settled_to_distributor)'
  )
);
PREPARE stmt FROM @sql_idx; EXECUTE stmt; DEALLOCATE PREPARE stmt;


-- ############################################################
-- 源文件：sql/biz_phone_decrypt.sql
-- ############################################################

-- 手机号解密权限（仅平台 / 客服角色可授）
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '手机号解密', m.menu_id, 5, '#', '', 1, 0, 'F', '0', '0', 'biz:phone:decrypt', '#', 'admin', NOW(), '查看完整手机号（脱敏反操作）'
FROM sys_menu m WHERE m.menu_name = '会员管理' AND m.menu_type = 'M' LIMIT 1;

-- 授权给超管 + 客服（角色 ID 1 = 超级管理员，2 = 普通角色，按实际调整）
INSERT INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu WHERE perms = 'biz:phone:decrypt';


-- ############################################################
-- 源文件：sql/biz_order_verify_bill_confirm.sql
-- ############################################################

-- ============================================================
-- 核销 / 买单确认：菜单权限插入
--   - biz:order:verify  订单核销（后台 web 端）
--   - biz:bill:confirm   买单确认（后台 web 端）
-- ============================================================

-- 1) 订单核销按钮（挂在「订单管理」菜单下）
SET @order_parent = (SELECT menu_id FROM sys_menu WHERE perms = 'biz:order:list' LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '订单核销', @order_parent, 6, '#', '', 1, 0, 'F', '0', '0', 'biz:order:verify', '#', 'admin', NOW(), '订单核销（后台 web 端）'
FROM DUAL
WHERE @order_parent IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:order:verify');

-- 2) 买单确认按钮
SET @bill_parent = (SELECT menu_id FROM sys_menu WHERE perms = 'biz:bill:list' LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单确认', @bill_parent, 6, '#', '', 1, 0, 'F', '0', '0', 'biz:bill:confirm', '#', 'admin', NOW(), '买单确认（后台 web 端）'
FROM DUAL
WHERE @bill_parent IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:bill:confirm');

-- 3) 把新权限授权给 admin + common 角色（默认全开）
INSERT INTO sys_role_menu (role_id, menu_id)
SELECT r.role_id, m.menu_id
FROM sys_role r, sys_menu m
WHERE r.role_key IN ('admin','common')
  AND m.perms IN ('biz:order:verify','biz:bill:confirm')
  AND NOT EXISTS (
    SELECT 1 FROM sys_role_menu rm
    WHERE rm.role_id = r.role_id AND rm.menu_id = m.menu_id
  );

-- 4) 自检
SELECT m.menu_id, m.menu_name, m.perms FROM sys_menu m WHERE m.perms IN ('biz:order:verify','biz:bill:confirm');


-- ############################################################
-- 源文件：sql/biz_order_verifycode_fix.sql
-- ############################################################

-- =============================================
-- 修复：biz_order.verify_code 默认空串与唯一索引冲突
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_order_verifycode_fix.sql
-- 现象：核销码在支付成功后才生成，未支付订单该列为 ''，
--       而 uk_verify_code 是唯一索引，导致同商户第二笔未支付订单必然
--       报 Duplicate entry '' for key 'uk_verify_code' 而无法下单。
-- 方案：列改为可空且默认 NULL（MySQL 唯一索引允许多个 NULL），并把存量空串刷成 NULL。
-- 幂等：可重复执行。
-- =============================================

UPDATE biz_order SET verify_code = NULL WHERE verify_code = '';

ALTER TABLE biz_order
  MODIFY COLUMN verify_code VARCHAR(32) DEFAULT NULL COMMENT '核销码（支付后生成，未支付为NULL以避开唯一索引）';

-- 验证：应为 0 行空串
SELECT COUNT(*) AS 空串核销码 FROM biz_order WHERE verify_code = '';


-- ############################################################
-- 源文件：sql/biz_agent_commission_c1.sql
-- ############################################################

-- ============================================================
-- C1 代理商佣金概览（admin 端）权限 + 菜单
-- 2026-08-14
-- ============================================================
-- 菜单（hidden=true，只是个权限载体，admin 端不显示菜单项，/agent/index 容器内调用）
INSERT IGNORE INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('代理商佣金概览', 0, 5, 'agentCommission', NULL, 1, 0, 'F', '0', '0', 'biz:agent:commission:summary', 'money', 'admin', NOW(), '代理商工作台佣金概览（admin 端）');

-- 绑定 admin 角色（role_id=1）
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu WHERE perms='biz:agent:commission:summary' AND menu_id NOT IN (SELECT menu_id FROM sys_role_menu WHERE role_id=1);


-- ############################################################
-- 源文件：sql/biz_booking_member_menu.sql
-- ############################################################

-- 预约明细列表菜单（挂在“团购运营”目录 2001 下，复用 biz:booking 权限）
-- menu_id 使用 2104，避免与现有 biz 菜单冲突

delete from sys_menu where menu_id = 2104;
insert into sys_menu
  (menu_id, menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
values
  (2104, '预约明细', 2001, 6, 'bookingmember', 'biz/bookingmember/index', '', '', 1, 0, 'C', '0', '0', 'biz:booking:list', 'form', 'admin', sysdate(), '预约报名明细列表');

-- 授予超级管理员角色（role_id=1）
delete from sys_role_menu where menu_id = 2104;
insert into sys_role_menu (role_id, menu_id) values (1, 2104);


-- ############################################################
-- 源文件：sql/v2_admin_menus.sql
-- ############################################################

-- ============================================
-- v2 admin 菜单（idempotent）
-- 路径：团购运营 / 商品类型 / 子品管理
-- 已含：staffInvite 菜单（之前单独跑过）
-- ============================================

-- 1) 商品类型字典菜单（parent=2108 商品顶级菜单）
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品类型', 2108, 5, 'productType', 'biz/productType/index', 1, 0, 'C', '0', '0', 'biz:productType:list', 'dict', 'admin', SYSDATE(), '商品类型字典管理（11 种类型）'
FROM (SELECT 1) t
WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE component = 'biz/productType/index');

-- 2) 5 个按钮权限（query / add / edit / remove / export）
SET @m = (SELECT menu_id FROM sys_menu WHERE component = 'biz/productType/index' LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品类型查询', @m, 1, '', '', 1, 0, 'F', '0', '0', 'biz:productType:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:productType:query');
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品类型新增', @m, 2, '', '', 1, 0, 'F', '0', '0', 'biz:productType:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:productType:add');
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品类型修改', @m, 3, '', '', 1, 0, 'F', '0', '0', 'biz:productType:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:productType:edit');
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品类型删除', @m, 4, '', '', 1, 0, 'F', '0', '0', 'biz:productType:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:productType:remove');
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品类型导出', @m, 5, '', '', 1, 0, 'F', '0', '0', 'biz:productType:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:productType:export');

-- 3) 角色授权（admin 1 角色）
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu
WHERE component = 'biz/productType/index' OR perms IN ('biz:productType:query','biz:productType:add','biz:productType:edit','biz:productType:remove','biz:productType:export');

-- 4) 子品管理菜单（parent=2108）
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '子品管理', 2108, 6, 'productSubitem', 'biz/productSubitem/index', 1, 0, 'C', '0', '0', 'biz:productSubitem:list', 'tree', 'admin', SYSDATE(), '商品子品组 + 子品管理'
FROM (SELECT 1) t
WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE component = 'biz/productSubitem/index');

-- 5) 子品管理按钮权限
SET @m2 = (SELECT menu_id FROM sys_menu WHERE component = 'biz/productSubitem/index' LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '子品查询', @m2, 1, '', '', 1, 0, 'F', '0', '0', 'biz:productSubitem:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m2 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:productSubitem:query');
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '子品新增', @m2, 2, '', '', 1, 0, 'F', '0', '0', 'biz:productSubitem:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m2 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:productSubitem:add');
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '子品修改', @m2, 3, '', '', 1, 0, 'F', '0', '0', 'biz:productSubitem:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m2 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:productSubitem:edit');
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '子品删除', @m2, 4, '', '', 1, 0, 'F', '0', '0', 'biz:productSubitem:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @m2 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms = 'biz:productSubitem:remove');

-- 6) 子品管理授权
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu
WHERE component = 'biz/productSubitem/index' OR perms LIKE 'biz:productSubitem:%';

-- 7) 验证
SELECT menu_id, menu_name, perms, path FROM sys_menu
WHERE component IN ('biz/productType/index','biz/productSubitem/index')
   OR perms LIKE 'biz:productType:%'
   OR perms LIKE 'biz:productSubitem:%'
ORDER BY menu_id;


-- ############################################################
-- 源文件：sql/v3_p2_menus_routes.sql
-- ############################################################

-- =====================================================================
-- v3 P2-3: 菜单/权限 SQL 收口
-- - 修复 2265 员工管理 parent_id=NULL 导致 getRouters NPE 的问题
-- - 挂到 tenant 2215 下面（员工管理是通用能力，平台/代理商/商户都可见）
-- - 校验 productType / productSubitem 父链 2108 商品管理
-- - 给 admin 角色补全 3 个新菜单的绑定（防止遗漏）
-- =====================================================================

-- 1) 修 2265 parent_id（NULL → 2215 tenant）
UPDATE sys_menu SET parent_id = 2215 WHERE menu_id = 2265 AND parent_id IS NULL;

-- 2) 校验 2270 / 2276 父链是 2108 商品管理（防止改父）
-- 已是 2108，跳过（仅留 assertion）

-- 3) 给 admin 角色（role_id=1）补全 productType / productSubitem / staffInvite 3 个菜单的权限
INSERT IGNORE INTO sys_role_menu (role_id, menu_id) SELECT 1, menu_id FROM sys_menu WHERE menu_id IN (2265, 2270, 2276, 2266, 2267, 2268, 2269, 2271, 2272, 2273, 2274, 2275, 2277, 2278, 2279, 2280);

-- 4) 校验 admin 角色 menu 数量
-- SELECT COUNT(*) FROM sys_role_menu WHERE role_id=1;  -- 应为 64 + 16 = 80


-- ############################################################
-- 源文件：sql/migration-2026-08-14-f2-mpauth-menu.sql
-- ############################################################

-- F2 补 v2 新增 controller 的 sys_menu 记录 (mpauth) + agent 角色加 banner/mpauth perms
-- 现象: Banner agent 返 403 没有权限, MpAuth agent 返 403 (sys_menu 缺记录)
-- 根因: Banner v2 升级时漏给 agent 角色加 menu_id 2259/2260; MpAuth 是 v2 新增, sys_menu 完全没注册
-- 修法:
--   1. sys_role_menu: role_id=4 (agent) 加 banner (2259/2260)
--   2. sys_menu: 新增 2290 (mpauth 菜单) + 2291 (mpauth:query 按钮)
--   3. sys_role_menu: role_id=4 加 mpauth (2290/2291)
-- 验证: E16 Banner 3/3 PASS + E17 MpAuth 3/3 PASS (agent 别人 500 / 自己 200 / admin 200)
-- 注（2026-08-21）：原本这里是 `USE ry-vue;`。
-- `use` 是 mysql 客户端指令，会无视命令行上指定的库直接切到 ry-vue，
-- 导致「对着测试库执行、却写进生产库」。库名请在命令行给：
--   mysql --default-character-set=utf8mb4 -uroot -p <目标库> < 本文件
-- USE ry-vue;
-- 1. agent 角色加 banner
INSERT IGNORE INTO sys_role_menu (role_id, menu_id) VALUES (4, 2259), (4, 2260);
-- 2. sys_menu 新增 mpauth (parent_id=0 顶级)
INSERT IGNORE INTO sys_menu (menu_id, menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark) VALUES
  (2290, '小程序授权', 0, 99, 'mpauth', 'biz/mpauth/index', 1, 0, 'C', '0', '0', 'biz:mpauth:list',  '#', 'admin', NOW(), 'mpauth 菜单 (v2 新增)'),
  (2291, '小程序授权查询', 2290, 1, '#', '', 1, 0, 'F', '0', '0', 'biz:mpauth:query', '#', 'admin', NOW(), 'mpauth 详情 (v2 新增)');
-- 3. agent 角色加 mpauth
INSERT IGNORE INTO sys_role_menu (role_id, menu_id) VALUES (4, 2290), (4, 2291);


-- ############################################################
-- 源文件：sql/biz_menu_business_pages.sql
-- ############################################################

-- ============================================================
-- 补齐 19 个业务菜单页 + 按钮权限（2026-08-22）
--
-- 背景：这 19 个业务菜单最初由 RuoYi 代码生成器直接写进开发库，
--       建表 SQL 从未入仓。sql/biz_menu_reorganization.sql 只做「重新分组」
--       （把已存在的菜单移到 5 个分组下），并不创建它们。
--       → 全新库跑完 init-all.sh 后，后台只有 14 个业务菜单，
--         订单/会员/商品/门店/推客/佣金等 18 个页面在侧边栏根本不出现。
--
-- 幂等：全部按 perms / menu_name 判断存在性，可重复执行
-- 注意：菜单 ID 由自增分配，父子关系一律按「菜单名」查找，不硬编码 ID
--       （本地库 2108=门店商品，脚本库 2108=首页轮播图，硬编码必错）
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p <库名> < sql/biz_menu_business_pages.sql
-- ============================================================

-- 0) 分组目录（门店商品/交易订单/会员体系/推客分销/平台配置）由
--    sql/biz_menu_reorganization.sql 创建，本脚本必须在它之后执行，
--    这里只按名字查找、绝不自建，否则会出现两套同名分组。

-- 1) 18 个业务菜单页（C 型）

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='商品管理' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品创建', @pid, 1, 'create', 'biz/product/create', NULL, '', 1, 0, 'C', '0', '0', 'biz:product:add', '#', 'admin', SYSDATE(), '商品创建路由（抖音来客风格）'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:add' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='商品管理' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品详情', @pid, 2, 'detail/:productId(d+)', 'biz/product/detail', NULL, '', 1, 0, 'C', '1', '0', 'biz:product:query', '#', 'admin', SYSDATE(), '商品详情路由'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:query' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='门店商品' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店管理', @pid, 1, 'store', 'biz/store/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:store:list', 'shopping', 'admin', SYSDATE(), '门店菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:store:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='门店商品' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品分类', @pid, 2, 'category', 'biz/category/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:category:list', 'list', 'admin', SYSDATE(), '商品分类菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:category:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='门店商品' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品管理', @pid, 3, 'product', 'biz/product/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:product:list', 'goods', 'admin', SYSDATE(), '商品菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='门店商品' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '相册管理', @pid, 4, 'album', 'biz/album/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:album:list', 'image', 'admin', SYSDATE(), '门店相册菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:album:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='门店商品' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '协议管理', @pid, 5, 'agreement', 'biz/agreement/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:agreement:list', 'documentation', 'admin', SYSDATE(), '协议菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='交易订单' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '团购订单', @pid, 1, 'order', 'biz/order/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:order:list', 'form', 'admin', SYSDATE(), '订单菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:order:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='交易订单' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单记录', @pid, 2, 'bill', 'biz/bill/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:bill:list', 'money', 'admin', SYSDATE(), '买单流水菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='会员体系' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员管理', @pid, 1, 'member', 'biz/member/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:member:list', 'peoples', 'admin', SYSDATE(), '会员菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:member:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='会员体系' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员用户', @pid, 2, 'user', 'biz/user/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:user:list', 'tree', 'admin', SYSDATE(), '账号门店关联菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:user:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='会员体系' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '代金券管理', @pid, 3, 'voucher', 'biz/voucher/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:voucher:list', 'star', 'admin', SYSDATE(), '代金券模板菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='会员体系' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员账户', @pid, 4, 'account', 'biz/account/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:account:list', 'validCode', 'admin', SYSDATE(), '分账接收方菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:account:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='推客分销' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '推客管理', @pid, 1, 'distributor', 'biz/distributor/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:distributor:list', 'user', 'admin', SYSDATE(), '推客菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='推客分销' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金规则', @pid, 2, 'rule', 'biz/rule/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:rule:list', 'edit', 'admin', SYSDATE(), '佣金规则菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='推客分销' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金记录', @pid, 3, 'commission', 'biz/commission/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:commission:list', 'money', 'admin', SYSDATE(), '佣金明细菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='推客分销' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '提现申请', @pid, 4, 'withdraw', 'biz/withdraw/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:withdraw:list', 'money', 'admin', SYSDATE(), '提现记录菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:list' AND menu_type='C') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE menu_name='推客分销' AND menu_type='M' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '提现记录', @pid, 5, 'record', 'biz/record/index', NULL, '', 1, 0, 'C', '0', '0', 'biz:record:list', 'documentation', 'admin', SYSDATE(), '分账明细菜单'
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:record:list' AND menu_type='C') x);

-- 2) 按钮权限（F 型），父菜单按 perms 定位

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:account:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账接收方查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:account:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:account:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:account:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账接收方新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:account:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:account:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:account:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账接收方修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:account:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:account:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:account:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账接收方删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:account:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:account:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:account:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账接收方导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:account:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:account:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '协议查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:agreement:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '协议新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:agreement:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '协议修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:agreement:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '协议删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:agreement:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '协议导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:agreement:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:agreement:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:album:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店相册查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:album:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:album:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:album:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店相册新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:album:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:album:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:album:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店相册修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:album:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:album:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:album:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店相册删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:album:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:album:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:album:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店相册导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:album:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:album:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单流水查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:bill:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单流水新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:bill:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单流水修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:bill:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单流水删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:bill:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单流水导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:bill:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '买单确认', @pid, 6, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:bill:confirm', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:bill:confirm') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:category:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品分类查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:category:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:category:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:category:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品分类新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:category:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:category:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:category:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品分类修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:category:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:category:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:category:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品分类删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:category:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:category:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:category:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品分类导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:category:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:category:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金明细查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:commission:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金明细新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:commission:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金明细修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:commission:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金明细删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:commission:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金明细导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:commission:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:commission:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '推客查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:distributor:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '推客新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:distributor:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '推客修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:distributor:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '推客删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:distributor:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '推客导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:distributor:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:distributor:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:member:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:member:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:member:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:member:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:member:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:member:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:member:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:member:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:member:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:member:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:member:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:member:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:member:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '会员导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:member:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:member:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:order:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '订单查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:order:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:order:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:order:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '订单新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:order:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:order:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:order:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '订单修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:order:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:order:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:order:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '订单删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:order:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:order:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:order:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '订单导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:order:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:order:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:order:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '订单核销', @pid, 6, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:order:verify', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:order:verify') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:product:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:product:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:product:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:product:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:product:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:product:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:product:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:product:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:product:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '商品导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:product:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:product:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:record:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账明细查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:record:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:record:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:record:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账明细新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:record:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:record:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:record:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账明细修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:record:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:record:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:record:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账明细删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:record:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:record:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:record:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '分账明细导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:record:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:record:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金规则查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:rule:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金规则新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:rule:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金规则修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:rule:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金规则删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:rule:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '佣金规则导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:rule:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:rule:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:store:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:store:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:store:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:store:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:store:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:store:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:store:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:store:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:store:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:store:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:store:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:store:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:store:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '门店导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:store:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:store:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:user:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '账号门店关联查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:user:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:user:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:user:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '账号门店关联新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:user:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:user:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:user:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '账号门店关联修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:user:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:user:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:user:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '账号门店关联删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:user:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:user:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:user:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '账号门店关联导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:user:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:user:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '代金券模板查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:voucher:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '代金券模板新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:voucher:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '代金券模板修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:voucher:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '代金券模板删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:voucher:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '代金券模板导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:voucher:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:voucher:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '提现记录查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:withdraw:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:query') x);


-- ============================================================
-- 5) 延后建的按钮：biz:booking:* / biz:withdraw:* 的父菜单由本文件之后的
--    脚本创建（预约明细 / 提现申请），必须放在角色绑定之后再挂，否则 @pid 为空。
-- ============================================================
SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '在线预约查询', @pid, 1, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:booking:query', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:query') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '在线预约新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:booking:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '在线预约修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:booking:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '在线预约删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:booking:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '在线预约导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:booking:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:booking:export') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '提现记录新增', @pid, 2, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:withdraw:add', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:add') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '提现记录修改', @pid, 3, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:withdraw:edit', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:edit') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '提现记录删除', @pid, 4, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:withdraw:remove', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:remove') x);

SET @pid = (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:list' AND menu_type='C' ORDER BY menu_id LIMIT 1);
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, query, route_name, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT '提现记录导出', @pid, 5, '', '', NULL, '', 1, 0, 'F', '0', '0', 'biz:withdraw:export', '#', 'admin', SYSDATE(), ''
FROM (SELECT 1) t WHERE @pid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM (SELECT menu_id FROM sys_menu WHERE perms='biz:withdraw:export') x);

-- ============================================================
-- 4) 角色绑定：把业务菜单授予 admin(role_id=1) 与平台角色(role_id=3)
--    不绑的话菜单建了也不会出现在侧边栏（RuoYi 按 sys_role_menu 过滤）
-- ============================================================
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu WHERE perms LIKE 'biz:%';

INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu WHERE menu_type='M'
  AND menu_name IN ('团购运营','门店商品','交易订单','会员体系','推客分销','平台配置');

INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 3, menu_id FROM sys_menu
WHERE (perms LIKE 'biz:%'
       OR (menu_type='M' AND menu_name IN ('团购运营','门店商品','交易订单','会员体系','推客分销','平台配置')))
  AND EXISTS (SELECT 1 FROM sys_role WHERE role_id=3);

-- 补绑这些按钮到角色
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id FROM sys_menu WHERE perms IN
  ('biz:booking:query','biz:booking:add','biz:booking:edit','biz:booking:remove','biz:booking:export',
   'biz:withdraw:add','biz:withdraw:edit','biz:withdraw:remove','biz:withdraw:export');
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 3, menu_id FROM sys_menu WHERE perms IN
  ('biz:booking:query','biz:booking:add','biz:booking:edit','biz:booking:remove','biz:booking:export',
   'biz:withdraw:add','biz:withdraw:edit','biz:withdraw:remove','biz:withdraw:export')
  AND EXISTS (SELECT 1 FROM sys_role WHERE role_id=3);

-- ============================================================
-- 6) 兜底：sys_menu.parent_id 绝不允许 NULL
--    SysMenu.getParentId() 被 SysMenuServiceImpl 直接 longValue()，
--    任何一行 parent_id IS NULL 都会让 GET /getRouters 抛 500，
--    表现为「登录成功但后台侧边栏全空」。
--    历史上 biz_banner.sql（找不存在的「商城管理」）和 biz_merchant_v2.sql
--    （要求门店商品挂在团购运营下）都踩过，这里统一收敛为顶级 0。
-- ============================================================
UPDATE sys_menu SET parent_id = 0 WHERE parent_id IS NULL;

-- 6.1) 上面兜底会把这两个菜单变成「顶级但无分组标题」（侧边栏出现无名分组）。
--      归位：员工管理 → 门店商品；小程序授权 → 平台配置。
--      注：MySQL 不允许 UPDATE 的子查询引用同一张表（ERROR 1093），先用变量取出。
SET @goods_pid = (SELECT menu_id FROM sys_menu WHERE menu_name='门店商品' AND menu_type='M' ORDER BY menu_id LIMIT 1);
UPDATE sys_menu SET parent_id = @goods_pid
WHERE perms = 'biz:staffInvite:list' AND menu_type='C' AND parent_id = 0 AND @goods_pid IS NOT NULL;

SET @conf_pid = (SELECT menu_id FROM sys_menu WHERE menu_name='平台配置' AND menu_type='M' ORDER BY menu_id LIMIT 1);
UPDATE sys_menu SET parent_id = @conf_pid
WHERE perms = 'biz:mpauth:list' AND menu_type='C' AND parent_id = 0 AND @conf_pid IS NOT NULL;


-- ############################################################
-- 源文件：sql/biz_product_dict_charset_fix.sql
-- ############################################################

-- ============================================
-- 修复 biz_product_type 字典 typeName/typeDesc 字符集乱码
-- 原因：v2 升级时执行 biz_product_seed.sql 未指定 utf8mb4 连接
--       导致 typeName/typeDesc 中文字段被双重 UTF-8 编码
-- 解决：用 SET NAMES utf8mb4 连接，直接覆盖为正确中文
-- 兼容性：可重复执行（WHERE type_code 唯一索引）
-- ============================================
SET NAMES utf8mb4;

UPDATE biz_product_type SET type_name = '团购套餐' WHERE type_code='GROUPON';
UPDATE biz_product_type SET type_name = '代金券'   WHERE type_code='VOUCHER';
UPDATE biz_product_type SET type_name = '次卡'     WHERE type_code='TIMECARD';
UPDATE biz_product_type SET type_name = '储值卡'   WHERE type_code='STORED_CARD';
UPDATE biz_product_type SET type_name = '周期卡'   WHERE type_code='PERIOD_CARD';
UPDATE biz_product_type SET type_name = '惠享卡'   WHERE type_code='HUIXIANG_CARD';
UPDATE biz_product_type SET type_name = '预售券'   WHERE type_code='PRESALE';
UPDATE biz_product_type SET type_name = '提货券'   WHERE type_code='PICKUP_VOUCHER';
UPDATE biz_product_type SET type_name = '组合券包' WHERE type_code='COMBO';
UPDATE biz_product_type SET type_name = '到店买单' WHERE type_code='BILL';
UPDATE biz_product_type SET type_name = '预约服务' WHERE type_code='BOOKING';

UPDATE biz_product_type SET type_desc = '套餐商品，搭配自由，快速吸引顾客' WHERE type_code='GROUPON';
UPDATE biz_product_type SET type_desc = '现金抵扣券，出单快，便于引流增收' WHERE type_code='VOUCHER';
UPDATE biz_product_type SET type_desc = '一次购买分次核销，增加用户粘性'   WHERE type_code='TIMECARD';
UPDATE biz_product_type SET type_desc = '通过存储金额，引导顾客多次到店消费' WHERE type_code='STORED_CARD';
UPDATE biz_product_type SET type_desc = '月/季/年卡等长周期商品，方便锁客'   WHERE type_code='PERIOD_CARD';
UPDATE biz_product_type SET type_desc = '大额分次核销，提前锁客' WHERE type_code='HUIXIANG_CARD';
UPDATE biz_product_type SET type_desc = '先买后约，方便用户直播及短视频囤货' WHERE type_code='PRESALE';
UPDATE biz_product_type SET type_desc = '支持多规格管理和门店库存设置'       WHERE type_code='PICKUP_VOUCHER';
UPDATE biz_product_type SET type_desc = '团购、代金券、实物自由组合，一次购买分次核销' WHERE type_code='COMBO';
UPDATE biz_product_type SET type_desc = '顾客自助输入金额付款（当前 product_type=1）' WHERE type_code='BILL';
UPDATE biz_product_type SET type_desc = '预约类商品（当前 product_type=2）' WHERE type_code='BOOKING';


-- ############################################################
-- 源文件：sql/biz_product_industry_sync_safe.sql
-- ############################################################

-- ============================================================
-- biz_product.industry_code 同步脚本 (MySQL 5.7 兼容版)
-- ============================================================
-- 背景: 原 sql/biz_product_seed.sql 第 9 步用 `UPDATE ... JOIN` 语法
--       MySQL 5.7.10 不支持 (需 8.0.19+) → 同步失败 → 8 行 product 的
--       industry_code 仍为空，违反 P1 字典化质量要求。
--
-- 产品级标准:
--   1. 幂等可重跑 (基于 WHERE 条件 + 游标替代 JOIN)
--   2. 字符集正确 (SET NAMES utf8mb4 + connection charset)
--   3. 安全默认值 (找不到映射时用 'OTHER' 而非 NULL)
--   4. 业务断言 (R1 行数检查，便于 CI 集成)
--
-- 依赖: 已存在 biz_product + biz_product_category 表
--       biz_product_category.industry_code 已有值 (CATERING/DINING/...)
-- 用法: mysql -h127.0.0.1 -uroot -p133301 ry-vue < biz_product_industry_sync_safe.sql
-- ============================================================

SET NAMES utf8mb4;
SET @db := DATABASE();

-- 1) 临时映射表：从 biz_product_category 提取 (category_id-10000 → industry_code) 映射
DROP TEMPORARY TABLE IF EXISTS tmp_cat_industry;
CREATE TEMPORARY TABLE tmp_cat_industry (
    legacy_category_id INT PRIMARY KEY,
    industry_code      VARCHAR(50) NOT NULL
) ENGINE=Memory;

INSERT INTO tmp_cat_industry (legacy_category_id, industry_code)
SELECT category_id - 10000, industry_code
FROM biz_product_category
WHERE category_id BETWEEN 10000 AND 19999
  AND industry_code IS NOT NULL
  AND industry_code <> '';

-- 2) 游标式 UPDATE (MySQL 5.7 兼容)


-- 原游标过程等价改写为一条 UPDATE（避免 DELIMITER，Navicat 友好）
UPDATE biz_product p
JOIN tmp_cat_industry m ON m.legacy_category_id = p.category_id
SET p.industry_code = m.industry_code
WHERE p.industry_code IS NULL OR p.industry_code = '';


-- 3) 兜底：未匹配到的置 'OTHER' (保证 NOT NULL 约束或业务展示正常)
UPDATE biz_product
SET industry_code = 'OTHER'
WHERE industry_code IS NULL OR industry_code = '';

-- 4) 业务断言 (CI 集成)
SELECT 'biz_product_industry_sync_safe' AS step,
       COUNT(*)                           AS total,
       SUM(CASE WHEN industry_code = '' OR industry_code IS NULL THEN 1 ELSE 0 END) AS empty_industry,
       SUM(CASE WHEN industry_code = 'OTHER' THEN 1 ELSE 0 END) AS other_fallback
FROM biz_product;


-- ############################################################
-- 源文件：sql/biz_product_seed.sql
-- ############################################################

-- ============================================
-- 仅跑 seed 段（L7+ 之后）
-- 用于：主 SQL 1)-6) 已跑过（建表/加列），但 seed 段未跑
-- 11 条 type + 行业品类 seed + 数据迁移 + 同步
-- ============================================

-- 7) 商品类型字典 seed
insert ignore into biz_product_type (type_code, type_name, type_desc, sort, app_can_create, need_license) values
  ('GROUPON',       '团购套餐', '套餐商品，搭配自由，快速吸引顾客',          1, 1, 0),
  ('VOUCHER',       '代金券',   '现金抵扣券，出单快，便于引流增收',          2, 1, 0),
  ('TIMECARD',      '次卡',     '一次购买分次核销，增加用户粘性',            3, 1, 1),
  ('STORED_CARD',   '储值卡',   '通过存储金额，引导顾客多次到店消费',        4, 1, 1),
  ('PERIOD_CARD',   '周期卡',   '月/季/年卡等长周期商品，方便锁客',          5, 1, 1),
  ('HUIXIANG_CARD', '惠享卡',   '大额分次核销，提前锁客',                    6, 1, 1),
  ('PRESALE',       '预售券',   '先买后约，方便用户直播及短视频囤货',        7, 0, 0),
  ('PICKUP_VOUCHER','提货券',   '支持多规格管理和门店库存设置',              8, 0, 0),
  ('COMBO',         '组合券包', '团购、代金券、实物自由组合，一次购买分次核销', 9, 1, 0),
  ('BILL',          '到店买单', '顾客自助输入金额付款（当前 product_type=1）', 10, 1, 0),
  ('BOOKING',       '预约服务', '预约类商品（当前 product_type=2）',         11, 1, 0);

-- 8) 数据迁移：将 biz_category 现有数据迁到 biz_product_category（作为店内分类挂在某品类下）
-- 默认挂在 "购物·美食·堂食套餐"（category_id=10000）下，level=1
insert ignore into biz_product_category
  (category_id, merchant_id, parent_id, category_name, full_path, level, industry_code, allowed_types, sort, status, create_by, create_time)
values
  (10000, 0, 0, '美食',      '美食',                   1, 'CATERING',  'GROUPON,VOUCHER,BILL,BOOKING', 1, '0', 'system', now());

-- 现有店内分类（category_id 100-200）作为美食的子分类
insert ignore into biz_product_category
  (category_id, merchant_id, parent_id, category_name, full_path, level, industry_code, allowed_types, sort, status, create_by, create_time)
select
  category_id + 10000,  -- 避开原 ID 段
  0,
  10000,
  category_name,
  concat('美食·', category_name),
  2,
  'CATERING',
  'GROUPON,VOUCHER,BILL,BOOKING',
  sort,
  status,
  create_by,
  create_time
from biz_category;  -- v2 注: 旧表无 del_flag 列，迁移全部数据

-- 9) 同步商品表的 industry_code（基于其原 category_id 反查）
update biz_product p
  join biz_product_category c on c.category_id = p.category_id + 10000
set p.industry_code = c.industry_code
where p.industry_code = '' or p.industry_code is null;

-- 10) 同步 product_type → type_code
-- 当前映射：0(到店自取)→GROUPON  1(到店买单)→BILL  2(预约服务)→BOOKING
update biz_product set type_code = 'GROUPON' where product_type = '0' and (type_code is null or type_code = '' or type_code = 'GROUPON');
update biz_product set type_code = 'BILL'     where product_type = '1' and (type_code is null or type_code = '' or type_code = 'GROUPON');
update biz_product set type_code = 'BOOKING'  where product_type = '2' and (type_code is null or type_code = '' or type_code = 'GROUPON');

-- 11) 行业品类 seed（全量覆盖抖音来客 8 大类）
-- 一级品类
insert ignore into biz_product_category (category_id, merchant_id, parent_id, category_name, full_path, level, industry_code, deposit_amount, allowed_types, sort, status, create_by, create_time) values
  (1,  0, 0, '购物',         '购物',           1, 'SHOPPING',     500000,  'GROUPON,VOUCHER,HUIXIANG_CARD,COMBO,PRESALE,PICKUP_VOUCHER',  1, '0', 'system', now()),
  (2,  0, 0, '美食',         '美食',           1, 'CATERING',     100000,  'GROUPON,VOUCHER,BILL,BOOKING',                                2, '0', 'system', now()),
  (3,  0, 0, '丽人',         '丽人',           1, 'BEAUTY',       200000,  'GROUPON,VOUCHER,TIMECARD,STORED_CARD,PERIOD_CARD,HUIXIANG_CARD,COMBO,BOOKING', 3, '0', 'system', now()),
  (4,  0, 0, '住宿',         '住宿',           1, 'HOTEL',        300000,  'GROUPON,VOUCHER,PERIOD_CARD,HUIXIANG_CARD,COMBO',              4, '0', 'system', now()),
  (5,  0, 0, '教培',         '教培',           1, 'EDUCATION',    300000,  'GROUPON,VOUCHER,TIMECARD,PERIOD_CARD,HUIXIANG_CARD,COMBO',     5, '0', 'system', now()),
  (6,  0, 0, '休闲娱乐',     '休闲娱乐',       1, 'LEISURE',      150000,  'GROUPON,VOUCHER,TIMECARD,PERIOD_CARD,COMBO',                  6, '0', 'system', now()),
  (7,  0, 0, '生活服务',     '生活服务',       1, 'LIFE_SERVICE', 100000,  'GROUPON,VOUCHER,PERIOD_CARD,COMBO,BOOKING',                   7, '0', 'system', now()),
  (8,  0, 0, '汽车',         '汽车',           1, 'AUTO',         300000,  'GROUPON,VOUCHER,STORED_CARD,PERIOD_CARD,HUIXIANG_CARD,COMBO',  8, '0', 'system', now()),
  (9,  0, 0, '医疗健康',     '医疗健康',       1, 'MEDICAL',      500000,  'GROUPON,VOUCHER,TIMECARD,PERIOD_CARD,HUIXIANG_CARD,COMBO,BOOKING', 9, '0', 'system', now()),
  (10, 0, 0, '宠物',         '宠物',           1, 'PET',           50000,  'GROUPON,VOUCHER,STORED_CARD,COMBO',                          10, '0', 'system', now()),
  (11, 0, 0, '亲子',         '亲子',           1, 'PARENT_CHILD', 200000,  'GROUPON,VOUCHER,TIMECARD,PERIOD_CARD,COMBO',                 11, '0', 'system', now());

-- 二级品类（每个一级下挂常见二级）
insert ignore into biz_product_category (merchant_id, parent_id, category_name, full_path, level, industry_code, deposit_amount, allowed_types, sort, status, create_by, create_time) values
  -- 购物（id=1）下
  (0, 1, '服饰鞋帽',  '购物·服饰鞋帽',  2, 'SHOPPING', 500000, 'GROUPON,VOUCHER,HUIXIANG_CARD,COMBO',                       1, '0', 'system', now()),
  (0, 1, '母婴用品',  '购物·母婴用品',  2, 'SHOPPING', 200000, 'GROUPON,VOUCHER,COMBO,HUIXIANG_CARD',                       2, '0', 'system', now()),
  (0, 1, '美妆个护',  '购物·美妆个护',  2, 'SHOPPING', 300000, 'GROUPON,VOUCHER,HUIXIANG_CARD,COMBO',                       3, '0', 'system', now()),
  (0, 1, '数码家电',  '购物·数码家电',  2, 'SHOPPING', 500000, 'GROUPON,VOUCHER,COMBO',                                     4, '0', 'system', now()),
  (0, 1, '日用百货',  '购物·日用百货',  2, 'SHOPPING', 100000, 'GROUPON,VOUCHER',                                           5, '0', 'system', now()),
  -- 美食（id=2）下
  (0, 2, '火锅',      '美食·火锅',      2, 'CATERING', 100000, 'GROUPON,VOUCHER,BILL,BOOKING',                              1, '0', 'system', now()),
  (0, 2, '中餐',      '美食·中餐',      2, 'CATERING', 100000, 'GROUPON,VOUCHER,BILL,BOOKING',                              2, '0', 'system', now()),
  (0, 2, '西餐',      '美食·西餐',      2, 'CATERING', 100000, 'GROUPON,VOUCHER,BILL,BOOKING',                              3, '0', 'system', now()),
  (0, 2, '小吃快餐',  '美食·小吃快餐',  2, 'CATERING',  50000, 'GROUPON,VOUCHER,BILL',                                      4, '0', 'system', now()),
  (0, 2, '甜品饮品',  '美食·甜品饮品',  2, 'CATERING',  50000, 'GROUPON,VOUCHER,BILL',                                      5, '0', 'system', now()),
  -- 丽人（id=3）下
  (0, 3, '美发',      '丽人·美发',      2, 'BEAUTY',   200000, 'GROUPON,VOUCHER,TIMECARD,STORED_CARD,PERIOD_CARD',          1, '0', 'system', now()),
  (0, 3, '美甲',      '丽人·美甲',      2, 'BEAUTY',   100000, 'GROUPON,VOUCHER,TIMECARD,STORED_CARD',                      2, '0', 'system', now()),
  (0, 3, '美容',      '丽人·美容',      2, 'BEAUTY',   200000, 'GROUPON,VOUCHER,TIMECARD,PERIOD_CARD,HUIXIANG_CARD',        3, '0', 'system', now()),
  (0, 3, '美睫',      '丽人·美睫',      2, 'BEAUTY',   100000, 'GROUPON,VOUCHER,TIMECARD',                                  4, '0', 'system', now()),
  (0, 3, '美体',      '丽人·美体',      2, 'BEAUTY',   200000, 'GROUPON,VOUCHER,PERIOD_CARD',                               5, '0', 'system', now()),
  -- 住宿（id=4）下
  (0, 4, '酒店',      '住宿·酒店',      2, 'HOTEL',    300000, 'GROUPON,VOUCHER,PERIOD_CARD,HUIXIANG_CARD',                 1, '0', 'system', now()),
  (0, 4, '民宿',      '住宿·民宿',      2, 'HOTEL',    200000, 'GROUPON,VOUCHER,PERIOD_CARD',                               2, '0', 'system', now()),
  (0, 4, '公寓',      '住宿·公寓',      2, 'HOTEL',    200000, 'GROUPON,VOUCHER,PERIOD_CARD',                               3, '0', 'system', now()),
  -- 教培（id=5）下
  (0, 5, '学科教育',  '教培·学科教育',  2, 'EDUCATION', 300000, 'GROUPON,VOUCHER,TIMECARD,PERIOD_CARD',                     1, '0', 'system', now()),
  (0, 5, '兴趣教育',  '教培·兴趣教育',  2, 'EDUCATION', 200000, 'GROUPON,VOUCHER,TIMECARD,PERIOD_CARD,COMBO',               2, '0', 'system', now()),
  (0, 5, '职业培训',  '教培·职业培训',  2, 'EDUCATION', 300000, 'GROUPON,VOUCHER,TIMECARD,PERIOD_CARD',                     3, '0', 'system', now()),
  -- 休闲娱乐（id=6）下
  (0, 6, 'KTV',       '休闲娱乐·KTV',   2, 'LEISURE',  150000, 'GROUPON,VOUCHER,TIMECARD,COMBO',                          1, '0', 'system', now()),
  (0, 6, '密室',      '休闲娱乐·密室',  2, 'LEISURE',  150000, 'GROUPON,VOUCHER,TIMECARD,COMBO',                          2, '0', 'system', now()),
  (0, 6, '桌游',      '休闲娱乐·桌游',  2, 'LEISURE',   50000, 'GROUPON,VOUCHER,TIMECARD',                                3, '0', 'system', now()),
  (0, 6, '网吧',      '休闲娱乐·网吧',  2, 'LEISURE',  100000, 'GROUPON,VOUCHER,STORED_CARD,PERIOD_CARD',                 4, '0', 'system', now()),
  (0, 6, '运动健身',  '休闲娱乐·运动健身', 2, 'LEISURE', 100000, 'GROUPON,VOUCHER,PERIOD_CARD,TIMECARD,COMBO',              5, '0', 'system', now()),
  -- 生活服务（id=7）下
  (0, 7, '家政',      '生活服务·家政',  2, 'LIFE_SERVICE', 100000, 'GROUPON,VOUCHER,PERIOD_CARD',                            1, '0', 'system', now()),
  (0, 7, '洗护',      '生活服务·洗护',  2, 'LIFE_SERVICE', 100000, 'GROUPON,VOUCHER,STORED_CARD,PERIOD_CARD',               2, '0', 'system', now()),
  (0, 7, '维修',      '生活服务·维修',  2, 'LIFE_SERVICE', 100000, 'GROUPON,VOUCHER,BOOKING',                                3, '0', 'system', now()),
  -- 汽车（id=8）下
  (0, 8, '保养',      '汽车·保养',      2, 'AUTO',     200000, 'GROUPON,VOUCHER,PERIOD_CARD,HUIXIANG_CARD,COMBO',          1, '0', 'system', now()),
  (0, 8, '洗车',      '汽车·洗车',      2, 'AUTO',     100000, 'GROUPON,VOUCHER,PERIOD_CARD',                              2, '0', 'system', now()),
  (0, 8, '维修',      '汽车·维修',      2, 'AUTO',     300000, 'GROUPON,VOUCHER,BOOKING',                                  3, '0', 'system', now()),
  -- 医疗健康（id=9）下
  (0, 9, '口腔',      '医疗健康·口腔',  2, 'MEDICAL',  500000, 'GROUPON,VOUCHER,TIMECARD,COMBO,BOOKING',                   1, '0', 'system', now()),
  (0, 9, '中医',      '医疗健康·中医',  2, 'MEDICAL',  500000, 'GROUPON,VOUCHER,PERIOD_CARD,COMBO,BOOKING',                2, '0', 'system', now()),
  (0, 9, '医美',      '医疗健康·医美',  2, 'MEDICAL',  500000, 'GROUPON,VOUCHER,TIMECARD,PERIOD_CARD,HUIXIANG_CARD,COMBO,BOOKING', 3, '0', 'system', now()),
  -- 宠物（id=10）下
  (0,10, '宠物美容',  '宠物·宠物美容',  2, 'PET',       50000, 'GROUPON,VOUCHER,STORED_CARD,COMBO',                        1, '0', 'system', now()),
  (0,10, '宠物医疗',  '宠物·宠物医疗',  2, 'PET',       50000, 'GROUPON,VOUCHER,BOOKING',                                  2, '0', 'system', now()),
  (0,10, '宠物寄养',  '宠物·宠物寄养',  2, 'PET',       50000, 'GROUPON,VOUCHER,PERIOD_CARD,COMBO',                        3, '0', 'system', now()),
  -- 亲子（id=11）下
  (0,11, '儿童摄影',  '亲子·儿童摄影',  2, 'PARENT_CHILD', 200000, 'GROUPON,VOUCHER,COMBO',                                  1, '0', 'system', now()),
  (0,11, '儿童乐园',  '亲子·儿童乐园',  2, 'PARENT_CHILD', 200000, 'GROUPON,VOUCHER,COMBO',                                  2, '0', 'system', now()),
  (0,11, '亲子游泳',  '亲子·亲子游泳',  2, 'PARENT_CHILD', 200000, 'GROUPON,VOUCHER,PERIOD_CARD,COMBO',                      3, '0', 'system', now());


-- ============================================================
-- 清理助手过程
-- ============================================================
DROP PROCEDURE IF EXISTS biz_add_column;
DROP PROCEDURE IF EXISTS biz_add_index;
DROP PROCEDURE IF EXISTS biz_drop_index;
DROP PROCEDURE IF EXISTS add_column_if_missing;

SET FOREIGN_KEY_CHECKS = 1;

SELECT '导入完成' AS msg,
       (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE()) AS tables,
       (SELECT COUNT(*) FROM sys_menu) AS menus,
       (SELECT COUNT(*) FROM sys_menu WHERE parent_id IS NULL) AS bad_parent_should_be_0;
