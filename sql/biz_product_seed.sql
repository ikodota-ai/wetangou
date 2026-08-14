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
from biz_category
where del_flag = '0';

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

