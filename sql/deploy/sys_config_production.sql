-- ============================================================
-- 洞天团购 · 生产环境 sys_config 部署模板
-- ============================================================
-- 用途：
--   1) 多商户代发布（第三方平台）：componentAppId / Secret / Token / AesKey
--   2) 模板 + 域名：templateId / redirectDomain / apiBaseUrl
--   3) 商家 demo 小程序：miniapp.appId / miniapp.secret（如果走的是 demo 商户）
--   4) 关 mock：所有 mockEnabled 设为 false
--
-- 用法：
--   1) 把下面的 'XXX' 占位符替换成你的真实值
--   2) mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/deploy/sys_config_production.sql
--   3) 重启后端 jar 让 config 热加载（或刷新 sys_config 缓存）
--      实际 RuoYi 的 sys_config 走 Redis 缓存，修改后等几分钟或重启即可
--
-- 风险：
--   - 误改 miniapp.appId 会让所有会员登录失败
--   - 误改 componentAppId 会让所有代发布/授权失效
--   - 强烈建议执行前备份 sys_config 表
-- ============================================================

-- ----------------------------
-- 0. 备份原配置（强烈建议）
-- ----------------------------
-- CREATE TABLE sys_config_backup_2026XXXX AS
-- SELECT * FROM sys_config
-- WHERE config_key IN (
--   'wx.miniapp.appId','wx.miniapp.secret','wx.miniapp.mockEnabled',
--   'wx.open.componentAppId','wx.open.componentSecret','wx.open.componentToken',
--   'wx.open.componentAesKey','wx.open.templateId','wx.open.redirectDomain',
--   'wx.open.apiBaseUrl','wx.pay.mockEnabled'
-- );

-- ----------------------------
-- 1. 多商户代发布（第三方平台）核心配置
-- ----------------------------
-- 从微信开放平台后台获取：https://open.weixin.qq.com/
UPDATE sys_config SET config_value = 'wxXXXXXXXXXXXXXXXX' WHERE config_key = 'wx.open.componentAppId';
UPDATE sys_config SET config_value = 'XXXXXXXXXXXXXXXXXXXXXXXX' WHERE config_key = 'wx.open.componentSecret';
-- 消息校验 Token：自己在开放平台后台填一个 32 位字符串，平台和这里必须一致
UPDATE sys_config SET config_value = 'your_token_32_chars_xxxxxxxxxxxx' WHERE config_key = 'wx.open.componentToken';
-- 消息加密 EncodingAesKey：43 位字符串，开放平台后台生成
UPDATE sys_config SET config_value = 'your_aes_key_43_chars_xxxxxxxxxxxxxxxxxxxxx' WHERE config_key = 'wx.open.componentAesKey';
-- 代码模板 ID：上传 miniprogram7 代码包后在开放平台「代码管理」获得
UPDATE sys_config SET config_value = 'template_id_number' WHERE config_key = 'wx.open.templateId';
-- 授权回调域名：商户扫码授权后微信回调的域名（必须 HTTPS，已备案）
UPDATE sys_config SET config_value = 'https://platform.你的域名.com' WHERE config_key = 'wx.open.redirectDomain';
-- API 域名：商户小程序运行时调用的后端地址（必须 HTTPS）
UPDATE sys_config SET config_value = 'https://api.你的域名.com' WHERE config_key = 'wx.open.apiBaseUrl';

-- ----------------------------
-- 2. 平台自有 demo 小程序（如果暂时只有一个 demo 商家）
-- ----------------------------
-- 实际多商户场景下，每个商户的 appid 存在 biz_merchant.appid
-- 这里配置的是「平台自有」的 appid，作为开发期 fallback
UPDATE sys_config SET config_value = 'wx9e147c4e2151b123' WHERE config_key = 'wx.miniapp.appId';
UPDATE sys_config SET config_value = '2e58986bb6c994c0e7a23e7bab24b218' WHERE config_key = 'wx.miniapp.secret';

-- ----------------------------
-- 3. 关闭所有 mock（生产必做）
-- ----------------------------
UPDATE sys_config SET config_value = 'false' WHERE config_key = 'wx.miniapp.mockEnabled';
UPDATE sys_config SET config_value = 'false' WHERE config_key = 'wx.pay.mockEnabled';

-- ----------------------------
-- 4. 验证（执行后看结果）
-- ----------------------------
SELECT config_key, config_value
FROM sys_config
WHERE config_key IN (
  'wx.miniapp.appId','wx.miniapp.secret','wx.miniapp.mockEnabled',
  'wx.open.componentAppId','wx.open.componentSecret','wx.open.componentToken',
  'wx.open.componentAesKey','wx.open.templateId','wx.open.redirectDomain',
  'wx.open.apiBaseUrl','wx.pay.mockEnabled'
)
ORDER BY config_id;
