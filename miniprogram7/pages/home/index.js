const app = getApp();
const { api, toFullUrl } = require('../../utils/request.js');

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
    qrcode: ''
  },
  onLoad() {
    try {
      const sys = wx.getSystemInfoSync();
      this.setData({ statusBarHeight: sys.statusBarHeight || 20 });
    } catch (e) {}
    // 加载商品
    this.loadData();
  },
  onShow() {
    if (typeof this.getTabBar === 'function' && this.getTabBar()) {
      this.getTabBar().setData({ selected: 0 });
    }
  },
  loadData() {
    app.pickNearestStore((store) => {
      console.log('[home] pickNearestStore =>', JSON.stringify(store).slice(0, 300))
      // 后端字段是 storeName / businessHours，WXML 用了 name / hours，这里做一次兼容
      const viewStore = store ? Object.assign({}, store, {
        name: store.storeName || store.name || '',
        hours: store.businessHours || store.hours || '',
        logo: store.logo ? toFullUrl(store.logo) : ''
      }) : {}
      // 客服信息：门店优先，商家兜底（兜底是数据层兜底，不是 UI 兜底：拿不到店时用商家资料）
      const m = (app.globalData && app.globalData.merchant) || {},
            sp = (store && (store.servicePhone || store.phone)) || m.servicePhone || '',
            sq = (store && store.serviceQrcode) || m.serviceQrcode || '',
            sh = (store && (store.businessHours || store.hours)) || m.businessHours || ''
      this.setData({
        store: viewStore,
        goods: app.globalData.goods,
        phone: sp,
        qrcode: sq ? toFullUrl(sq) : '',
        businessHours: sh
      })
      if (store && store.storeId) {
        this.loadBanners(store.storeId);
        this.loadFacilities(store.storeId);
      } else {
        console.warn('[home] store is null, skip banners/facilities');
      }
    });
  },

  // 拉后端 banner；不兜底：无数据 / 失败 / 缺 imageUrl 都视为错误并提示
  loadBanners(storeId) {
    api.bannerList({ position: 'home', merchantId: 0 }).then((res) => {
      const rows = (res && (res.data || res.rows || res)) || [];
      if (!Array.isArray(rows) || rows.length === 0) {
        throw new Error('后端未配置首页 banner（position=home 0 条），请在【平台配置 → 轮播图管理】新增')
      }
      const banners = rows
        .filter((b) => b.imageUrl)
        .map((b) => ({ id: b.bannerId, src: toFullUrl(b.imageUrl), link: b.linkUrl || '' }));
      if (banners.length === 0) {
        throw new Error('后端 banner 全部缺 imageUrl，请在【轮播图管理】检查图片字段')
      }
      this.setData({ banners });
    }).catch((err) => {
      console.error('[home] loadBanners FAIL', err)
      wx.showToast({ title: '首页 banner 加载失败：' + ((err && (err.msg || err.message)) || '网络异常'), icon: 'none', duration: 4000 })
      // 保持 banners=[]（空数组），让 swiper 显示空白以便排查
      this.setData({ banners: [] })
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
    wx.navigateTo({ url: '/pages/pay/index/index' + (id ? '?storeId=' + id : '') });
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
