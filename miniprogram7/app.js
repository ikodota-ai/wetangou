// app.js 洞天团购小程序（miniprogram7）入口
const { api, toFullUrl, mockEnabled } = require('./utils/request.js');
const mock = require('./utils/mock.js');

// 显式 require 一遍关键 page 文件，避免「代码依赖分析」误判孤立文件
// 微信开发者工具 2.01+ 引入了「过滤无依赖文件」开关：page 文件如果在 app.json
// 里登记但没有任何 JS require 它，会被静态扫描判定为孤立文件并从构建中剔除，
// 表现就是运行时 MiniProgramError: 已被代码依赖分析忽略。
require('./pages/order/detail/index.js');
require('./pages/order/list/index.js');
require('./pages/order/submit/index.js');
require('./pages/goods/detail/index.js');
require('./pages/booking/detail/index.js');

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
    // 邀请人（扫码进入时由 scene 解析得到，登录时回传后端）
    inviter: {
      merchantId: null,
      memberId: null
    },
    // 系统
    env: 'dev',
    mockEnabled: mockEnabled
  },

  // 工具：Haversine 距离（km）
  getDistance(lat1, lng1, lat2, lng2) {
    const toRad = (d) => (d * Math.PI) / 180;
    const a = toRad(lat1) - toRad(lat2);
    const b = toRad(lng1) - toRad(lng2);
    const s = 2 * Math.asin(Math.sqrt(
      Math.pow(Math.sin(a / 2), 2) +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.pow(Math.sin(b / 2), 2)
    ));
    return Math.round(s * 6378.137 * 100) / 100;
  },

  // 通知所有页面更新用户资料
  notifyUserUpdate() {
    const pages = getCurrentPages();
    pages.forEach((p) => {
      if (typeof p.onUserUpdate === 'function') {
        try { p.onUserUpdate(this.globalData.user); } catch (e) {}
      }
    });
  },

  // 加载门店列表
  // 优先按用户经纬度调 /api/store/nearest 做「最近门店」定位；
  // 没有经纬度时退到 /api/store/list 全列表；
  // 接口通但空数据时不再回退 mock（mock 已被全局禁用，且会让示例门店混入真实商户）。
  loadStores(longitude, latitude) {
    return new Promise((resolve) => {
      if (this.globalData.stores.length) return resolve(this.globalData.stores);
      const normalize = (s) => ({
        storeId: s.storeId || s.id,
        name: s.storeName || s.name,
        storeName: s.storeName || s.name,
        subName: s.subName || '',
        hours: s.businessHours || s.hours || '',
        businessHours: s.businessHours || s.hours || '',
        address: s.address || '',
        phone: s.phone || '',
        servicePhone: s.servicePhone || s.phone || '',
        serviceQrcode: s.serviceQrcode ? toFullUrl(s.serviceQrcode) : '',
        logo: s.logo ? toFullUrl(s.logo) : '',
        intro: s.intro || '',
        services: s.services || '',
        latitude: s.latitude ? parseFloat(s.latitude) : 23.405,
        longitude: s.longitude ? parseFloat(s.longitude) : 113.227,
        distance: s.distance != null ? s.distance : null
      });
      const apply = (rows) => {
        this.globalData.stores = rows.map(normalize);
        resolve(this.globalData.stores);
      };
      const useList = () => api.storeList().then((res) => {
        const rows = (res && (res.rows || res.data || res)) || [];
        if (Array.isArray(rows) && rows.length) apply(rows);
        else { console.warn('[stores] empty from server'); this.globalData.stores = []; resolve(this.globalData.stores); }
      });
      if (longitude != null && latitude != null) {
        api.storeNearest({ longitude, latitude, limit: 10 }).then((res) => {
          const rows = (res && (res.rows || res.data || res)) || [];
          if (Array.isArray(rows) && rows.length) apply(rows);
          else useList();
        }).catch(() => useList());
      } else {
        useList();
      }
    });
  },

  // 加载商品
  loadGoods(storeId) {
    return new Promise((resolve) => {
      if (this.globalData.goods.length) return resolve(this.globalData.goods);
      const applyMock = () => {
        this.globalData.goods = mock.goods.map((g) => ({ ...g, cover: g.cover }));
        resolve(this.globalData.goods);
      };
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
          // 同上：商户未配商品时展示空列表，不用示例商品充数
          console.warn('[goods] empty from server');
          this.globalData.goods = [];
          resolve(this.globalData.goods);
        }
      }).catch((e) => { if (MOCK_ENABLED) applyMock('error: ' + (e && e.errMsg || e)); else throw e; });
    });
  },

  // 选最近门店（先用 wx.getLocation 拿坐标，再调 /api/store/nearest 走服务端排序）
  pickNearestStore(callback) {
    wx.getLocation({
      type: 'gcj02',
      success: (res) => {
        this.globalData.location = { latitude: res.latitude, longitude: res.longitude };
        this.loadStores(res.longitude, res.latitude).then((stores) => {
          if (!stores.length) { this.globalData.store = null; return callback && callback(null); }
          const nearest = stores[0];
          if (nearest.distance != null) {
            // 服务端返回的是米，转成 km 字符串
            nearest.distance = (Math.round(nearest.distance / 100) / 10).toFixed(1) + 'km';
          } else {
            nearest.distance = '未知';
          }
          this.globalData.store = nearest;
          this.loadGoods(nearest.storeId).then(() => callback && callback(nearest));
        });
      },
      fail: () => {
        // 没有定位权限时退到全列表，按 store_id 倒序取第一个
        this.loadStores().then((stores) => {
          if (!stores.length) { this.globalData.store = null; return callback && callback(null); }
          const s = stores[0];
          s.distance = s.distance || '未知';
          this.globalData.store = s;
          this.loadGoods(s.storeId).then(() => callback && callback(s));
        });
      }
    });
  },

  // 微信登录
  wxLogin(profile, callback) {
    if (typeof profile === 'function') { callback = profile; profile = null; }
    profile = profile || {};
    wx.login({
      success: (res) => {
        if (!res || !res.code) {
          wx.showToast({ title: '微信登录失败', icon: 'none' });
          callback && callback(new Error('no code'), null);
          return;
        }
        api.login({
          code: res.code,
          nickName: profile.nickName,
          avatarUrl: profile.avatarUrl,
          inviteBy: (this.globalData.inviter && this.globalData.inviter.memberId) || undefined
        }).then((data) => {
            const token = data && (data.token || (data.data && data.data.token));
            const memberId = data && (data.memberId || (data.data && data.data.memberId));
            if (token) {
              wx.setStorageSync('token', token);
              this.globalData.user = {
                ...this.globalData.user,
                memberId,
                token,
                nickName: profile.nickName || this.globalData.user.nickName,
                avatarUrl: profile.avatarUrl || this.globalData.user.avatarUrl,
                logged: true
              };
              this.fetchProfile();
              // 已登录但登录前未携带 inviteBy（首次扫码进入新装环境），补一次回填
              const inv = this.globalData.inviter;
              if (inv && inv.memberId && inv.memberId !== memberId) {
                api.bindInvite(inv.memberId).then(() => {
                  this.globalData.inviter = { merchantId: null, memberId: null };
                }).catch(() => {});
              }
              callback && callback(null, this.globalData.user);
            } else {
              // 后端无响应/未启动
              if (MOCK_ENABLED) {
                const mockToken = 'mock-token-' + Date.now();
                wx.setStorageSync('token', mockToken);
                this.globalData.user = {
                  ...this.globalData.user,
                  memberId: this.globalData.user.memberId || 10001,
                  token: mockToken,
                  nickName: profile.nickName || this.globalData.user.nickName || '好吃嘴',
                  avatarUrl: profile.avatarUrl || this.globalData.user.avatarUrl || '/assets/avatar/default.png',
                  logged: true
                };
                callback && callback(null, this.globalData.user);
              } else {
                callback && callback(new Error('微信登录失败：后端无响应'), null);
              }
            }
          })
          .catch(() => {
            if (MOCK_ENABLED) {
              const mockToken = 'mock-token-' + Date.now();
              wx.setStorageSync('token', mockToken);
              this.globalData.user = {
                ...this.globalData.user,
                memberId: this.globalData.user.memberId || 10001,
                token: mockToken,
                nickName: profile.nickName || this.globalData.user.nickName || '好吃嘴',
                avatarUrl: profile.avatarUrl || this.globalData.user.avatarUrl || '/assets/avatar/default.png',
                logged: true
              };
              callback && callback(null, this.globalData.user);
            } else {
              callback && callback(new Error('微信登录失败：后端无响应'), null);
            }
          });
      },
      fail: (err) => {
        wx.showToast({ title: '微信登录失败', icon: 'none' });
        callback && callback(err, null);
      }
    });
  },

  // 拉会员资料
  fetchProfile() {
    const t = wx.getStorageSync('token');
    if (!t) return Promise.resolve();
    return api.getUserInfo().then((res) => {
      const d = res && (res.data || res);
      if (!d) return;
      this.globalData.user = {
        ...this.globalData.user,
        memberId: d.memberId || this.globalData.user.memberId,
        nickName: d.nickname || d.nickName || this.globalData.user.nickName,
        avatarUrl: d.avatar || d.avatarUrl || this.globalData.user.avatarUrl,
        phone: d.phone || this.globalData.user.phone,
        logged: true
      };
      this.notifyUserUpdate();
    }).catch(() => {});
  },

  // 检查登录态
  checkLogin() {
    const t = wx.getStorageSync('token');
    if (t) {
      this.globalData.user.logged = true;
      this.globalData.user.token = t;
      return true;
    }
    return false;
  },

  // 退出
  logout() {
    wx.removeStorageSync('token');
    this.globalData.user = {
      memberId: null, openid: null, nickName: '', avatarUrl: '', phone: '', token: '', logged: false
    };
    this.notifyUserUpdate();
  },

  /**
   * 解析小程序启动 / 唤起时的 scene 值
   *
   * <p>约定 scene=distributor:{merchantId}:{memberId}，用于推客邀请裂变。
   * 也兼容老的 query.inviteBy 透传。命中后写入 globalData.inviter，
   * 由 wxLogin 在登录请求里带回后端。</p>
   */
  parseInviteScene(options) {
    if (!options) return;
    let scene = options.scene;
    if (typeof scene === 'number') scene = String(scene);
    if (typeof scene !== 'string' || !scene) {
      const q = options.query || {};
      if (q.inviteBy) {
        this.globalData.inviter = {
          merchantId: q.merchantId ? Number(q.merchantId) : null,
          memberId: Number(q.inviteBy)
        };
      }
      return;
    }
    const decoded = decodeURIComponent(scene);
    const m = /^distributor:(\d+):(\d+)$/.exec(decoded);
    if (m) {
      this.globalData.inviter = { merchantId: Number(m[1]), memberId: Number(m[2]) };
    }
  },

  onShow(options) {
    // 每次回到前台都重新解析，避免从其他场景切回时丢失邀请人
    this.parseInviteScene(options);
  },

  onLaunch(options) {
    // 启动时解析 scene 中的邀请人
    this.parseInviteScene(options);
    // 启动预加载
    this.loadStores();
    if (this.checkLogin()) {
      this.fetchProfile();
    }
  }
});
