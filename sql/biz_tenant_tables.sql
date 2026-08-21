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
