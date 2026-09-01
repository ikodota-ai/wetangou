const app = getApp();
const { api } = require('../../utils/request.js');
const { haversineKm, formatDistance } = require('../../utils/util.js');
const { resolveContact } = require('../../utils/contact.js');

Page({
  // bookingTypes 来自后台「字典管理 → 预约类型」，不再写死一张「堂食预约」卡。
  // typesLoaded 用来区分「还没拉到」和「后台真的没配」——前者不该显示空态。
  data: { statusBarHeight: 20, store: {}, bookingTypes: [], typesLoaded: false },
  onLoad() {
    try { this.setData({ statusBarHeight: wx.getSystemInfoSync().statusBarHeight || 20 }); } catch (e) {}
    this.loadTypes();
    // 立即用缓存的 store 渲染一次（避免空窗期）
    const cached = (getApp().globalData && getApp().globalData.store) || null
    if (cached && cached.storeId) {
      this.setData({ store: this._compatStore(cached) });
    } else {
      this.setData({ _storeLoadTimedOut: false });
    }
    // 门店从占位升级成最近门店时刷新（回调现在每次都会触发，见 app.js useStore 注释）
    app.pickNearestStore((s) => {
      if (s && s.storeId) this.setData({ store: this._compatStore(s), _storeLoadTimedOut: false });
    });
    // 5 秒兜底：仍未拿到则显示重试按钮
    if (this._storeTimer) clearTimeout(this._storeTimer);
    this._storeTimer = setTimeout(() => {
      const cur = this.data.store;
      if (!cur || !cur.storeId) this.setData({ _storeLoadTimedOut: true });
    }, 5000);
  },
  onUnload() { if (this._storeTimer) { clearTimeout(this._storeTimer); this._storeTimer = null; } },

  // 预约类型：后台字典配几条就显示几张卡，顺序按字典的 dict_sort
  loadTypes() {
    api.bookingTypes().then((res) => {
      const rows = (res && (res.data || res.rows || res)) || [];
      this.setData({
        bookingTypes: Array.isArray(rows) ? rows : [],
        typesLoaded: true
      });
    }).catch((err) => {
      console.warn('[booking] loadTypes FAIL', err);
      this.setData({ bookingTypes: [], typesLoaded: true });
    });
  },

  retryStore() {
    this.setData({ _storeLoadTimedOut: false });
    app.pickNearestStore((s) => {
      if (s && s.storeId) this.setData({ store: this._compatStore(s), _storeLoadTimedOut: false });
    }, { force: true });
  },

  // 兼容后端字段：storeName → name，businessHours → hours
  //
  // 距离必须走 formatDistance，和首页保持一致：后端 distance 单位是米，
  // 原来 wxml 直接渲染 {{store.distance}}，屏幕上就是「距您1234.5678」这种裸数字。
  _compatStore(s) {
    if (!s) return {};
    const loc = (app.globalData && app.globalData.location) || null
    let _distKm = null
    if (s.distance != null && s.distance !== '') {
      _distKm = Number(s.distance) / 1000
    } else if (loc && loc.lat != null && loc.lng != null && s.latitude != null && s.longitude != null) {
      _distKm = haversineKm(loc.lat, loc.lng, s.latitude, s.longitude)
    }
    const _dist = formatDistance(_distKm)
    return Object.assign({}, s, {
      name: s.storeName || s.name || '',
      hours: s.businessHours || s.hours || '',
      address: s.address || '',
      distanceText: _dist,
      hasDistance: !!_dist
    });
  },
  onShow() {
    if (typeof this.getTabBar === 'function' && this.getTabBar()) this.getTabBar().setData({ selected: 2 });
  },
  goCreate() {
    const id = this.data.store.storeId;
    this._toCreate(id, '', '');
  },
  // 点某一类预约：把类型带过去，create 页据此落 booking_type 并显示标题
  goCreateType(e) {
    const ds = (e && e.currentTarget && e.currentTarget.dataset) || {};
    this._toCreate(this.data.store.storeId, ds.code || '', ds.name || '');
  },
  _toCreate(storeId, code, name) {
    const q = [];
    if (storeId) q.push('storeId=' + storeId);
    if (code) q.push('bookingType=' + encodeURIComponent(code));
    // 标题一起带过去，省掉 create 页再拉一次字典
    if (name) q.push('typeName=' + encodeURIComponent(name));
    wx.navigateTo({ url: '/pages/booking/create/index' + (q.length ? '?' + q.join('&') : '') });
  },
  goList() { wx.navigateTo({ url: '/pages/booking/list/index' }); },
  goHome() { wx.switchTab({ url: '/pages/home/index' }); },
  goLocation() {
    const s = this.data.store;
    if (!s.latitude || !s.longitude) return wx.showToast({ title: '暂无门店坐标', icon: 'none' });
    wx.openLocation({ latitude: s.latitude, longitude: s.longitude, name: s.name, address: s.address });
  },
  // 客服电话必须走统一降级（utils/contact.js）：门店 -> 商家。
  // 原先这里自己写 `store.servicePhone || store.phone`，少了商家兜底那一级 ——
  // 门店没填客服/门店电话时直接提示「暂无客服电话」，而后台商家客服是配了的。
  // 首页「在线咨询」和 store/service 页都已收口到 resolveContact，这里是漏的一处。
  goService() {
    const merchant = (app.globalData && app.globalData.merchant) || {};
    const phone = resolveContact(this.data.store, merchant).servicePhone;
    if (!phone) return wx.showToast({ title: '暂无客服电话', icon: 'none' });
    wx.showActionSheet({
      itemList: ['拨打电话'],
      success: (r) => { if (r.tapIndex === 0) wx.makePhoneCall({ phoneNumber: phone }); }
    });
  }
});
