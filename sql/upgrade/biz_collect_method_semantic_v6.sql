-- ============================================================================
-- 统一 biz_product.collect_method 语义为「收款方式」（v6，方案 A）
--
-- 背景见 doc/collect_method-语义冲突排查-2026-08-27.md：
--   PRD 里收款方式（HEADQUARTERS/STORE）和券码类型（PLATFORM/THIRD_PARTY/
--   MERCHANT_OWN）本是两个字段，4e071924 建列时把后者的取值和 comment 挂到了
--   名为 collect_method（收款方式）的列上 —— 名字取前者、语义写后者，
--   后续开发各自按名字和 comment 理解，分叉成三套值。
--
--   券码类型已由 biz_product_ext.code_type 独立承接（415 行全有值），
--   所以这列上的「券码类型」comment 现在是重复定义，必须清掉。
--
-- 取值统一用 HEAD / STORE 而不是 PRD 的 HEADQUARTERS：
--   仓内已有 2 条 HEAD，且 create.vue / detail.vue 都用 HEAD，
--   改成 HEADQUARTERS 要动 3 个文件却没有任何收益。
--
-- 存量归一（229 条 PLATFORM 全是 DDL DEFAULT 兜底，无一条是用户选的）：
--   按所属商户的 biz_merchant.pay_mode 推导 —— 这才是真正决定收款归属的字段
--   （0 商户自有商户号 / 1 平台统一收款）。当前两个商户都是 0，
--   在「一个商户一套支付配置」的形态下等价于总部统一收款，故一律落 HEAD。
--   等真出现连锁分店独立收款（门店各自的商户号）再引入 STORE。
--
-- 安全性：全仓 grep 确认无任何业务代码读这一列（ProductValidator 无校验、
--   顾客端 wxml 从不渲染），改取值不会破坏现有逻辑。
--
-- 导入：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_collect_method_semantic_v6.sql
-- 幂等：可重复执行
-- ============================================================================

-- 1) 改 comment + DEFAULT。
--    MODIFY COLUMN 本身幂等（重复执行结果一致），不需要先探测。
ALTER TABLE biz_product
  MODIFY COLUMN collect_method varchar(20) DEFAULT 'HEAD'
  COMMENT '收款方式 HEAD总部统一收款/STORE门店独立收款（取值以此为准；旧值 PLATFORM 是历史 comment 写错留下的券码类型语义，券码类型见 biz_product_ext.code_type）';

-- 2) 存量归一：把券码类型语义的旧值按商户 pay_mode 推导成收款方式语义。
--    只动这 3 个旧值，不碰已经正确的 HEAD/STORE（幂等的关键）。
UPDATE biz_product p
  LEFT JOIN biz_merchant m ON m.merchant_id = p.merchant_id
   SET p.collect_method = CASE
         -- pay_mode=1 平台统一收款 → 总部收款
         WHEN m.pay_mode = '1' THEN 'HEAD'
         -- pay_mode=0 商户自有商户号 → 当前形态下也是总部统一收款
         -- （门店各自持商户号才算 STORE，现在没有这种数据）
         ELSE 'HEAD'
       END
 WHERE p.collect_method IN ('PLATFORM', 'THIRD_PARTY', 'MERCHANT_OWN');

-- 3) 空值兜底：DEFAULT 只在 insert 不带该列时生效，历史上可能有显式写 null 的
UPDATE biz_product SET collect_method = 'HEAD'
 WHERE collect_method IS NULL OR collect_method = '';

-- 4) 校验
SELECT collect_method, COUNT(*) AS cnt
  FROM biz_product GROUP BY collect_method ORDER BY cnt DESC;

SELECT CONCAT('残留旧语义取值（应为 0）：', COUNT(*)) AS result
  FROM biz_product WHERE collect_method IN ('PLATFORM', 'THIRD_PARTY', 'MERCHANT_OWN');
