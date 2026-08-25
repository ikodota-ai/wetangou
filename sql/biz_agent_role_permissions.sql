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

-- 2) 缓存处理
-- 无需清 Redis：sys_menu 不走缓存，getRouters 每次实时查库。
-- 改动 sys_role_menu 后，已登录账号的权限集合存在 login_tokens 里不会自动刷新，
-- 让相关账号重新登录即可；要手工清只删登录态前缀，切勿 flushdb（生产 Redis 与其它业务共用）：
--   redis-cli -n 3 --scan --pattern 'login_tokens:*' | xargs -r -n 200 redis-cli -n 3 del
