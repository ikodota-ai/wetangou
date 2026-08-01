-- ----------------------------
-- 首页轮播图 biz_banner
-- ----------------------------
DROP TABLE IF EXISTS biz_banner;
CREATE TABLE biz_banner (
  banner_id     BIGINT(20)      NOT NULL AUTO_INCREMENT         COMMENT 'Banner ID',
  merchant_id   BIGINT(20)      NOT NULL DEFAULT 0              COMMENT '商户ID（0=全平台）',
  title         VARCHAR(100)    DEFAULT ''                      COMMENT '标题',
  image_url     VARCHAR(500)    NOT NULL                        COMMENT '图片URL',
  link_url      VARCHAR(500)    DEFAULT NULL                    COMMENT '跳转链接',
  position      VARCHAR(32)     NOT NULL DEFAULT 'home'         COMMENT '位置（home/agent/distributor）',
  status        CHAR(1)         NOT NULL DEFAULT '0'            COMMENT '状态（0启用 1停用）',
  sort          INT(4)          NOT NULL DEFAULT 0              COMMENT '显示顺序',
  active_from   DATETIME        DEFAULT NULL                    COMMENT '生效时间',
  active_to     DATETIME        DEFAULT NULL                    COMMENT '失效时间',
  create_by     VARCHAR(64)     DEFAULT ''                      COMMENT '创建者',
  create_time   DATETIME        DEFAULT NULL                    COMMENT '创建时间',
  update_by     VARCHAR(64)     DEFAULT ''                      COMMENT '更新者',
  update_time   DATETIME        DEFAULT NULL                    COMMENT '更新时间',
  PRIMARY KEY (banner_id),
  KEY idx_merchant (merchant_id),
  KEY idx_position (position, status, sort)
) ENGINE=InnODB COMMENT = '首页轮播图';

-- 菜单 + 权限
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
VALUES ('首页轮播图', (SELECT menu_id FROM (SELECT menu_id FROM sys_menu WHERE menu_name='商城管理' LIMIT 1) t), 6, 'banner', 'biz/banner/index', 1, 0, 'C', '0', '0', 'biz:banner:list', 'picture', 'admin', NOW(), '首页轮播图管理')
ON DUPLICATE KEY UPDATE perms = VALUES(perms);

SET @pid = LAST_INSERT_ID();
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT m.menu_id, m.menu_id, 1, '', '', 1, 0, 'F', '0', '0', 'biz:banner:query',  '#', 'admin', NOW(), '查询' FROM sys_menu m WHERE m.menu_name='首页轮播图' LIMIT 1
ON DUPLICATE KEY UPDATE perms=VALUES(perms);
