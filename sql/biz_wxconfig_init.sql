-- 微信配置初始值（首次部署时执行，菜单及已有值会跳过）
-- 行为：INSERT IGNORE，已存在则不覆盖（管理员后续在后台改）
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
