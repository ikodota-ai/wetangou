// app.js 洞天团购小程序（miniprogram7）入口
const { api, toFullUrl, mockEnabled } = require('./utils/request.js');

App({
  onLaunch() {
    // 启动时解析 scene（带参进入：太阳码 scene=distributor:{merchantId}:{memberId}）
    if (this.parseInviteFromScene) this.parseInviteFromScene()
    // 启动时拉一次会员资料（如果本地有 token），让「我的」页能直接显示真实头像/昵称/手机号
    if (this.bootUser) this.bootUser()
    // 启动时拉一次商家公开信息（商家名/客服兜底），登录页/我的页/联系客服都用得到
    if (this.bootMerchant) this.bootMerchant()
  },
  /**
   * 解析太阳码 scene 里的 inviteBy：
   *   1) 冷启动：wx.getLaunchOptionsSync().query.scene
   *   2) 热启动（被扫码进入）：wx.getEnterOptionsSync() 同样读
   * 格式约定：scene=distributor:{merchantId}:{memberId}，只取后半段写到 globalData.inviteBy
   * 不会覆盖已有值（避免 A 邀请 B 扫了 B 的码，B 再扫 A 的码时 inviteBy 漂移）
   */
  parseInviteFromScene() {
    try {
      const opts = (wx.getLaunchOptionsSync && wx.getLaunchOptionsSync()) || {}
      const enter = (wx.getEnterOptionsSync && wx.getEnterOptionsSync()) || {}
      const scene = (opts.query && opts.query.scene) || (enter.query && enter.query.scene) || (opts.scene) || (enter.scene) || ''
      this._applyInviteScene(scene)
    } catch (e) {
      console.warn('[app] parseInviteFromScene FAIL', e)
    }
  },
  _applyInviteScene(scene) {
    if (!scene || typeof scene !== 'string') return
    if (this.globalData.inviteBy) return
    const m = scene.match(/^distributor:\d+:(\d+)/)
    if (m && m[1]) {
      this.globalData.inviteBy = parseInt(m[1], 10)
      try { wx.setStorageSync('inviteBy', this.globalData.inviteBy) } catch (e) {}
    }
  },
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
    inviteBy: null,
    // 当前商家公开信息（名称/logo/客服兜底/营业时间）
    merchant: { merchantId: null, merchantName: '', logo: '', servicePhone: '', serviceQrcode: '', businessHours: '', intro: '' }
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
  /**
   * 全局用户资料变更通知：所有监听 onUserUpdate 的 page 都会被同步刷新
   * 用法：app.notifyUserUpdate() 或 app.notifyUserUpdate(user)
   */
  notifyUserUpdate(user) {
    if (user) {
      this.globalData.user = Object.assign(this.globalData.user || {}, user)
    }
    const pages = getCurrentPages && getCurrentPages()
    if (!pages || !pages.length) return
    pages.forEach((p) => {
      if (typeof p.onUserUpdate === 'function') {
        try { p.onUserUpdate(this.globalData.user) } catch (e) { console.error('[app] onUserUpdate fail', e) }
      }
    })
  },

  /**
   * 应用启动时如果本地有 token，主动拉一次会员资料，
   * 把 nickName/avatarUrl/phone 同步到 globalData，让「我的」页立刻显示真实信息
   */
  bootUser() {
    const token = wx.getStorageSync && wx.getStorageSync('token')
    if (!token) return Promise.resolve()
    if (this.globalData.user && this.globalData.user.logged) return Promise.resolve()
    this.globalData.user = Object.assign(this.globalData.user || {}, {
      memberId: wx.getStorageSync('memberId') || null,
      token: token,
      logged: false
    })
    return api.getUserInfo().then((u) => {
      const m = u && (u.data || u)
      if (m && m.memberId) {
        this.globalData.user = Object.assign(this.globalData.user, {
          memberId: m.memberId,
          openid: m.openid || this.globalData.user.openid || '',
          nickName: m.nickname || m.nickName || '',
          avatarUrl: m.avatar || m.avatarUrl || '',
          phone: m.phone || '',
          logged: true
        })
        wx.setStorageSync('memberId', m.memberId)
        this.notifyUserUpdate()
      }
    }).catch((err) => {
      console.warn('[app] bootUser FAIL', err)
      if (err && (err.code === 401 || /401/.test(String(err)))) {
        wx.removeStorageSync('token')
        wx.removeStorageSync('memberId')
      }
    })
  },

  /**
   * 启动时拉取当前商家公开信息（匿名接口），写到 globalData.merchant
   * 登录页要显示商家名、联系客服要从这里读客服兜底
   */
  bootMerchant() {
    return api.merchantInfo().then((m) => {
      const data = m && (m.data || m)
      if (data && data.merchantId) {
        this.globalData.merchant = Object.assign(this.globalData.merchant, data)
      }
    }).catch((err) => {
      console.warn('[app] bootMerchant FAIL', err)
    })
  },

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
