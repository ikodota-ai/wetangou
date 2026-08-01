-- ----------------------------
-- 代理商门店配额
-- ----------------------------
-- 业务规则：代理商名下所有商户的门店总数 ≤ agent.store_quota。
-- store_quota=0 表示不限制（兼容平台直营/历史数据）。
-- 已用门店数 = 实时统计 SUM(biz_store)，不入库。

CALL biz_add_column('biz_agent', 'store_quota',
  "store_quota int(11) default 0 comment '可开门店额度（0=不限）' after merchant_quota");
CALL biz_add_index('biz_agent', 'idx_store_quota', 'key idx_store_quota (store_quota)');
