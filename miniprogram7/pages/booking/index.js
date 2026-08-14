const app = getApp();

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
  _compatStore(s) {
    if (!s) return {};
    return Object.assign({}, s, {
      name: s.storeName || s.name || '',
      hours: s.businessHours || s.hours || '',
      address: s.address || ''
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
