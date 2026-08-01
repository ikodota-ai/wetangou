const app = getApp();
const { api, toFullUrl } = require('../../utils/request.js');

// 门店未配相册时的兜底轮播图，避免首页出现空白 swiper
const FALLBACK_BANNERS = [
  { id: 'f1', src: '/assets/img/RestaurantImg.png' },
  { id: 'f2', src: '/assets/img/GoodsImg.jpg' }
];

Page({
  data: {
    statusBarHeight: 20,
    banners: FALLBACK_BANNERS,
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
      this.setData({
        store: store || {},
        goods: app.globalData.goods,
        phone: (store && (store.servicePhone || store.phone)) || '',
        qrcode: (store && store.serviceQrcode) || ''
      });
      if (store && store.storeId) {
        this.loadBanners(store.storeId);
        this.loadFacilities(store.storeId);
      }
    });
  },
  // 首页轮播复用门店相册，门店没配图时保留内置兜底图
  // 优先拉后端 banner，门店没配时再回退到 storeAlbum
  loadBanners(storeId) {
    api.bannerList({ position: 'home', merchantId: 0 }).then((res) => {
      const rows = (res && (res.data || res.rows || res)) || [];
      const banners = (Array.isArray(rows) ? rows : [])
        .filter((b) => b.imageUrl)
        .map((b) => ({ id: b.bannerId, src: toFullUrl(b.imageUrl), link: b.linkUrl || '' }));
      if (banners.length) {
        this.setData({ banners });
        return;
      }
      // 回退：复用门店相册
      return api.storeAlbum(storeId).then((res2) => {
        const rows2 = (res2 && (res2.data || res2.rows || res2)) || [];
        const fb = (Array.isArray(rows2) ? rows2 : [])
          .filter((a) => a.imgUrl)
          .map((a, i) => ({ id: a.albumId || 'a' + i, src: toFullUrl(a.imgUrl) }));
        if (fb.length) this.setData({ banners: fb });
      }).catch(() => {});
    }).catch(() => {});
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
    // 平台 banner 带 linkUrl 时优先跳；门店相册兜底时跳贴图页
    const item = (e && e.currentTarget && e.currentTarget.dataset) || {};
    const link = item.link;
    if (link && /^https?:\/\//.test(link)) {
      // 外链
      wx.setClipboardData({ data: link });
      return;
    }
    if (link) {
      wx.navigateTo({ url: link, fail: () => { wx.switchTab({ url: '/pages/album/index' }); } });
      return;
    }
    wx.switchTab({ url: '/pages/album/index' });
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
