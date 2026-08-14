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
