const app = getApp();
const { haversineKm, formatDistance } = require('../../utils/util.js');

Page({
  data: { statusBarHeight: 20, store: {} },
  onLoad() {
    try { this.setData({ statusBarHeight: wx.getSystemInfoSync().statusBarHeight || 20 }); } catch (e) {}
    // 立即用缓存的 store 渲染一次（避免空窗期）
    const cached = (getApp().globalData && getApp().globalData.store) || null
    if (cached && cached.storeId) {
      this.setData({ store: this._compatStore(cached) });
    } else {
      this.setData({ _storeLoadTimedOut: false });
    }
    // 后台异步尝试选最近门店（pickNearestStore 内部有 globalData 短路，未变就不重渲染）
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
    wx.navigateTo({ url: '/pages/booking/create/index' + (id ? '?storeId=' + id : '') });
  },
  goList() { wx.navigateTo({ url: '/pages/booking/list/index' }); },
  goHome() { wx.switchTab({ url: '/pages/home/index' }); },
  goLocation() {
    const s = this.data.store;
    if (!s.latitude || !s.longitude) return wx.showToast({ title: '暂无门店坐标', icon: 'none' });
    wx.openLocation({ latitude: s.latitude, longitude: s.longitude, name: s.name, address: s.address });
  },
  goService() {
    const phone = this.data.store.servicePhone || this.data.store.phone;
    if (!phone) return wx.showToast({ title: '暂无客服电话', icon: 'none' });
    wx.showActionSheet({
      itemList: ['拨打电话'],
      success: (r) => { if (r.tapIndex === 0) wx.makePhoneCall({ phoneNumber: phone }); }
    });
  }
});
