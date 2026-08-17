const app = getApp();
const { api, toFullUrl } = require('../../utils/request.js');
const { haversineKm, formatDistance } = require('../../utils/util.js');

Page({
  data: {
    statusBarHeight: 20,
    banners: [],  // 不设兜底图；后端无 banner 数据时由调用方显式报错
    store: {},
    goods: [],
    facilities: [],
    tab: 'pickup',
    showConsult: false,
    showFacility: false,
    phone: '',
    qrcode: '',
    serviceHours: '',
    isStoreService: false,
    hasStaff: false
  },
  onShow() {
    // 检测是否绑了 staff 身份（右上角可切换）
    const u = wx.getStorageSync('staffUser') || null
    this.setData({ hasStaff: !!(u && u.logged) })
  },
  _lastBannerStoreId: null,
  _bannerToastShown: false,
  _firstLoadDone: false,
  _slowTimer: null,
  onLoad() {
    // 3.5s 内还没拿到 store → 触发降级 + 主动再 fetch 一次（避免白板卡死）
    this._slowTimer = setTimeout(() => {
      if (!this.data.store || !this.data.store.storeId) {
        console.warn('[home] 3.5s 仍无 store，触发降级');
        this.setData({
          store: {
            name: '门店加载中…',
            hours: '',
            address: '',
            distanceText: '距离未知'
          }
        });
        // 主动兜底：直接调 storeList 拿一个店（不走位置），保证有真实店名
        api.storeList({ page: 1, pageSize: 1 }).then((res) => {
          const rows = (res && (res.rows || res.data || res)) || [];
          if (Array.isArray(rows) && rows.length && rows[0].storeId) {
            const viewStore = this._compatStoreView(rows[0]);
            this.setData({ store: viewStore });
          }
        }).catch(() => {});
      }
    }, 3500);
    try {
      const sys = wx.getSystemInfoSync();
      this.setData({ statusBarHeight: sys.statusBarHeight || 20 });
    } catch (e) {}
    // 始终调 pickNearestStore：
    //   - 有缓存 → 立刻 callback 渲染（占位）
    //   - 同时异步取位 + 查最近门店，nearest 拿到后 callback 升级 store
    // 两种情况都走 loadData，统一收口
    this.loadData();
  },
  onUnload() { if (this._slowTimer) { clearTimeout(this._slowTimer); this._slowTimer = null; } },
  onShow() {
    if (typeof this.getTabBar === 'function' && this.getTabBar()) {
      this.getTabBar().setData({ selected: 0 });
    }
  },
  // 把后端 store 字段转成 wxml 用的视图模型（name/hours/distanceText）
  _compatStoreView(s) {
    if (!s) return {}
    const loc = (app.globalData && app.globalData.location) || null
    let _distKm = null
    if (s.distance != null && s.distance !== '') {
      // 后端字段单位约定为米；统一转成 km 传给 formatDistance
      const d = Number(s.distance)
      _distKm = d / 1000
    } else if (loc && loc.lat != null && loc.lng != null && s.latitude != null && s.longitude != null) {
      _distKm = haversineKm(loc.lat, loc.lng, s.latitude, s.longitude)
    } else {
      // 没有位置时，距离显示 formatDistance 的 ""（wxml fallback "距离未知"）
      // 不主动取位（懒加载策略：避免频繁弹系统授权框）
    }
    return Object.assign({}, s, {
      name: s.storeName || s.name || '',
      hours: s.businessHours || s.hours || '',
      logo: s.logo ? toFullUrl(s.logo) : '',
      distanceText: formatDistance(_distKm) || '计算中…'
    })
  },

  loadData() {
    let lastStoreId = null
    app.pickNearestStore((store) => {
      if (!store) {
        console.warn('[home] pickNearestStore returned null')
        return
      }
      console.log('[home] pickNearestStore =>', JSON.stringify(store).slice(0, 300))
      // 距离计算走 _compatStoreView（包含「计算中…」占位 + 缺位置时后台异步补位）
      const viewStore = this._compatStoreView(store)
      // 客服信息：门店优先，商家兜底。
      const m = (app.globalData && app.globalData.merchant) || {}
      const _storePhone = store.servicePhone || store.phone
      const _storeQr = store.serviceQrcode
      const _storeSvcHours = store.serviceHours
      const sp = _storePhone || m.servicePhone || ''
      const sq = _storeQr || m.serviceQrcode || ''
      const sh = _storeSvcHours || m.serviceHours || m.businessHours || ''
      this.setData({
        store: viewStore,
        goods: app.globalData.goods || [],
        phone: sp,
        qrcode: sq ? toFullUrl(sq) : '',
        serviceHours: sh,
        isStoreService: !!_storePhone || !!_storeSvcHours || !!_storeQr
      })
      // 「到店自取」tab 用的是跨店商品，globalData.goods 是按 storeId 拉的，可能为空
      // 这里主动按 merchantId 再拉一次补齐（不论 pickNearestStore 有没有先填过）
      app.loadAllPickupGoods().then((list) => {
        if (Array.isArray(list) && list.length && this.data.tab === 'pickup') {
          this.setData({ goods: list })
        }
      })
      // 只在 storeId 变化时重拉 banners / facilities（占位 → 真实最近切换时才刷）
      if (store.storeId !== lastStoreId) {
        lastStoreId = store.storeId
        this._lastBannerStoreId = null
        this.loadBanners(store.storeId)
        this.loadFacilities(store.storeId)
      }
    });
  },

  // 拉后端 banner；不兜底：无数据 / 失败 / 缺 imageUrl 都视为错误并提示
  // merchantId 从 app.globalData.merchant.merchantId 取（按当前登录商户过滤）
  loadBanners(storeId) {
    const merchantId = (app.globalData && app.globalData.merchant && app.globalData.merchant.merchantId) || 0
    if (this._lastBannerStoreId === storeId) return
    this._lastBannerStoreId = storeId
    api.bannerList({ position: 'home', merchantId: merchantId }).then((res) => {
      const rows = (res && (res.data || res.rows || res)) || [];
      if (!Array.isArray(rows) || rows.length === 0) {
        throw new Error('当前商户未配置首页 banner（position=home 0 条），请在后台【门店商品 → 轮播图管理】新增')
      }
      const banners = rows
        .filter((b) => b.imageUrl)
        .map((b) => ({ id: b.bannerId, src: toFullUrl(b.imageUrl), link: b.linkUrl || '' }));
      if (banners.length === 0) {
        throw new Error('当前商户所有 banner 缺 imageUrl，请在后台【门店商品 → 轮播图管理】检查图片字段')
      }
      this._bannerToastShown = false
      this.setData({ banners });
    }).catch((err) => {
      console.error('[home] loadBanners FAIL', err)
      if (!this._bannerToastShown) {
        this._bannerToastShown = true
        wx.showToast({ title: '首页 banner 加载失败：' + ((err && (err.msg || err.message)) || '网络异常'), icon: 'none', duration: 4000 })
      }
      // 保持 banners=[]（空数组），让 swiper 显示空白以便排查
      this.setData({ banners: [] ,
  onSwitchToStaff() {
    const u = wx.getStorageSync('staffUser') || null
    if (!u || !u.logged) {
      wx.showModal({ title: '提示', content: '当前账号未绑定商家身份，可使用「更多登录方式 → 账号密码登录」', showCancel: false })
      return
    }
    wx.reLaunch({ url: '/pages/merchant/home/index' })
  }
})
    });
  },
  // 设施标签由后端翻译字典，前端不再硬编码中文
  loadFacilities(storeId) {
    api.storeServices(storeId).then((res) => {
      const rows = (res && (res.data || res)) || [];
      this.setData({ facilities: Array.isArray(rows) ? rows : [] });
    }).catch(() => {});
  },
  onBannerChange() {},
  onBannerTap(e) {
    // 跳 banner.linkUrl；没 linkUrl 就不响应点击
    const item = (e && e.currentTarget && e.currentTarget.dataset) || {};
    const link = item.link;
    if (!link) { wx.showToast({ title: '该 banner 未配置跳转链接', icon: 'none' }); return; }
    if (/^https?:\/\//.test(link)) { wx.setClipboardData({ data: link }); return; }
    wx.navigateTo({ url: link, fail: (err) => { console.error('[home] banner navigate FAIL', err); wx.showToast({ title: '跳转失败：' + (err && err.errMsg) || '', icon: 'none' }); } });
  },
  switchTab(e) { this.setData({ tab: e.currentTarget.dataset.t }); },
  goDetail(e) { wx.navigateTo({ url: '/pages/goods/detail/index?id=' + e.currentTarget.dataset.id }); },
  // 带上当前门店，买单必须落到用户实际所在门店
  goPay() {
    const id = this.data.store && this.data.store.storeId;
    wx.navigateTo({ url: '/pages/pay/index' + (id ? '?storeId=' + id : '') });
  },
  goBooking() { wx.switchTab({ url: '/pages/booking/index' }); },
  goLocation() {
    const s = this.data.store;
    wx.openLocation({
      latitude: s.latitude || 23.405,
      longitude: s.longitude || 113.227,
      name: s.name,
      address: s.address
    });
  },
  goService() {
    wx.showActionSheet({
      itemList: ['拨打电话', '在线咨询'],
      success: (res) => {
        if (res.tapIndex === 0) this.callService();
        else this.openConsult();
      }
    });
  },
  callService() {
    if (!this.data.phone) return wx.showToast({ title: '暂无客服电话', icon: 'none' });
    wx.makePhoneCall({ phoneNumber: this.data.phone });
  },
  previewQrcode() {
    if (!this.data.qrcode) return;
    wx.previewImage({ urls: [this.data.qrcode] });
  },
  goVoucher() {
    const id = this.data.store && this.data.store.storeId;
    wx.navigateTo({ url: '/pages/voucher/index/index' + (id ? '?storeId=' + id : '') });
  },
  openConsult() { this.setData({ showConsult: true }); },
  closeConsult() { this.setData({ showConsult: false }); },
  openFacility() { this.setData({ showFacility: true }); },
  closeFacility() { this.setData({ showFacility: false }); }
});
