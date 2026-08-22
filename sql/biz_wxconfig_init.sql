-- 微信配置初始值（首次部署时执行，菜单及已有值会跳过）
-- 行为：INSERT IGNORE，已存在则不覆盖（管理员后续在后台改）

-- 前置（2026-08-22 修）：RuoYi 原生 sys_config 的 config_key 上**没有唯一索引**，
-- 所以下面的 INSERT IGNORE 形同虚设 —— biz_tenant_upgrade.sql 和本脚本会各插一份
-- wx.miniapp.appId / wx.miniapp.secret，重复后
-- `(select config_value from sys_config where config_key='wx.miniapp.appId')`
-- 这类子查询会报 ERROR 1242 Subquery returns more than 1 row。
-- 这里先去重（保留最小 config_id），再补唯一索引，让 INSERT IGNORE 真正生效。
DELETE c1 FROM sys_config c1
JOIN (
  SELECT config_key, MIN(config_id) AS keep_id
  FROM sys_config GROUP BY config_key HAVING COUNT(*) > 1
) d ON c1.config_key = d.config_key AND c1.config_id <> d.keep_id;

SET @sql := (
  SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.statistics
           WHERE table_schema = DATABASE() AND table_name = 'sys_config'
             AND index_name = 'uk_sys_config_key'),
    'SELECT ''uk_sys_config_key already exists'' AS msg',
    'ALTER TABLE sys_config ADD UNIQUE KEY uk_sys_config_key (config_key)'
  )
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

insert ignore into sys_config (config_name, config_key, config_value, config_type, create_by, create_time, remark)
values
('小程序AppId',           'wx.miniapp.appId',         'wx08075ce2ff0d153e',           'N', 'admin', sysdate(), '微信配置'),
('小程序AppSecret',        'wx.miniapp.secret',        'c7a8bc9b02bfe0e3a56236961c8fd4da', 'N', 'admin', sysdate(), '微信配置'),
('小程序mock登录开关',     'wx.miniapp.mockEnabled',   'false',                         'N', 'admin', sysdate(), '微信配置'),
('微信支付商户号',         'wx.pay.mchId',             '',                              'N', 'admin', sysdate(), '微信配置'),
('微信支付AppId',          'wx.pay.appId',             '',                              'N', 'admin', sysdate(), '微信配置'),
('微信支付证书序列号',     'wx.pay.certSerialNo',      '',                              'N', 'admin', sysdate(), '微信配置'),
('微信支付私钥路径',       'wx.pay.privateKeyPath',    '',                              'N', 'admin', sysdate(), '微信配置'),
('微信支付APIv3密钥',      'wx.pay.apiV3Key',          '',                              'N', 'admin', sysdate(), '微信配置'),
('微信支付回调地址',       'wx.pay.notifyUrl',         'https://your-domain.com/api/pay/notify', 'N', 'admin', sysdate(), '微信配置'),
('微信支付mock开关',       'wx.pay.mockEnabled',       'false',                          'N', 'admin', sysdate(), '微信配置');
