-- ----------------------------
-- 预约时段容量参数
-- 小程序预约页的可选时段由 GET /api/booking/slots 按门店营业时间切分，
-- 单时段可接受的预约人数上限由本参数控制，未配置时代码内默认 10 人。
-- 幂等：已存在则不重复插入（sys_config 无 config_key 唯一索引，故用 NOT EXISTS）
-- ----------------------------
insert into sys_config (config_name, config_key, config_value, config_type, create_by, create_time, remark)
select '预约单时段人数上限', 'biz.booking.slotLimit', '10', 'Y', 'admin', sysdate(), '在线预约每个时段可接受的总人数，超出后该时段显示已约满'
from dual
where not exists (select 1 from sys_config where config_key = 'biz.booking.slotLimit');
