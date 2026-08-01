const app = getApp();
const mock = require('../../../utils/mock.js');
Page({
  data: {
    latitude: 23.405,
    longitude: 113.227,
    markers: [{ id: 1, latitude: 23.405, longitude: 113.227, width: 40, height: 50, iconPath: '' }]
  },
  onLoad() {
    const s = (app.globalData.stores && app.globalData.stores[0]) || mock.stores[0];
    this.setData({ latitude: s.latitude, longitude: s.longitude });
  },
  goNav() { wx.openLocation({ latitude: this.data.latitude, longitude: this.data.longitude, name: '菌鑫来餐饮', address: '花城街道建设北路222号101房自编3号' }); },
  goTaxi() { wx.showToast({ title: '打车功能开发中', icon: 'none' }); },
  onFav() { wx.showToast({ title: '已收藏', icon: 'success' }); },
  onMore() { wx.showActionSheet({ itemList: ['分享位置', '报错'], success: (r) => r.tapIndex === 0 && wx.showToast({ title: '已分享', icon: 'success' }) }); }
});
