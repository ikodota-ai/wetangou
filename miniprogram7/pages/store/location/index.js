const app = getApp();
Page({
  data: {
    latitude: 0,
    longitude: 0,
    storeName: '',
    merchantName: '',
    address: '',
    markers: []
  },
  onLoad() {
    const appInst = (typeof getApp === 'function' ? getApp() : null) || {}
    const m = (appInst.globalData && appInst.globalData.merchant) || {}
    this.setData({ merchantName: m.merchantName || '当前商家' })
    const s = app.globalData.store || (app.globalData.stores && app.globalData.stores[0]);
    if (s && s.latitude != null && s.longitude != null) {
      this.setData({
        latitude: s.latitude,
        longitude: s.longitude,
        storeName: s.storeName || s.name || '',
        address: s.address || '',
        markers: [{ id: 1, latitude: s.latitude, longitude: s.longitude, width: 40, height: 50, iconPath: '' }]
      });
    } else {
      wx.showToast({ title: '门店位置暂未配置', icon: 'none' });
    }
  },
  goNav() {
    if (!this.data.latitude) return;
    wx.openLocation({
      latitude: this.data.latitude,
      longitude: this.data.longitude,
      name: this.data.storeName || '门店',
      address: this.data.address || ''
    });
  },
  goTaxi() { wx.showToast({ title: '打车功能开发中', icon: 'none' }); },
  onFav() { wx.showToast({ title: '已收藏', icon: 'success' }); },
  onMore() { wx.showActionSheet({ itemList: ['分享位置', '报错'], success: (r) => r.tapIndex === 0 && wx.showToast({ title: '已分享', icon: 'success' }) }); }
});
