const app = getApp();

Page({
  data: { statusBarHeight: 20, store: {} },
  onLoad() {
    try { this.setData({ statusBarHeight: wx.getSystemInfoSync().statusBarHeight || 20 }); } catch (e) {}
    app.pickNearestStore((s) => { this.setData({ store: s || {} }); });
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
