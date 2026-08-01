-- 演示种子数据
DELETE FROM biz_store WHERE store_id IN (100,101);
INSERT INTO biz_store (store_id,store_name,logo,province,city,district,address,longitude,latitude,phone,service_phone,business_hours,intro,sort,status,create_by,create_time)
VALUES
(100,'洞天团购·旗舰店','','广东省','深圳市','南山区','科技园中区科苑路15号',113.947,22.531,'0755-88888888','0755-88888888','10:00-22:00','旗舰门店，环境优雅',1,'0','admin',sysdate()),
(101,'洞天团购·万象城店','','广东省','深圳市','罗湖区','宝安南路1881号万象城L3',114.121,22.545,'0755-66666666','0755-66666666','10:00-22:30','商圈核心，交通便利',2,'0','admin',sysdate());

DELETE FROM biz_category WHERE category_id IN (100,101,102);
INSERT INTO biz_category (category_id,store_id,category_name,sort,status,create_by,create_time) VALUES
(100,0,'套餐',1,'0','admin',sysdate()),
(101,0,'单品',2,'0','admin',sysdate()),
(102,0,'预约服务',3,'0','admin',sysdate());

DELETE FROM biz_product WHERE product_id IN (1000,1001,1002);
INSERT INTO biz_product (product_id,store_id,category_id,product_name,subtitle,cover,product_type,price,market_price,stock,sales,validity_days,detail,notice,sort,status,create_by,create_time) VALUES
(1000,100,100,'双人精致套餐','含主菜2份+饮品2杯','','0',128.00,268.00,100,20,30,'<p>丰盛双人套餐</p>','<p>1.提前预约；2.节假日通用</p>',1,'0','admin',sysdate()),
(1001,100,101,'招牌牛肉面','秘制汤底','','0',38.00,58.00,200,80,30,'<p>招牌面食</p>','<p>到店即食</p>',2,'0','admin',sysdate()),
(1002,101,102,'SPA理疗60分钟','专业理疗师','','2',198.00,398.00,50,10,60,'<p>舒缓SPA</p>','<p>需提前预约</p>',3,'0','admin',sysdate());

DELETE FROM biz_commission_rule WHERE rule_id IN (1);
INSERT INTO biz_commission_rule (rule_id,rule_name,store_id,level,rate,settle_days,status,create_by,create_time)
VALUES (1,'全平台一级推客10%',0,1,10.00,7,'0','admin',sysdate());

DELETE FROM biz_voucher WHERE voucher_id IN (100);
INSERT INTO biz_voucher (voucher_id,store_id,voucher_name,face_value,threshold,total,received,valid_days,status,create_by,create_time)
VALUES (100,0,'满100减20',20.00,100.00,1000,0,30,'0','admin',sysdate());

DELETE FROM biz_agreement WHERE agreement_id IN (100,101,102);
INSERT INTO biz_agreement (agreement_id,agreement_type,title,content,store_id,status,create_by,create_time) VALUES
(100,'user','用户协议','<p>欢迎使用洞天团购小程序……</p>',0,'0','admin',sysdate()),
(101,'privacy','隐私政策','<p>我们重视您的隐私……</p>',0,'0','admin',sysdate()),
(102,'distributor','推客协议','<p>推客分销规则……</p>',0,'0','admin',sysdate());
