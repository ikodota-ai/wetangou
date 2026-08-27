// app.js 洞天团购小程序（miniprogram7）入口
const { api, toFullUrl, mockEnabled } = require('./utils/request.js');

App({
  onLaunch() {
    // 启动期回填 baseUrl，仅用于日志与页面调试展示；真正发请求的地址由
    // utils/request.js 的 probeBaseUrl() 探测结果决定（换网络时能自愈）。
    // 这里不再硬编码 IP：唯一事实来源是 utils/config.js，避免两处 IP 漂移。
    try {
      var cfg = require('./utils/config.js')
      this.globalData.baseUrl = cfg.BASE_URL || cfg.BASE_URL_DEFAULT || ''
      console.log('[app] onLaunch baseUrl =', this.globalData.baseUrl)
    } catch (e) {
      this.globalData.baseUrl = ''
    }
    // 启动时解析 scene（带参进入：太阳码 scene=distributor:{merchantId}:{memberId}）
    if (this.parseInviteFromScene) this.parseInviteFromScene()
    // 启动时拉一次会员资料（如果本地有 token），让「我的」页能直接显示真实头像/昵称/手机号
    if (this.bootUser) this.bootUser()
    // 启动时拉一次商家公开信息（商家名/客服兜底），登录页/我的页/联系客服都用得到
    if (this.bootMerchant) this.bootMerchant()
    // 启动时主动预加载默认门店到 globalData.store/stores（不依赖位置授权）：
    //   1) 用上一次缓存的 storeId 直接拉详情
    //   2) 否则按商户取第一个门店
    //   目的：进入任意页面（不一定是首页）都能直接读到门店，避免空 store 阻塞下单/买单/预约等流程
    this.bootDefaultStore()
    // 冷启动有 verify scene → 直接跳员工核销页
    if (this._pendingVerifyScene) {
      setTimeout(() => this.consumeVerifyScene(), 200)
    }
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
    // 太阳码 scene 格式：
    //   distributor:{merchantId}:{memberId}  → 推客邀请
    //   verify:{orderId}:{code}              → 订单核销（员工扫会员太阳码）
    if (scene.indexOf('verify:') === 0) {
      // 写一个一次性 token，merchant/verify onLoad 优先读 _verifySceneToken
      try { wx.setStorageSync('_verifySceneToken', scene) } catch (e) {}
      // 热启动场景：app onShow 阶段调用方跳页
      this._pendingVerifyScene = scene
      return
    }
    if (this.globalData.inviteBy) return
    const m = scene.match(/^distributor:\d+:(\d+)/)
    if (m && m[1]) {
      this.globalData.inviteBy = parseInt(m[1], 10)
      try { wx.setStorageSync('inviteBy', this.globalData.inviteBy) } catch (e) {}
    }
  },
  /**
   * 消费一次性 verify scene → 跳员工核销页
   *  - 在 onShow / 业务页 onShow 调用一次
   *  - 没有就 return
   */
  consumeVerifyScene() {
    const scene = this._pendingVerifyScene || wx.getStorageSync('_verifySceneToken') || ''
    if (!scene || scene.indexOf('verify:') !== 0) return
    // parse: verify:{orderId}:{code}
    const parts = scene.split(':')
    if (parts.length < 3) return
    const code = parts.slice(2).join(':')
    this._pendingVerifyScene = ''
    try { wx.removeStorageSync('_verifySceneToken') } catch (e) {}
    // 跳员工核销页（code 已包含完整信息，sid 留空由员工端按当前门店核销）
    wx.redirectTo({
      url: '/pages/merchant/verify/index?code=' + encodeURIComponent(code)
    })
  },
  /**
   * 退出登录：清掉 token + memberInfo + staffInfo + globalData 缓存
   *  - 兼容普通会员（仅清 token+user）和员工/商家（再清 staffUser）
   *  - 不在这里调 reLaunch（让调用方决定跳哪里）
   */
  logout() {
    try { wx.removeStorageSync('token') } catch (e) {}
    try { wx.removeStorageSync('memberTokenBackup') } catch (e) {}
    try { wx.removeStorageSync('staffToken') } catch (e) {}
    // 双身份（会员/商家）会话一并清，否则退出后仍能免密切回商家版
    try { wx.removeStorageSync('memberToken') } catch (e) {}
    try { wx.removeStorageSync('currentIdentity') } catch (e) {}
    try { wx.removeStorageSync('hasStaffAccount') } catch (e) {}
    try { wx.removeStorageSync('staffUser') } catch (e) {}
    try { wx.removeStorageSync('staffInfo') } catch (e) {}
    try { wx.removeStorageSync('inviteBy') } catch (e) {}
    try { wx.removeStorageSync('_verifySceneToken') } catch (e) {}
    // globalData 复位
    this.globalData = this.globalData || {}
    this.globalData.user = { memberId: null, openid: null, nickName: '', avatarUrl: '', phone: '', token: '', logged: false }
    this.globalData.staff = null
    this.globalData.inviteBy = null
    this.globalData._pendingVerifyScene = ''
    // 通知页面刷新（如 mine 页 logged 状态）
    if (this.notifyUserUpdate) this.notifyUserUpdate()
  },

  globalData: {
    // 位置/门店
    location: null,
    stores: [],
    store: null,
    // 商品
    goods: [],
    currentProduct: null,
    baseUrl: '', // onLaunch 时根据 ext.json / 默认值填充
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
   * 选择门店（小程序入口会调用）
   * 策略：「懒加载 + 静默 fuzzy」取位
   *
   *   A) 同步占位（立即 callback，**不**等位置）：
   *      1) globalData.store 已有 → 直接用
   *      2) wx.storage.lastStoreId → storeDetail 还原
   *      3) 都没有 → storeList 拿第一个
   *
   *   B) 懒加载取位（异步，**只在需要时**才发）：
   *      4) 如果 globalData.location 已有（之前 fuzzy 拿过）→ 直接用，调 storeNearest
   *      5) 如果 wx.storage.lastUserLocation 有缓存 → 还原 + 调 storeNearest
   *      6) 都没有 → 静默调 wx.getFuzzyLocation（用户已授权时不弹；首次未授权弹一次系统框）
   *      7) 拿到位置 → 持久化 + 调 storeNearest → 升级 store
   *      8) fuzzy fail（用户拒绝 / 系统未授权）→ 静默，保留同步占位的店
   *
   * force=true 时跳过缓存直接 storeList（页面下拉刷新用）
   */
  /**
   * 启动时拉商家公开信息到 globalData.merchant（店名/logo/客服/营业时间）
   * 失败仅 log，UI 走「默认」文案
   */
  bootMerchant() {
    try {
      api.merchantInfo().then((res) => {
        const d = (res && (res.data || res)) || {}
        if (d && d.merchantId) {
          this.globalData.merchant = Object.assign({}, this.globalData.merchant || {}, d)
          // 拿到 merchantId 后立即预拉跨店自取商品
          this.loadAllPickupGoods()
        }
      }).catch((e) => console.warn('[app] bootMerchant FAIL', e))
    } catch (e) {
      console.warn('[app] bootMerchant SYNC FAIL', e)
    }
  },
  /**
   * 启动时拉会员资料（如已登录），让「我的」页直接显示真实头像/昵称
   */
  bootUser() {
    try {
      const token = wx.getStorageSync('token')
      if (!token) return
      api.getUserInfo().then((res) => {
        const d = (res && (res.data || res)) || {}
        if (d && d.memberId) {
          this.globalData.user = Object.assign({}, this.globalData.user || {}, d, {
            logged: true,
            token: token
          })
          try { this.notifyUserUpdate && this.notifyUserUpdate(this.globalData.user) } catch (e) {}
        }
      }).catch((e) => console.warn('[app] bootUser FAIL', e))
    } catch (e) {
      console.warn('[app] bootUser SYNC FAIL', e)
    }
  },
  /**
   * 启动时静默预加载默认门店到 globalData.store（不弹位置授权，不阻塞）
   * 失败也无所谓：业务页面有自带的降级（取第一个店）
   */
  bootDefaultStore() {
    try {
      this.pickNearestStore(() => {}, { silent: true })
    } catch (e) {
      console.warn('[app] bootDefaultStore FAIL', e)
    }
  },
  pickNearestStore(callback, opts) {
    const useStore = (s, source) => {
      if (!s || !s.storeId) {
        if (source === 'sync') callback && callback(null);
        return;
      }
      const prev = this.globalData.store
      const changed = !prev || prev.storeId !== s.storeId || prev.latitude !== s.latitude
      this.globalData.store = s
      this.globalData.stores = [s]
      try { wx.setStorageSync('lastStoreId', s.storeId) } catch (e) {}
      this.loadGoods(s.storeId).catch(() => {})
      console.log('[pickNearestStore] source=' + source + ' storeId=' + s.storeId + ' name=' + (s.storeName || s.name || ''))
      if (changed) callback && callback(s)
    }
    const fetchList = (src) => api.storeList({ page: 1, pageSize: 1 }).then((res) => {
      const rows = (res && (res.rows || res.data || res)) || []
      useStore(Array.isArray(rows) && rows.length ? rows[0] : null, src)
    }).catch(() => useStore(null, src + '_fail'))
    const fetchDetail = (id, src) => api.storeDetail(id).then((res) => {
      const d = (res && (res.data || res)) || null
      if (d && d.storeId) useStore(d, src + '_hit')
      else fetchList(src + '_empty')
    }).catch(() => fetchList(src + '_fail'))

    // 静默取位：用户已授权时不再弹，未授权时弹一次（之后不再弹）
    const _reqLoc = function (cb) {
      if (typeof wx.getFuzzyLocation === 'function') {
        wx.getFuzzyLocation({
          type: 'gcj02',
          success: cb,
          fail: function () {
            // fuzzy 失败：fallback 一次 getLocation
            try {
              wx.getLocation({
                type: 'gcj02',
                success: cb,
                fail: function () { cb(null) }
              })
            } catch (e) {
              cb(null)
            }
          }
        })
      } else {
        try {
          wx.getLocation({
            type: 'gcj02',
            success: cb,
            fail: function () { cb(null) }
          })
        } catch (e) {
          cb(null)
        }
      }
    }

    // 还原 storage 里的 lastUserLocation
    if (!this.globalData.location) {
      const lastLoc = wx.getStorageSync && wx.getStorageSync('lastUserLocation')
      if (lastLoc && Number.isFinite(lastLoc.lat) && Number.isFinite(lastLoc.lng)) {
        this.globalData.location = { lat: lastLoc.lat, lng: lastLoc.lng }
      }
    }

    // 异步取位 + 查最近（懒加载：仅在 location 还没拿到时才调）
    const tryLazyLoc = () => {
      const loc = this.globalData.location
      if (loc && Number.isFinite(loc.lat) && Number.isFinite(loc.lng)) {
        // 已有位置 → 直接调 nearest
        api.storeNearest({ latitude: loc.lat, longitude: loc.lng, limit: 5 }).then((res) => {
          const rows = (res && (res.rows || res.data || res)) || []
          const nearest = Array.isArray(rows) && rows.length ? rows[0] : null
          if (nearest) useStore(nearest, 'nearest')
          // 没找到：保留同步占位的店
        }).catch(() => {})  // 失败：静默
        return
      }
      // 缓存全空 → 静默 fuzzy
      try {
        _reqLoc((newLoc) => {
          if (!newLoc) return  // 用户拒绝 / 系统未授权 → 静默
          const { latitude, longitude } = newLoc
          this.globalData.location = { lat: latitude, lng: longitude }
          try { wx.setStorageSync('lastUserLocation', { lat: latitude, lng: longitude, ts: Date.now() }) } catch (e) {}
          api.storeNearest({ latitude, longitude, limit: 5 }).then((res) => {
            const rows = (res && (res.rows || res.data || res)) || []
            const nearest = Array.isArray(rows) && rows.length ? rows[0] : null
            if (nearest) useStore(nearest, 'nearest')
          }).catch((e) => {
            // nearest 失败时 fallback 到 storeList（避免完全没有门店）
            console.warn('[pickNearestStore] nearest FAIL, fallback to list', e)
            api.storeList({ page: 1, pageSize: 1 }).then((r2) => {
              const rs = (r2 && (r2.rows || r2.data || r2)) || []
              const fb = Array.isArray(rs) && rs.length ? rs[0] : null
              if (fb) useStore(fb, 'nearest_fail_fallback')
            }).catch(() => {})
          })
        })
      } catch (e) {
        // getFuzzyLocation 抛错（极少见）→ 静默
      }
    }

    // force=true 模式：跳过缓存直接 list
    if (opts && opts.force) {
      fetchList('list_force')
      return
    }
    // 同步占位
    const cached = this.globalData && this.globalData.store
    if (cached && cached.storeId) {
      useStore(cached, 'globalData_placeholder')
      tryLazyLoc()
      return
    }
    const cachedId = wx.getStorageSync && wx.getStorageSync('lastStoreId')
    if (cachedId) {
      fetchDetail(cachedId, 'storage_placeholder')
      tryLazyLoc()
      return
    }
    // 首启无缓存：先 list 拿一个
    fetchList('list_placeholder')
    tryLazyLoc()
  },
  /**
   * 商品列表卡片上那行小字。
   *
   * 原先 home/index.wxml 写死「购买后365天内可用｜免预约」—— 有效期是每个商品
   * 自己的 validity_days（后台可填 30/90/365...），免不免预约取决于 type_code
   * 是不是 BOOKING，两个都写死等于对所有商品撒谎。
   * 优先用运营自己填的 subtitle；没填才按真实字段拼。
   */
  buildGoodsDesc(p) {
    if (p && p.subtitle) return p.subtitle
    const parts = []
    const days = p && p.validityDays
    if (days) parts.push('购买后' + days + '天内可用')
    const tc = (p && p.typeCode) || ''
    if (tc === 'BOOKING') {
      parts.push('需预约')
    } else if (tc) {
      parts.push('免预约')
    }
    return parts.join('｜')
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
            typeCode: p.typeCode || '',
            validityDays: p.validityDays || null,
            desc: this.buildGoodsDesc(p),
            sold: p.sales || p.sold || 0,
            cover: p.cover ? toFullUrl(p.cover) : '/assets/img/RestaurantImg.png'
          }));
          // 刷新当前在场的 home 页 goods 列表（pickNearestStore 同步 callback 时 goods 还是空）
          this._refreshHomeGoods()
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
  },
  /**
   * 加载"到店自取"商品（跨店，按 merchantId 拉取，不绑 storeId）
   * 失败返回空数组（不抛错），UI 走「暂无商品」空态
   */
  loadAllPickupGoods() {
    return new Promise((resolve) => {
      const merchant = (this.globalData && this.globalData.merchant) || {}
      const mid = merchant.merchantId
      if (!mid) { resolve([]); return }
      api.productList({ merchantId: mid, page: 1, pageSize: 20 }).then((res) => {
        const rows = (res && (res.rows || res.data || res)) || []
        const list = Array.isArray(rows) ? rows.map((p) => ({
          productId: p.productId || p.id,
          name: p.productName || p.name,
          productName: p.productName || p.name,
          price: p.price != null ? String(p.price) : '0.00',
          marketPrice: p.marketPrice != null ? String(p.marketPrice) : '',
          subtitle: p.subtitle || '',
          typeCode: p.typeCode || '',
          validityDays: p.validityDays || null,
          desc: this.buildGoodsDesc(p),
          sold: p.sales || p.sold || 0,
          cover: p.cover ? toFullUrl(p.cover) : '/assets/img/RestaurantImg.png'
        })) : []
        this.globalData.goods = list
        this._refreshHomeGoods()
        resolve(list)
      }).catch(() => resolve([]))
    })
  },
  _refreshHomeGoods() {
    try {
      const pages = getCurrentPages && getCurrentPages()
      if (!pages || !pages.length) return
      const home = pages.find((p) => p && p.route === 'pages/home/index')
      if (home && typeof home.setData === 'function') {
        home.setData({ goods: this.globalData.goods })
      }
    } catch (e) {}
  }
});
