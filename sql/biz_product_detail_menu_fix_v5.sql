-- ============================================================================
-- 修 sys_menu 里「商品创建 / 商品详情」两条死菜单（v5）
--
-- 背景：v3_p2_menus_routes.sql 早就插了 2292「商品创建」和 2293「商品详情」，
--      component 分别指向 biz/product/create 和 biz/product/detail。
--      但这两条从来没生效过，原因有两个：
--
--   1) 二者都挂在 2062「商品管理」下，而 2062 的 menu_type = 'C'。
--      SysMenuServiceImpl.buildMenus 只在 UserConstants.TYPE_DIR（即 'M'）时
--      才递归 children，所以 C 类菜单的子菜单被整体丢弃 ——
--      /getRouters 实测确认返回里根本没有这两条路由。
--
--   2) 2293 的 path 写成 'detail/:productId(d+)'，正则反斜杠在写 SQL 时丢了，
--      本意是 :productId(\d+)。就算路由能下发，这个 path 也匹配不到数字 ID。
--
--   3) 2292/2293 在 sys_role_menu 里 0 条授权记录（select count(*) 实测 = 0），
--      非 admin 角色即便路由能下发也拿不到。
--
-- 结论：商品创建 / 商品详情两个页面都改由 ruoyi-ui/src/router/index.js 静态注册
--      （/product/create 和 /product/detail/:productId），不依赖 sys_menu。
--      这两条 C 类菜单记录留着只会误导后来人 —— 看到 sys_menu 里有记录，
--      以为改 path 就能生效，实际改了也不下发。所以降级为按钮级（F）权限点，
--      与 2063「商品查询」/2064「商品新增」保持同一形态。
--
-- 权限侧不需要额外补：查看态用的 biz:product:query 已由 2063 承载，
-- 且已授权给 role_id 4（代理商）和 5（商户管理员），admin 走 *:*:* 全通。
--
-- 导入：mysql --default-character-set=utf8mb4 -uroot -p ry-vue < sql/biz_product_detail_menu_fix_v5.sql
-- 幂等：可重复执行
-- ============================================================================

-- 删掉这两条误导性的 C 类菜单（它们的 component 指向的页面现由静态路由承载）。
-- 用 component 一起限定，避免误删被后人改过用途的同 id 记录。
DELETE FROM sys_role_menu WHERE menu_id IN (
    SELECT menu_id FROM (
        SELECT menu_id FROM sys_menu
         WHERE menu_id IN (2292, 2293)
           AND menu_type = 'C'
           AND component IN ('biz/product/create', 'biz/product/detail')
    ) t
);

DELETE FROM sys_menu
 WHERE menu_id IN (2292, 2293)
   AND menu_type = 'C'
   AND component IN ('biz/product/create', 'biz/product/detail');

SELECT CONCAT('剩余 2292/2293 记录数（应为 0）：', COUNT(*)) AS result
  FROM sys_menu WHERE menu_id IN (2292, 2293);
