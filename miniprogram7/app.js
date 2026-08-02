// app.js 洞天团购小程序（miniprogram7）入口
const { api, toFullUrl, mockEnabled } = require('./utils/request.js');

App({
  globalData: {
    // 位置/门店
    location: null,
    stores: [],
    store: null,
    // 商品
    goods: [],
    currentProduct: null,
    baseUrl: "http://172.31.26.216:8080",
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
   * 选出门店后顺手加载该门店的商品（保持与旧版本一致，避免首页商品列表为空）
   */
  pickNearestStore(callback) {
    const useStore = (s) => {
      if (!s) {
        callback && callback(null);
        return;
      }
      this.globalData.store = s;
      this.globalData.stores = [s];
      this.globalData.location = { lat: s.latitude, lng: s.longitude };
      // 顺手把该门店的商品加载到 globalData，供首页 / 商品详情复用
      this.loadGoods(s.storeId).finally(() => callback && callback(s));
    };
    wx.getLocation({
      type: 'gcj02',
      success: (loc) => {
        const { latitude, longitude } = loc;
        this.globalData.location = { lat: latitude, lng: longitude };
        api.storeNearest({ lat: latitude, lng: longitude, limit: 5 }).then((res) => {
          const rows = (res && (res.rows || res.data || res)) || [];
          const nearest = Array.isArray(rows) && rows.length ? rows[0] : null;
          if (nearest) return useStore(nearest);
          // 没按坐标找到，回退到该商户第一个门店
          api.storeList({ page: 1, pageSize: 1 }).then((res2) => {
            const r2 = (res2 && (res2.rows || res2.data || res2)) || [];
            useStore(Array.isArray(r2) && r2.length ? r2[0] : null);
          }).catch(() => useStore(null));
        }).catch(() => useStore(null));
      },
      fail: () => {
        // 拒绝授权位置：直接取第一个门店
        api.storeList({ page: 1, pageSize: 1 }).then((res) => {
          const rows = (res && (res.rows || res.data || res)) || [];
          useStore(Array.isArray(rows) && rows.length ? rows[0] : null);
        }).catch(() => useStore(null));
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
          // 商户未配商品时返回空数组，不回退到 mock
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
  }
});
