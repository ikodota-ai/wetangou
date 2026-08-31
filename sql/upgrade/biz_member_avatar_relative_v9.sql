-- ============================================================================
-- 会员头像改存相对路径（v9）
--
-- 背景：ApiMemberController.uploadAvatar 原来把 serverConfig.getUrl() 拼出来的
-- 绝对地址写进 biz_member.avatar，而 getUrl() 取的是当次请求的 host：
--   本地跑     → http://127.0.0.1:8080/profile/avatar/...
--   内网调试   → http://172.31.26.216:8080/profile/avatar/...
-- 这类地址换台设备、换个环境全都打不开；而且小程序 <image> 不支持 http 协议，
-- 生产 https 域名下会被微信直接拦掉。
-- 用户看到的现象是「昵称能读出来、头像读不出来」—— 昵称是纯文本所以不受影响。
--
-- 代码侧已改为入库只存 /profile/avatar/... 相对路径，由前端 toFullUrl()
-- 用当前接口域名补全。本脚本把存量数据一起洗掉 host 前缀。
--
-- 导入：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/upgrade/biz_member_avatar_relative_v9.sql
-- 幂等：可重复执行（已是相对路径的行不会被匹配到）
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 洗掉 http(s)://host[:port] 前缀，只保留 /profile/... 部分
--
-- 只处理认得出 /profile/ 的行：那是后端 Constants.RESOURCE_PREFIX，
-- 能确定是本系统上传的文件。微信 CDN 头像（thirdwx.qlogo.cn 等）不能动 ——
-- 那些是外部地址，去掉 host 就彻底废了。
-- ----------------------------------------------------------------------------
update biz_member
set avatar = concat('/profile', substring_index(avatar, '/profile', -1))
where avatar regexp '^https?://'
  and avatar like '%/profile/%';

-- ----------------------------------------------------------------------------
-- 校验：应为 0 行
-- ----------------------------------------------------------------------------
select count(*) as remaining_absolute_profile_avatar
from biz_member
where avatar regexp '^https?://' and avatar like '%/profile/%';
