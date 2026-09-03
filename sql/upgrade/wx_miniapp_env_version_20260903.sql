-- ============================================================================
-- 小程序码指向版本（wx.miniapp.envVersion）
--
-- 背景（用户实测报错）：
--   部署后 PC 后台点「员工邀请二维码」报
--   生成小程序码失败：{"errcode":40066,"errmsg":"invalid url rid:..."}
--
-- 根因不是 page 路径写错。微信 getwxacodeunlimited 不传 env_version 时按
-- "release"（线上已发布版本）处理，而该小程序**还没发布过**，根本不存在
-- release 版本，微信就返 40066 invalid url。错误码指向 url/page，极容易被
-- 误判成路径拼错或 app.json 缺页面 —— 实际 pages/merchant/scan/index 一直在
-- app.json 里，且代码早就传了 check_path=false。缺的是"已发布"这个前提。
--
-- 同一个坑还埋在 /wxa/generatescheme（店员扫桌上核销码那条链），一并接同一开关。
--
-- 取值：release=正式版(默认) / trial=体验版 / develop=开发版
-- 未发布阶段填 trial 即可扫通；上线后回到 release。
-- 留空或填了别的值 → 代码兜底成 release，保持老行为。
--
-- 导入：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/upgrade/wx_miniapp_env_version_20260903.sql
-- 幂等：可重复执行
-- ============================================================================

-- 初始值刻意给 trial：会跑这个升级脚本的环境就是"刚部署、还没发布小程序"的
-- 环境，给 release 等于装完还是扫不出码、还得再手工改一次。
insert into sys_config
  (config_name, config_key, config_value, config_type, create_by, create_time, remark)
select '小程序码指向版本', 'wx.miniapp.envVersion', 'trial', 'N', 'admin', sysdate(),
       'release=正式版 / trial=体验版 / develop=开发版；小程序未发布时必须用 trial，否则微信返 40066'
 where not exists (
   select 1 from sys_config c where c.config_key = 'wx.miniapp.envVersion'
 );

-- 历史遗留的非法值洗成 release（代码里也有兜底，这里让库里的值同样自解释）
update sys_config
   set config_value = 'release'
 where config_key = 'wx.miniapp.envVersion'
   and config_value not in ('release', 'trial', 'develop');

select concat('wx.miniapp.envVersion = ', config_value) as result
  from sys_config where config_key = 'wx.miniapp.envVersion';
