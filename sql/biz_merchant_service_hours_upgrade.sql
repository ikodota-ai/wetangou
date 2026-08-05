-- 商家档案：客服服务时间（弹窗显示"客服工作时间 xxx"那行）
-- biz_merchant 和 biz_store 都加；merchant 是商家级缺省，store 是门店级覆盖
ALTER TABLE biz_merchant ADD COLUMN service_hours varchar(100) DEFAULT '' COMMENT '客服服务时间' AFTER business_hours;
ALTER TABLE biz_store ADD COLUMN service_hours varchar(100) DEFAULT '' COMMENT '客服服务时间' AFTER business_hours;
