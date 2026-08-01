const app = getApp();
const { api, toFullUrl } = require('../../utils/request.js');
const mock = require('../../utils/mock.js');

Page({
  data: { list: [], storeName: '' },
  onLoad() {
    this.load();
  },
  onShow() {
    if (typeof this.getTabBar === 'function' && this.getTabBar()) this.getTabBar().setData({ selected: 1 });
  },
  // 相册跟随当前门店，门店未就绪时先等 pickNearestStore 选出最近门店
  load() {
    const store = app.globalData.store || (app.globalData.stores && app.globalData.stores[0]);
    if (store && store.storeId) {
      this.loadAlbum(store);
      return;
    }
    app.pickNearestStore((s) => this.loadAlbum(s));
  },
  loadAlbum(store) {
    if (!store || !store.storeId) {
      this.fallback();
      return;
    }
    this.setData({ storeName: store.storeName || store.name || '' });
    api.storeAlbum(store.storeId).then((res) => {
      const rows = (res && (res.data || res.rows || res)) || [];
      const list = (Array.isArray(rows) ? rows : []).map((a) => ({
        id: a.albumId,
        url: toFullUrl(a.imageUrl)
      })).filter((a) => !!a.url);
      if (list.length) {
        this.setData({ list });
      } else {
        this.fallback();
      }
    }).catch(() => this.fallback());
  },
  fallback() {
    const store = (app.globalData.stores && app.globalData.stores[0]) || mock.stores[0];
    this.setData({ list: (store && store.album) || mock.stores[0].album });
  },
  // 点图全屏预览，相册页没有预览会很别扭
  preview(e) {
    const idx = e.currentTarget.dataset.idx;
    const urls = this.data.list.map((i) => i.url);
    if (!urls.length) return;
    wx.previewImage({ current: urls[idx], urls });
  }
});
