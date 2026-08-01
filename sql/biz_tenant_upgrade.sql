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

drop procedure if exists biz_add_index;
delimiter $$
create procedure biz_add_index(in p_table varchar(64), in p_index varchar(64), in p_ddl varchar(500))
begin
  if not exists (select 1 from information_schema.statistics
                 where table_schema = database() and table_name = p_table and index_name = p_index) then
    set @sql = concat('alter table `', p_table, '` add ', p_ddl);
    prepare stmt from @sql; execute stmt; deallocate prepare stmt;
  end if;
end $$
delimiter ;

drop procedure if exists biz_drop_index;
delimiter $$
create procedure biz_drop_index(in p_table varchar(64), in p_index varchar(64))
begin
  if exists (select 1 from information_schema.statistics
             where table_schema = database() and table_name = p_table and index_name = p_index) then
    set @sql = concat('alter table `', p_table, '` drop index `', p_index, '`');
    prepare stmt from @sql; execute stmt; deallocate prepare stmt;
  end if;
end $$
delimiter ;

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
  case when ifnull((select config_value from sys_config where config_key = 'wx.pay.mockEnabled'), 'true') = 'true'
       then '0' else '1' end,
  '0', 'admin', sysdate()
where not exists (select 1 from biz_merchant m where m.merchant_id = 1);

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

-- ----------------------------
-- 清理临时过程
-- ----------------------------
drop procedure if exists biz_add_column;
drop procedure if exists biz_add_index;
drop procedure if exists biz_drop_index;
