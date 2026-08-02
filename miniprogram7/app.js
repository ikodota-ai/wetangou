// app.js 洞天团购小程序（miniprogram7）入口
const { api, toFullUrl, mockEnabled } = require('./utils/request.js');

// 显式 require 一遍关键 page 文件，避免「代码依赖分析」误判孤立文件
// 微信开发者工具 2.01+ 引入了「过滤无依赖文件」开关：page 文件如果在 app.json
// 里登记但没有任何 JS require 它，会被静态扫描判定为孤立文件并从构建中剔除，
// 表现就是运行时 MiniProgramError: 已被代码依赖分析忽略。
require('./pages/order/detail/index.js');
require('./pages/order/list/index.js');
require('./pages/order/submit/index.js');
require('./pages/goods/detail/index.js');
require('./pages/booking/detail/index.js');
require('./pages/staff/login/index.js');
require('./pages/staff/home/index.js');
require('./pages/staff/verify/index.js');
require('./pages/staff/bill/index.js');
require('./pages/staff/booking/index.js');
require('./pages/staff/order/index.js');
require('./pages/staff/me/index.js');
require('./pages/staff/history/index.js');

App({
  globalData: {
    // 位置/门店
    location: null,
    stores: [],
    store: null,
    // 商品
    goods: [],
    currentProduct: null,
    baseUrl: "http://localhost:8080",
    // 会员
    user: {
      memberId: null,
      openid: null,
      nickName: '',
      avatarUrl: '',
      phone: '',
      token: '',
      logged: false
    },
    shareDistributorId: null,
    inviteBy: null
  },
  mockEnabled: mockEnabled,
  api,
  toFullUrl,
  /**
   * 选择最近门店（小程序入口会调用）
   * 流程：wx.getLocation 拿经纬度 → 调 /api/store/nearest 由服务端按距离排序
   * 如果用户拒绝授权位置，则默认选该商户第一个门店
   */
  pickNearestStore(callback) {
    const finish = (s) => {
      if (s) {
        this.globalData.store = s;
        this.globalData.stores = [s];
        this.globalData.location = { lat: s.latitude, lng: s.longitude };
      }
      callback && callback(s);
    };
    wx.getLocation({
      type: 'gcj02',
      success: (loc) => {
        const { latitude, longitude } = loc;
        this.globalData.location = { lat: latitude, lng: longitude };
        api.storeNearest({ lat: latitude, lng: longitude, limit: 5 }).then((res) => {
          const rows = (res && (res.rows || res.data || res)) || [];
          const nearest = Array.isArray(rows) && rows.length ? rows[0] : null;
          if (nearest) return finish(nearest);
          // 没有按坐标找到，就退回到该商户第一个门店
          api.storeList({ page: 1, pageSize: 1 }).then((res2) => {
            const r2 = (res2 && (res2.rows || res2.data || res2)) || [];
            finish(Array.isArray(r2) && r2.length ? r2[0] : null);
          }).catch(() => finish(null));
        }).catch(() => finish(null));
      },
      fail: () => {
        // 拒绝授权位置：直接取第一个门店
        api.storeList({ page: 1, pageSize: 1 }).then((res) => {
          const rows = (res && (res.rows || res.data || res)) || [];
          finish(Array.isArray(rows) && rows.length ? rows[0] : null);
        }).catch(() => finish(null));
      }
    });
  },
  // 加载商品
  loadGoods(storeId) {
    return new Promise((resolve, reject) => {
      if (this.globalData.goods.length) return resolve(this.globalData.goods);
      api.productList({ storeId }).then((res) => {
        const rows = (res && (res.rows || res.data || res)) || [];
        if (Array.isArray(rows) && rows.length) {
          this.globalData.goods = rows.map((p) => ({
            productId: p.productId || p.id,
            name: p.productName || p.name,
            productName: p.productName || p.name,
            price: p.price != null ? String(p.price) : '0.00',
            marketPrice: p.marketPrice != null ? String(p.marketPrice) : '',
            subtitle: p.subtitle || '',
            sold: p.sales || p.sold || 0,
            cover: p.cover ? toFullUrl(p.cover) : '/assets/img/RestaurantImg.png'
          }));
          resolve(this.globalData.goods);
        } else {
          // 商户未配商品时返回空数组，不回退到 mock 数据
          console.warn('[goods] empty from server');
          this.globalData.goods = [];
          resolve(this.globalData.goods);
        }
      }).catch((e) => {
        console.error('[goods] productList FAIL', e);
        this.globalData.goods = [];
        reject(e);
      });
    });
  },
});
