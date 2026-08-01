const app = getApp();
const { api, toFullUrl, fixRichText } = require('../../../utils/request.js');
const mock = require('../../../utils/mock.js');

Page({
  data: {
    id: null,
    product: null,
    imgIdx: 0,
    showShare: false,
    showAuthPhone: false,
    showError: false,
    errorMsg: '商品已过售卖期',
    user: { nickName: '好吃嘴', avatarUrl: '/assets/avatar/default.png' }
  },
  onLoad(opts) {
    this.setData({ id: opts.id });
    this.setData({ user: app.globalData.user });
    this.loadProduct(opts.id);
  },
  onUserUpdate(user) { this.setData({ user }); },
  // 以后端商品为准，仅在接口不可用时回退 mock，避免拿假 productId 去下单
  loadProduct(id) {
    api.productDetail(id).then((res) => {
      const p = (res && (res.data || res)) || null;
      if (p && p.productId) {
        this.setData({ product: this.normalize(p) });
      } else {
        this.fallback(id);
      }
    }).catch(() => {
      this.fallback(id);
    });
  },
  normalize(p) {
    const images = p.images
      ? (Array.isArray(p.images) ? p.images : String(p.images).split(','))
      : (p.cover ? [p.cover] : []);
    return {
      ...p,
      name: p.productName || p.name,
      price: p.price != null ? String(p.price) : '0.00',
      sold: p.sales || p.sold || 0,
      cover: p.cover ? toFullUrl(p.cover) : '/assets/img/RestaurantImg.png',
      images: images.filter((u) => !!u).map((u) => toFullUrl(u)),
      detail: fixRichText(p.detail)
    };
  },
  fallback(id) {
    const local = mock.goods.find((g) => String(g.productId) === String(id));
    if (local) {
      this.setData({ product: { ...local, images: local.images || [local.cover] } });
      return;
    }
    this.setData({ showError: true, errorMsg: '商品已过售卖期' });
  },
  goDetail(e) { wx.redirectTo({ url: '/pages/goods/detail/index?id=' + e.currentTarget.dataset.id }); },
  goStore() { wx.switchTab({ url: '/pages/home/index' }); },
  goOrderList() { wx.navigateTo({ url: '/pages/order/list/index' }); },
  openShare() { this.setData({ showShare: true }); },
  closeShare() { this.setData({ showShare: false }); },
  closeAuthPhone() { this.setData({ showAuthPhone: false }); },
  closeError() { this.setData({ showError: false }); },
  copyError() { wx.setClipboardData({ data: this.data.errorMsg }); },
  onBuy() {
    if (!app.globalData.user.logged) {
      wx.navigateTo({ url: '/pages/login/login' });
      return;
    }
    if (!app.globalData.user.phone) {
      this.setData({ showAuthPhone: true });
      return;
    }
    wx.navigateTo({ url: '/pages/order/submit/index?id=' + this.data.id });
  },
  onGotPhone(e) {
    if (e.detail.errMsg && e.detail.errMsg.indexOf('ok') !== -1) {
      const phone = e.detail.phoneNumber || '';
      app.globalData.user.phone = phone;
      this.setData({ showAuthPhone: false, user: app.globalData.user });
      // 后端走新版 getPhoneNumber 流程：回传 code 由后端换号
      api.updatePhone({ code: e.detail.code }).then((res) => {
        const real = res && (res.phone || (res.data && res.data.phone));
        if (real) {
          app.globalData.user.phone = real;
          this.setData({ user: app.globalData.user });
        }
      }).catch(() => {});
      wx.showToast({ title: '已授权', icon: 'success' });
      setTimeout(() => wx.navigateTo({ url: '/pages/order/submit/index?id=' + this.data.id }), 400);
    } else {
      wx.showToast({ title: '已取消授权', icon: 'none' });
      this.setData({ showAuthPhone: false });
    }
  }
});
