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
