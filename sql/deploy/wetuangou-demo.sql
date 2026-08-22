-- ============================================================
-- Wetangou 演示数据（可选，生产不要执行）
--
-- 用法（在 wetuangou.sql 之后，仅演示/测试环境）：
--   mysql --default-character-set=utf8mb4 -uroot -p 库名 < sql/deploy/wetuangou-demo.sql
--
-- 内容：示例商户/门店/商品/会员/订单/轮播图等演示数据
--
-- 生成方式：由 sql/deploy/build-merged.py 从 sql/*.sql 按实测顺序合并
--            （不要手改本文件，改源脚本后重新生成）
-- 生成时间：2026-08-22
-- ============================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- （本文件不含助手过程，全文无 DELIMITER）


-- ############################################################
-- 源文件：sql/biz_seed.sql
-- ############################################################

-- 演示种子数据
DELETE FROM biz_store WHERE store_id IN (100,101);
INSERT INTO biz_store (store_id,store_name,logo,province,city,district,address,longitude,latitude,phone,service_phone,business_hours,intro,sort,status,create_by,create_time)
VALUES
(100,'洞天团购·旗舰店','','广东省','深圳市','南山区','科技园中区科苑路15号',113.947,22.531,'0755-88888888','0755-88888888','10:00-22:00','旗舰门店，环境优雅',1,'0','admin',sysdate()),
(101,'洞天团购·万象城店','','广东省','深圳市','罗湖区','宝安南路1881号万象城L3',114.121,22.545,'0755-66666666','0755-66666666','10:00-22:30','商圈核心，交通便利',2,'0','admin',sysdate());

DELETE FROM biz_category WHERE category_id IN (100,101,102);
INSERT INTO biz_category (category_id,store_id,category_name,sort,status,create_by,create_time) VALUES
(100,0,'套餐',1,'0','admin',sysdate()),
(101,0,'单品',2,'0','admin',sysdate()),
(102,0,'预约服务',3,'0','admin',sysdate());

DELETE FROM biz_product WHERE product_id IN (1000,1001,1002);
INSERT INTO biz_product (product_id,store_id,category_id,product_name,subtitle,cover,product_type,price,market_price,stock,sales,validity_days,detail,notice,sort,status,create_by,create_time) VALUES
(1000,100,100,'双人精致套餐','含主菜2份+饮品2杯','','0',128.00,268.00,100,20,30,'<p>丰盛双人套餐</p>','<p>1.提前预约；2.节假日通用</p>',1,'0','admin',sysdate()),
(1001,100,101,'招牌牛肉面','秘制汤底','','0',38.00,58.00,200,80,30,'<p>招牌面食</p>','<p>到店即食</p>',2,'0','admin',sysdate()),
(1002,101,102,'SPA理疗60分钟','专业理疗师','','2',198.00,398.00,50,10,60,'<p>舒缓SPA</p>','<p>需提前预约</p>',3,'0','admin',sysdate());

DELETE FROM biz_commission_rule WHERE rule_id IN (1);
INSERT INTO biz_commission_rule (rule_id,rule_name,store_id,level,rate,settle_days,status,create_by,create_time)
VALUES (1,'全平台一级推客10%',0,1,10.00,7,'0','admin',sysdate());

DELETE FROM biz_voucher WHERE voucher_id IN (100);
INSERT INTO biz_voucher (voucher_id,store_id,voucher_name,face_value,threshold,total,received,valid_days,status,create_by,create_time)
VALUES (100,0,'满100减20',20.00,100.00,1000,0,30,'0','admin',sysdate());

DELETE FROM biz_agreement WHERE agreement_id IN (100,101,102);
INSERT INTO biz_agreement (agreement_id,agreement_type,title,content,store_id,status,create_by,create_time) VALUES
(100,'user','用户协议','<p>欢迎使用洞天团购小程序……</p>',0,'0','admin',sysdate()),
(101,'privacy','隐私政策','<p>我们重视您的隐私……</p>',0,'0','admin',sysdate()),
(102,'distributor','推客协议','<p>推客分销规则……</p>',0,'0','admin',sysdate());


-- ############################################################
-- 源文件：sql/biz_demo_data.sql
-- ############################################################

-- =============================================
-- 演示数据：从小程序 mock 提取并落库（门店 / 商品 / 相册 / 分类 / 协议 / 代金券）
-- 执行：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_demo_data.sql
-- 背景：小程序原先在接口返回空时回退 utils/mock.js，关闭 mock 后页面会空白；
--       本脚本把那份演示数据搬进后台，保证真实接口即有内容可展示。
-- 归属：商户 1（洞天团购默认商户），门店 ID 200，商品 ID 2000-2003，均为固定 ID 便于幂等重跑。
-- 图片：需先把 miniprogram7/assets/img 下 4 张图拷到上传目录 upload/demo/（见脚本末尾说明）。
-- 幂等：可重复执行，先按固定 ID 删除再插入。
-- =============================================

SET @merchant_id = 1;
SET @store_id = 200;

-- ----------------------------
-- 步骤1：清理本脚本管理的数据（按固定ID，不影响其他种子数据）
-- ----------------------------
DELETE FROM biz_store_album WHERE store_id = @store_id;
DELETE FROM biz_product WHERE product_id BETWEEN 2000 AND 2003;
DELETE FROM biz_store WHERE store_id = @store_id;
DELETE FROM biz_category WHERE category_id BETWEEN 200 AND 202;
DELETE FROM biz_voucher WHERE voucher_id BETWEEN 200 AND 201;

-- ----------------------------
-- 步骤2：门店（mock stores[0] 菌鑫来餐饮）
-- services 存 sys_dict_data 中 biz_store_service 的码值（逗号分隔），
-- 与后台门店编辑页的复选框一致；小程序展示时需按字典翻译成中文标签
-- ----------------------------
INSERT INTO biz_store (store_id, merchant_id, store_name, logo, province, city, district, address,
  longitude, latitude, phone, service_phone, business_hours, intro, services, sort, status, del_flag,
  create_by, create_time, remark)
VALUES (@store_id, @merchant_id, '菌鑫来餐饮', '/profile/upload/demo/banner1.jpg',
  '广东省', '广州市', '花都区', '花城街道建设北路222号101房自编3号',
  113.227000, 23.405000, '13434123069', '13434123069', '周一至周日 09:00-22:30',
  '胡苏老菌庄 · 主打云南时令野生菌，菌汤浓郁，适合家庭聚餐与商务宴请。',
  'dine_in,can_book,private_room,free_parking_lot,free_parking', 1, '0', '0',
  'admin', SYSDATE(), '演示数据，来源小程序 mock');

-- ----------------------------
-- 步骤3：门店相册（mock stores[0].album）
-- ----------------------------
INSERT INTO biz_store_album (merchant_id, store_id, image_url, album_type, sort, create_by, create_time) VALUES
(@merchant_id, @store_id, '/profile/upload/demo/RestaurantImg.png', '0', 1, 'admin', SYSDATE()),
(@merchant_id, @store_id, '/profile/upload/demo/GoodsImg.jpg',      '0', 2, 'admin', SYSDATE()),
(@merchant_id, @store_id, '/profile/upload/demo/banner1.jpg',       '0', 3, 'admin', SYSDATE()),
(@merchant_id, @store_id, '/profile/upload/demo/BookTypeImg.jpg',   '0', 4, 'admin', SYSDATE());

-- ----------------------------
-- 步骤4：该门店的商品分类
-- ----------------------------
INSERT INTO biz_category (category_id, merchant_id, store_id, category_name, icon, sort, status, create_by, create_time) VALUES
(200, @merchant_id, @store_id, '野生菌套餐', '', 1, '0', 'admin', SYSDATE()),
(201, @merchant_id, @store_id, '火锅锅底',   '', 2, '0', 'admin', SYSDATE()),
(202, @merchant_id, @store_id, '预约服务',   '', 3, '0', 'admin', SYSDATE());

-- ----------------------------
-- 步骤5：商品（mock goods 四款，套餐明细写入 detail，使用规则写入 notice）
-- product_type：0 团购券
-- ----------------------------
INSERT INTO biz_product (product_id, merchant_id, store_id, category_id, product_name, subtitle,
  cover, images, product_type, price, market_price, stock, sales, validity_days, detail, notice,
  sort, status, del_flag, create_by, create_time, remark)
VALUES (2000, @merchant_id, @store_id, 200, '【大满足】野生菌6-8人餐', '菌香浓郁，6-8人聚餐首选',
  '/profile/upload/demo/RestaurantImg.png',
  '/profile/upload/demo/RestaurantImg.png,/profile/upload/demo/GoodsImg.jpg,/profile/upload/demo/banner1.jpg',
  '0', 498.00, 698.00, 200, 0, 365,
  '<p><strong>套餐内容</strong></p>
<table border="1" cellspacing="0" cellpadding="6" style="width:100%;border-collapse:collapse">
    <tr><th>项目</th><th>数量</th><th>价格</th></tr>
    <tr><td>山茶菌</td><td style="text-align:center">1</td><td style="text-align:right">¥48.00</td></tr>
    <tr><td>猪肚菌</td><td style="text-align:center">1</td><td style="text-align:right">¥53.00</td></tr>
    <tr><td>牛排菌</td><td style="text-align:center">1</td><td style="text-align:right">¥58.00</td></tr>
    <tr><td>丛枝菌</td><td style="text-align:center">1</td><td style="text-align:right">¥68.00</td></tr>
    <tr><td>白虎掌菌</td><td style="text-align:center">1</td><td style="text-align:right">¥138.00</td></tr>
    <tr><td>排骨</td><td style="text-align:center">1</td><td style="text-align:right">¥48.00</td></tr>
    <tr><td>清远麻鸡</td><td style="text-align:center">1</td><td style="text-align:right">¥158.00</td></tr>
    <tr><td>招牌杂菌炒饭</td><td style="text-align:center">1</td><td style="text-align:right">¥48.00</td></tr>
    <tr><td>杂菜</td><td style="text-align:center">1</td><td style="text-align:right">¥10.00</td></tr>
    <tr><td>茶位</td><td style="text-align:center">8</td><td style="text-align:right">¥3.00</td></tr>
    <tr><td>纸巾</td><td style="text-align:center">1</td><td style="text-align:right">¥3.00</td></tr>
</table>',
  '<p><strong>使用规则</strong></p><ul><li>可用时间：10:30至21:00</li><li>购买限制：不限制购买数量</li><li>预约提醒：到店消费：无需预约，高峰期可能需要排队</li><li>使用规则：不与店内优惠同享</li><li>代金券限制：每人最多使用1张</li><li>人数限制：不限制人数</li><li>如需发票，请向商家索取</li></ul>',
  1, '0', '0', 'admin', SYSDATE(), '演示数据，来源小程序 mock');

INSERT INTO biz_product (product_id, merchant_id, store_id, category_id, product_name, subtitle,
  cover, images, product_type, price, market_price, stock, sales, validity_days, detail, notice,
  sort, status, del_flag, create_by, create_time, remark)
VALUES (2001, @merchant_id, @store_id, 201, '【到店必吃】野生菌火锅四人餐', '招牌菌汤锅底，4人份',
  '/profile/upload/demo/GoodsImg.jpg',
  '/profile/upload/demo/GoodsImg.jpg,/profile/upload/demo/RestaurantImg.png',
  '0', 268.00, 368.00, 200, 0, 365,
  '<p><strong>套餐内容</strong></p>
<table border="1" cellspacing="0" cellpadding="6" style="width:100%;border-collapse:collapse">
    <tr><th>项目</th><th>数量</th><th>价格</th></tr>
    <tr><td>野生菌火锅四人份</td><td style="text-align:center">1</td><td style="text-align:right">¥268.00</td></tr>
</table>',
  '<p><strong>使用规则</strong></p><ul><li>可用时间：10:30至21:00</li><li>购买限制：不限制购买数量</li><li>预约提醒：到店消费：无需预约，高峰期可能需要排队</li><li>使用规则：不与店内优惠同享</li><li>代金券限制：每人最多使用1张</li><li>人数限制：不限制人数</li><li>如需发票，请向商家索取</li></ul>',
  2, '0', '0', 'admin', SYSDATE(), '演示数据，来源小程序 mock');

INSERT INTO biz_product (product_id, merchant_id, store_id, category_id, product_name, subtitle,
  cover, images, product_type, price, market_price, stock, sales, validity_days, detail, notice,
  sort, status, del_flag, create_by, create_time, remark)
VALUES (2002, @merchant_id, @store_id, 200, '超值2-3人餐', '小聚首选，2-3人份',
  '/profile/upload/demo/GoodsImg.jpg',
  '/profile/upload/demo/GoodsImg.jpg',
  '0', 168.00, 228.00, 200, 0, 365,
  '<p><strong>套餐内容</strong></p>
<table border="1" cellspacing="0" cellpadding="6" style="width:100%;border-collapse:collapse">
    <tr><th>项目</th><th>数量</th><th>价格</th></tr>
    <tr><td>超值2-3人份</td><td style="text-align:center">1</td><td style="text-align:right">¥168.00</td></tr>
</table>',
  '<p><strong>使用规则</strong></p><ul><li>可用时间：10:30至21:00</li><li>购买限制：不限制购买数量</li><li>预约提醒：到店消费：无需预约，高峰期可能需要排队</li><li>使用规则：不与店内优惠同享</li><li>代金券限制：每人最多使用1张</li><li>人数限制：不限制人数</li><li>如需发票，请向商家索取</li></ul>',
  3, '0', '0', 'admin', SYSDATE(), '演示数据，来源小程序 mock');

INSERT INTO biz_product (product_id, merchant_id, store_id, category_id, product_name, subtitle,
  cover, images, product_type, price, market_price, stock, sales, validity_days, detail, notice,
  sort, status, del_flag, create_by, create_time, remark)
VALUES (2003, @merchant_id, @store_id, 200, '尝鲜推荐·野生菌鸡煲双人套餐', '清远麻鸡 + 时令野生菌',
  '/profile/upload/demo/BookTypeImg.jpg',
  '/profile/upload/demo/BookTypeImg.jpg,/profile/upload/demo/GoodsImg.jpg',
  '0', 138.00, 198.00, 200, 0, 365,
  '<p><strong>套餐内容</strong></p>
<table border="1" cellspacing="0" cellpadding="6" style="width:100%;border-collapse:collapse">
    <tr><th>项目</th><th>数量</th><th>价格</th></tr>
    <tr><td>野生菌鸡煲双人份</td><td style="text-align:center">1</td><td style="text-align:right">¥138.00</td></tr>
</table>',
  '<p><strong>使用规则</strong></p><ul><li>可用时间：10:30至21:00</li><li>购买限制：不限制购买数量</li><li>预约提醒：到店消费：无需预约，高峰期可能需要排队</li><li>使用规则：不与店内优惠同享</li><li>代金券限制：每人最多使用1张</li><li>人数限制：不限制人数</li><li>如需发票，请向商家索取</li></ul>',
  4, '0', '0', 'admin', SYSDATE(), '演示数据，来源小程序 mock');

-- ----------------------------
-- 步骤6：协议正文（mock agreement，纯文本转富文本）
-- 原库中只有 40 余字的占位内容，此处替换为完整正文
-- ----------------------------
UPDATE biz_agreement SET title = '用户服务协议', content = '<p><strong>用户服务协议</strong></p>
<p>更新日期：2026年7月1日</p>
<p>生效日期：2026年7月1日</p>
<p>欢迎使用菌鑫来餐饮微信小程序服务。本协议是您与广州花都菌鑫来餐饮店（以下简称"我们/平台"）之间关于使用小程序服务的有效约定。您使用、登录、购买本小程序服务，即代表已阅读、理解并同意遵守本协议全部条款；若您不同意，请立即停止使用本服务。</p>
<p><strong>一、主体信息</strong></p>
<p>平台运营主体：广州花都菌鑫来餐饮店</p>
<p>服务产品：菌鑫来餐饮微信小程序</p>
<p>客服电话：13434123069</p>
<p>联系邮箱：3621065215@qq.com</p>
<p><strong>二、服务内容</strong></p>
<p>本小程序为用户提供门店信息浏览、团购商品查看、团购券购买、券码核销、订单管理、售后退款、客服咨询等配套技术与信息服务。平台仅提供交易技术支持，商品及到店服务均由合作门店提供，门店承担对应服务履约及质量责任，平台依法履行平台管理义务。</p>
<p><strong>三、用户使用规范</strong></p>
<p>1. 用户需为具备完全民事行为能力的自然人，未成年人需在监护人同意及陪同下使用本服务。</p>
<p>2. 用户承诺提交的手机号、身份信息、账户信息真实有效，不得冒用他人信息操作，因信息不实造成的损失由用户承担。</p>',
  update_by = 'admin', update_time = SYSDATE()
WHERE agreement_type = 'user';

UPDATE biz_agreement SET title = '用户隐私政策', content = '<p><strong>用户隐私政策</strong></p>
<p>更新日期：2026年7月1日</p>
<p>生效日期：2026年7月1日</p>
<p>广州花都菌鑫来餐饮店（以下简称"我们"）及旗下菌鑫来餐饮微信小程序，高度重视用户隐私与个人信息保护。本隐私政策旨在告知用户我们如何收集、使用、存储、共享及保护您的个人信息，以及您所享有的相关权利。</p>
<p>使用本小程序即代表您同意本政策全部内容；若您不同意，将无法使用本小程序相关服务。</p>
<p><strong>一、适用范围</strong></p>
<p>本政策适用于用户使用菌鑫来餐饮小程序全部服务场景，包括浏览、登录、购买团购、订单管理、到店核销、退款售后、客服咨询、参与活动等全部功能。</p>
<p><strong>二、信息收集与使用规则</strong></p>
<p>我们仅收集为提供服务所必需的个人信息，不会过度采集用户数据。</p>
<p>1. 登录与账号识别信息</p>
<p>收集：微信OpenID、昵称、头像、设备信息、网络信息、登录记录；必要时收集手机号。</p>
<p>用途：用于账号识别、正常登录、保障账号安全、关联订单与售后记录。</p>
<p>2. 订单与交易信息</p>
<p>收集：订单号、下单门店、券码、支付金额、支付记录。</p>
<p>用途：完成下单、支付、发券、核销、退款、售后处理、交易安全及财务对账。</p>
<p>3. 核销服务信息</p>
<p>收集：券码、核销状态、核销时间、核销门店信息。</p>
<p>用途：用于核销服务记录与争议处理。</p>',
  update_by = 'admin', update_time = SYSDATE()
WHERE agreement_type = 'privacy';

-- 推客协议：小程序推客中心「推客协议」弹层读取此条，原库中仅 15 字占位
UPDATE biz_agreement SET title = '推客推广服务协议', content = '<p><strong>推客推广服务协议</strong></p>
<p>更新日期：2026年8月1日</p>
<p>本协议是您（以下简称"推客"）与广州花都菌鑫来餐饮店就参与本店推广分销服务达成的约定。您申请成为推客即视为已阅读并同意本协议全部条款。</p>
<p><strong>一、推客资格</strong></p>
<p>1. 推客须为已完成实名手机号绑定的本小程序注册会员，且具备完全民事行为能力。</p>
<p>2. 推客身份不可转让、出借或与他人共用，一经发现平台有权收回资格并冻结未结算佣金。</p>
<p><strong>二、佣金计算与结算</strong></p>
<p>1. 佣金按订单实付金额乘以对应商品佣金比例计算，具体比例以下单时后台配置为准。</p>
<p>2. 订单支付成功后佣金进入待结算状态，自订单核销完成起经过冷静期（默认 7 天）后转为可提现余额；期间发生退款、撤销核销的订单不产生佣金。</p>
<p>3. 推客可在推客中心查看累计收入、可提现余额、提现中金额与已提现金额。</p>
<p><strong>三、提现规则</strong></p>
<p>1. 提现金额不得超过可提现余额，提现申请提交后对应金额即被冻结，等待平台审核打款。</p>
<p>2. 提现需提供真实有效的收款账户信息，因账户信息填写错误导致的打款失败与损失由推客自行承担。</p>
<p>3. 审核不通过时冻结金额将退回可提现余额，并在提现记录中标注驳回原因。</p>
<p><strong>四、推广行为规范</strong></p>
<p>1. 禁止以虚假宣传、夸大功效、恶意比价、诱导下单后退款刷单等方式获取佣金。</p>
<p>2. 禁止在未获授权的渠道以本店名义发布广告，禁止盗用本店品牌标识从事其他经营活动。</p>
<p>3. 违反上述规范的，平台有权取消相关订单佣金、冻结账户并追究相应责任。</p>
<p><strong>五、协议变更</strong></p>
<p>平台有权根据经营需要调整佣金比例与结算规则，调整后自小程序内公示之日起生效，继续参与推广即视为接受变更。</p>',
  update_by = 'admin', update_time = SYSDATE()
WHERE agreement_type = 'distributor';

-- ----------------------------
-- 步骤7：该门店可领代金券（小程序券入口所需）
-- ----------------------------
INSERT INTO biz_voucher (voucher_id, merchant_id, store_id, voucher_name, face_value, threshold,
  total, received, valid_days, status, create_by, create_time) VALUES
(200, @merchant_id, @store_id, '新客立减10元',  10.00,  50.00, 500, 0, 30, '0', 'admin', SYSDATE()),
(201, @merchant_id, @store_id, '满300减50元',   50.00, 300.00, 200, 0, 60, '0', 'admin', SYSDATE());

-- ----------------------------
-- 验证
-- ----------------------------
SELECT store_id, store_name, phone, business_hours, services FROM biz_store WHERE store_id = @store_id;
SELECT product_id, product_name, price, market_price, stock, category_id FROM biz_product WHERE product_id BETWEEN 2000 AND 2003;
SELECT COUNT(*) AS 相册张数 FROM biz_store_album WHERE store_id = @store_id;
SELECT agreement_type, title, CHAR_LENGTH(content) AS 正文字数 FROM biz_agreement WHERE agreement_type IN ('user','privacy','distributor');
SELECT voucher_id, voucher_name, face_value, threshold FROM biz_voucher WHERE voucher_id BETWEEN 200 AND 201;

-- ----------------------------
-- 图片准备（首次执行前）：把小程序内置图拷到 RuoYi 上传目录
--   mkdir -p $RUOYI_PROFILE/upload/demo
--   cp miniprogram7/assets/img/{RestaurantImg.png,GoodsImg.jpg,banner1.jpg,BookTypeImg.jpg} \
--      $RUOYI_PROFILE/upload/demo/
-- $RUOYI_PROFILE 为 application.yml 中 ruoyi.profile 的值（默认 /Users/mac/ruoyi/uploadPath）
-- ----------------------------


-- ############################################################
-- 源文件：sql/biz_banner_home_seed.sql
-- ############################################################

-- ============================================================
-- 首页 banner 种子数据（演示用，真阿里云 OSS 图片）
-- ============================================================
-- 用法：
--   mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_banner_home_seed.sql
--
-- 前提：
--   1) 已执行 sql/deploy/sys_config_production.sql（或商户 wx.* 配置已就位）
--   2) 已上传演示图到 OSS（参考 AGENTS.md 部署章节）
--   3) merchant_id=1 是 demo 商户（洞天团购）
-- ============================================================

-- 清空旧演示 banner
DELETE FROM biz_banner WHERE merchant_id = 1 AND position = 'home' AND title LIKE '%双人火锅%';
DELETE FROM biz_banner WHERE merchant_id = 1 AND position = 'home' AND title LIKE '%代金券%';
DELETE FROM biz_banner WHERE merchant_id = 1 AND position = 'home' AND title LIKE '%组合券包%';

-- 3 张 banner（点击跳商品详情）
INSERT INTO biz_banner
  (merchant_id, position, title, image_url, link_url, status, sort, create_by, create_time)
VALUES
  (1, 'home', '云南野生菌双人火锅套餐',
     'https://wetuango.oss-cn-shenzhen.aliyuncs.com/2026/08/17/RestaurantImg_20260817172226A004.png',
     '/pages/goods/detail/index?id=999534',
     '0', 1, 'admin', NOW()),
  (1, 'home', '100 元代金券 / 满 200 可用',
     'https://wetuango.oss-cn-shenzhen.aliyuncs.com/2026/08/17/GoodsImg_20260817172230A005.jpg',
     '/pages/goods/detail/index?id=999535',
     '0', 2, 'admin', NOW()),
  (1, 'home', '超值组合券包 / 一次购买分次核销',
     'https://wetuango.oss-cn-shenzhen.aliyuncs.com/2026/08/17/banner1_20260817172230A006.jpg',
     '/pages/goods/detail/index?id=999536',
     '0', 3, 'admin', NOW());

-- 验证
SELECT banner_id, title, image_url, link_url, sort
FROM biz_banner WHERE position='home' ORDER BY sort;


-- ############################################################
-- 源文件：sql/biz_product_subitem_seed.sql
-- ############################################################

-- ============================================================
-- biz_product_subitem / biz_product_subitem_group 种子数据
-- 2026-08-14
-- 用途：本地端到端测试商品详情 subitemGroups 端点
-- 幂等：INSERT IGNORE / NOT EXISTS，重复跑安全
-- 注：每行 group_id 自增（避免 product 共享主键冲突）
-- ============================================================

-- === GROUPON 商品：2-3 人餐 / 4-6 人餐 规格 ===
-- product 2000 套餐
INSERT IGNORE INTO biz_product_subitem_group (group_id, product_id, group_name, pick_rule, sort, create_time)
VALUES (20001, 2000, '套餐规格', 'PICK', 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (20001, 2000, '2-3 人餐', 1, 168.00, 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (20001, 2000, '4-6 人餐', 1, 268.00, 2, NOW());

-- product 2001 套餐
INSERT IGNORE INTO biz_product_subitem_group (group_id, product_id, group_name, pick_rule, sort, create_time)
VALUES (20011, 2001, '套餐规格', 'PICK', 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (20011, 2001, '2-3 人餐', 1, 168.00, 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (20011, 2001, '4-6 人餐', 1, 268.00, 2, NOW());

-- product 2002
INSERT IGNORE INTO biz_product_subitem_group (group_id, product_id, group_name, pick_rule, sort, create_time)
VALUES (20021, 2002, '套餐规格', 'PICK', 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (20021, 2002, '2-3 人餐', 1, 168.00, 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (20021, 2002, '4-6 人餐', 1, 268.00, 2, NOW());

-- product 2003
INSERT IGNORE INTO biz_product_subitem_group (group_id, product_id, group_name, pick_rule, sort, create_time)
VALUES (20031, 2003, '套餐规格', 'PICK', 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (20031, 2003, '2-3 人餐', 1, 168.00, 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (20031, 2003, '4-6 人餐', 1, 268.00, 2, NOW());

-- === BOOKING 商品：SPA 时长 ===
-- product 1002 SPA 60/90 分钟
INSERT IGNORE INTO biz_product_subitem_group (group_id, product_id, group_name, pick_rule, sort, create_time)
VALUES (10021, 1002, '服务时长', 'PICK', 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (10021, 1002, '60 分钟', 1, 198.00, 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (10021, 1002, '90 分钟', 1, 298.00, 2, NOW());

-- === GROUPON 口味/主菜 ===
-- product 1000 套餐
INSERT IGNORE INTO biz_product_subitem_group (group_id, product_id, group_name, pick_rule, sort, create_time)
VALUES (10001, 1000, '口味', 'PICK', 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (10001, 1000, '微辣', 1, 128.00, 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (10001, 1000, '中辣', 1, 128.00, 2, NOW());

-- product 1001 主菜
INSERT IGNORE INTO biz_product_subitem_group (group_id, product_id, group_name, pick_rule, sort, create_time)
VALUES (10011, 1001, '主菜', 'PICK', 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (10011, 1001, '宫保鸡丁', 1, 38.00, 1, NOW());
INSERT IGNORE INTO biz_product_subitem (group_id, product_id, subitem_name, quantity, price, sort, create_time)
VALUES (10011, 1001, '鱼香肉丝', 1, 38.00, 2, NOW());


-- ############################################################
-- 源文件：sql/biz_fee_staffinvite_seed.sql
-- ############################################################

-- ============================================================
-- biz_agent_fee / biz_merchant_fee / biz_merchant_staff_invite 种子数据
-- 2026-08-14（推进 doc/下一轮迭代清单-2026-08-14.md E2）
-- 用途：让 admin 端 /biz/agentfee /biz/merchantfee /biz/staffInvite 端到端可见
-- 幂等：INSERT IGNORE，重复跑安全
-- ============================================================

-- === biz_agent_fee 缴费记录 ===
-- agent 1 缴费 12 个月（年初缴到明年）
INSERT IGNORE INTO biz_agent_fee (fee_id, fee_no, agent_id, fee_type, amount, quota_add, months, pay_channel, pay_time, status, audit_by, audit_time, create_by, create_time, remark)
VALUES (1000001, 'AF2026010001', 1, '1', 1200.00, 50, 12, '1', '2026-01-15 10:30:00', '1', 'admin', '2026-01-15 11:00:00', 'admin', '2026-01-15 10:00:00', '2026 年度缴费 12 个月 +50 商户额度');
-- agent 1 续费 6 个月
INSERT IGNORE INTO biz_agent_fee (fee_id, fee_no, agent_id, fee_type, amount, quota_add, months, pay_channel, pay_time, status, audit_by, audit_time, create_by, create_time, remark)
VALUES (1000002, 'AF2026080001', 1, '1', 800.00, 30, 6, '1', '2026-08-01 14:20:00', '1', 'admin', '2026-08-01 14:30:00', 'admin', '2026-08-01 14:00:00', '2026-08 续费 6 个月 +30 商户额度');
-- agent 100 缴费 3 个月（小代理商）
INSERT IGNORE INTO biz_agent_fee (fee_id, fee_no, agent_id, fee_type, amount, quota_add, months, pay_channel, pay_time, status, audit_by, audit_time, create_by, create_time, remark)
VALUES (1000100, 'AF2026070100', 100, '1', 600.00, 10, 3, '0', NULL, '0', NULL, NULL, 'admin', '2026-07-15 09:00:00', '2026-07 提交 3 个月缴费待审核');
-- agent 101 缴费 1 个月
INSERT IGNORE INTO biz_agent_fee (fee_id, fee_no, agent_id, fee_type, amount, quota_add, months, pay_channel, pay_time, status, audit_by, audit_time, create_by, create_time, remark)
VALUES (1000101, 'AF2026080101', 101, '1', 200.00, 5, 1, '1', '2026-08-10 16:00:00', '1', 'admin', '2026-08-10 16:30:00', 'admin', '2026-08-10 15:30:00', '2026-08 缴费 1 个月 +5 商户额度');

-- === biz_merchant_fee 商户服务费 ===
-- merchant 1 缴年费（agent 1 名下）
INSERT IGNORE INTO biz_merchant_fee (fee_id, fee_no, merchant_id, agent_id, fee_type, amount, months, begin_time, end_time, status, create_by, create_time, remark)
VALUES (2000001, 'MF2026010001', 1, 1, '1', 800.00, 12, '2026-01-15 11:30:00', '2027-01-15 11:30:00', '1', 'admin', '2026-01-15 11:00:00', '2026 年度服务费 12 个月');
-- merchant 200 缴半年（agent 101 名下）
INSERT IGNORE INTO biz_merchant_fee (fee_id, fee_no, merchant_id, agent_id, fee_type, amount, months, begin_time, end_time, status, create_by, create_time, remark)
VALUES (2000200, 'MF2026080200', 200, 101, '1', 500.00, 6, '2026-08-10 17:00:00', '2027-02-10 17:00:00', '1', 'admin', '2026-08-10 16:30:00', '2026-08 半年服务费');

-- === biz_merchant_staff_invite 员工邀请码 ===
-- merchant 1 store 1 邀请 STAFF
INSERT IGNORE INTO biz_merchant_staff_invite (invite_id, invite_code, scene, wxacode_url, merchant_id, store_id, role, expire_at, status, create_by, create_time, remark)
VALUES (3000001, 'STAFF001', 'staff_invite:1:1:STAFF', 'https://example.com/qr/staff001.png', 1, 1, 'STAFF', '2026-09-30 23:59:59', '0', 'admin', '2026-08-01 09:00:00', '员工邀请码 STAFF001');
-- merchant 1 store 1 邀请 MANAGER
INSERT IGNORE INTO biz_merchant_staff_invite (invite_id, invite_code, scene, wxacode_url, merchant_id, store_id, role, expire_at, status, create_by, create_time, remark)
VALUES (3000002, 'MNG0002', 'staff_invite:1:1:MGR', 'https://example.com/qr/mng0002.png', 1, 1, 'MANAGER', '2026-09-30 23:59:59', '1', 'admin', '2026-08-05 10:00:00', '店长邀请码 MNG0002（已用）');


-- ############################################################
-- 源文件：sql/biz_mpauth_settle_seed.sql
-- ############################################################

-- ============================================================
-- biz_mp_auth / biz_settle_account / biz_settle_record 种子数据
-- 2026-08-14（推进 doc/下一轮迭代清单-2026-08-14.md E3）
-- 用途：让 admin 端 /biz/mpauth /biz/account /biz/record 端到端可见
-- 幂等：INSERT IGNORE，重复跑安全
-- ============================================================

-- === biz_mp_auth 微信第三方平台授权 ===
-- merchant 1 已授权（与 mprelease 2 条数据匹配 appid）
INSERT IGNORE INTO biz_mp_auth (auth_id, merchant_id, appid, nick_name, head_img, principal_name, verify_type, refresh_token, func_info, auth_status, auth_time, create_time, update_time)
VALUES (5000001, 1, 'wx9e147c4e2151b123', '洞天团购测试小程序', 'https://example.com/headimg.jpg', '张三', '-1', 'rt_xxxxx_refresh_token_value_1234567890', '17,18,19,25,30,31,36,40,41,44,45,48,49,50,51,52', '1', '2026-07-15 10:30:00', '2026-07-15 10:00:00', '2026-08-02 03:24:15');
-- merchant 200 未授权（演示待授权状态）
INSERT IGNORE INTO biz_mp_auth (auth_id, merchant_id, appid, nick_name, principal_name, auth_status, create_time)
VALUES (5000200, 200, 'wx9876543210abcdef', '美食城小程序', '李四', '0', '2026-08-10 14:00:00');

-- === biz_settle_account 分账接收方 ===
-- merchant 1 默认账户：分账给平台 30% / 商户 70%
INSERT IGNORE INTO biz_settle_account (account_id, merchant_id, owner_type, owner_id, receiver_type, receiver_account, receiver_name, rate, status, create_time, update_time)
VALUES (6000001, 1, '1', 1, 'MERCHANT_ID', 'merchant_001', '洞天团购主商户', 70.00, '1', '2026-07-15 11:00:00', '2026-08-01 10:00:00');
-- merchant 1 平台账户
INSERT IGNORE INTO biz_settle_account (account_id, merchant_id, owner_type, owner_id, receiver_type, receiver_account, receiver_name, rate, status, create_time, update_time)
VALUES (6000002, 1, '0', 0, 'PLATFORM', 'platform_main', '平台运营账户', 30.00, '1', '2026-07-15 11:00:00', '2026-08-01 10:00:00');
-- merchant 200 推客账户
INSERT IGNORE INTO biz_settle_account (account_id, merchant_id, owner_type, owner_id, receiver_type, receiver_account, receiver_name, rate, status, create_time)
VALUES (6000200, 200, '2', 100, 'DISTRIBUTOR_ID', 'distributor_100', '推客100账户', 10.00, '1', '2026-08-10 14:30:00');

-- === biz_settle_record 分账记录 ===
-- order 1 (假设) 分账 100 元
INSERT IGNORE INTO biz_settle_record (record_id, merchant_id, order_id, out_order_no, receiver_account, amount, status, finish_time, create_time)
VALUES (7000001, 1, 1001, 'OUT20260810001', 'merchant_001', 70.00, '1', '2026-08-10 15:00:00', '2026-08-10 14:50:00');
INSERT IGNORE INTO biz_settle_record (record_id, merchant_id, order_id, out_order_no, receiver_account, amount, status, finish_time, create_time)
VALUES (7000002, 1, 1001, 'OUT20260810001', 'platform_main', 30.00, '1', '2026-08-10 15:00:00', '2026-08-10 14:50:00');
-- order 2 分账中（演示 status=0 处理中）
INSERT IGNORE INTO biz_settle_record (record_id, merchant_id, order_id, out_order_no, receiver_account, amount, status, create_time)
VALUES (7000003, 1, 1002, 'OUT20260812001', 'merchant_001', 168.00, '0', '2026-08-12 10:00:00');
-- order 3 失败
INSERT IGNORE INTO biz_settle_record (record_id, merchant_id, order_id, out_order_no, receiver_account, amount, status, create_time)
VALUES (7000004, 1, 1003, 'OUT20260813001', 'merchant_001', 38.00, '2', '2026-08-13 16:00:00');


SET FOREIGN_KEY_CHECKS = 1;

SELECT '导入完成' AS msg,
       (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE()) AS tables,
       (SELECT COUNT(*) FROM sys_menu) AS menus,
       (SELECT COUNT(*) FROM sys_menu WHERE parent_id IS NULL) AS bad_parent_should_be_0;
