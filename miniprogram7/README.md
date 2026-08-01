# miniprogram7 · 洞天团购微信小程序（1:1 复刻版）

> 全新重建项目，1:1 复刻 `doc/prod_img/` 35 张产品截图。  
> 旧 `miniprogram6/` 保留作历史参考，不参与本项目构建。

## 一、对应 PRD
- `doc/PRD.md`：完整产品需求文档（设计令牌、信息架构、状态机、接口约定、验收清单）。

## 二、目录结构
```
miniprogram7/
├─ app.js / app.json / app.wxss
├─ sitemap.json / project.config.json / project.private.config.json
├─ assets/        # 公共资源（icon/img/avatar/tabbar 预留）
├─ components/    # 通用组件（auth-phone/share-card/error-modal/...）
├─ custom-tab-bar/# 4 项 tabBar（CSS 绘制）
├─ utils/         # request.js / mock.js / util.js / config.js
└─ pages/         # 21 业务页面（与 app.json 一一对应）
```

## 三、页面路由

| 顺序 | 页面 | 路由 |
| --- | --- | --- |
| 1 | 首页 | `pages/home/index` |
| 2 | 贴图 | `pages/album/index` |
| 3 | 预约 | `pages/booking/index` |
| 4 | 我的 | `pages/mine/index/index` |
| 5 | 登录 | `pages/login/login` |
| 6 | 预约填写 | `pages/booking/create/index` |
| 7 | 预约列表 | `pages/booking/list/index` |
| 8 | 预约详情 | `pages/booking/detail/index` |
| 9 | 会员资料 | `pages/mine/profile/index` |
| 10 | 商家地址 | `pages/store/location/index` |
| 11 | 客服电话 | `pages/store/service/index` |
| 12 | 商品详情 | `pages/goods/detail/index` |
| 13 | 分享 | `pages/goods/share/index` |
| 14 | 提交订单 | `pages/order/submit/index` |
| 15 | 订单列表 | `pages/order/list/index` |
| 16 | 买单 | `pages/pay/index/index` |
| 17 | 推客中心 | `pages/promoter/index/index` |
| 18 | 提现方式 | `pages/promoter/withdraw/index` |
| 19 | 提现记录 | `pages/promoter/records/index` |
| 20 | 用户协议 | `pages/agreement/user/index` |
| 21 | 隐私协议 | `pages/agreement/privacy/index` |

## 四、运行
1. 微信开发者工具导入 `miniprogram7/`。
2. 替换 `project.config.json` 的 `appid` 为自有 appId。
3. `utils/config.js` 中 `BASE_URL` 指向后端（RuoYi-Vue）。
4. 后端未连通时 `MOCK_ENABLED: true`，所有页面可独立预览。

## 五、PRD 验收清单
参见 `doc/PRD.md` §9，逐条勾选完成情况。

## 六、约束
- 不依赖 npm 构建；纯原生小程序。
- 设计令牌集中在 `app.wxss` 与 `app.js`。
- 所有网络请求通过 `utils/request.js`，错误统一 Toast 化。
- 401 → 自动清除 token；位置拒绝 → 默认第一家门店。
