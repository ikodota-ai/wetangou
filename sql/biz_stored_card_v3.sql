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
