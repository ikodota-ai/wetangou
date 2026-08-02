const app = getApp();
const { api, toFullUrl, fixRichText } = require('../../../utils/request.js');

Page({
  data: {
    id: null,
    product: null,
    imgIdx: 0,
    showShare: false,
    showAuthPhone: false,
    // 三个互斥状态：loading / loadError / 空
    loading: false,
    loadError: false,
    errorMsg: '',
    user: { nickName: '好吃嘴', avatarUrl: '/assets/avatar/default.png' }
  },
  onLoad(opts) {
    this.setData({ id: opts.id, user: app.globalData.user });
    this.loadProduct(opts.id);
  },
  onUserUpdate(user) { this.setData({ user }); },
  // 完全走后端，不做 mock 兜底；接口报错直接把错暴露给用户，便于排查
  loadProduct(id) {
    console.log('[goods/detail] loadProduct start, id=', id);
    if (!id) {
      this.setData({ loading: false, loadError: true, errorMsg: '商品ID缺失' });
      return;
    }
    this.setData({ loading: true, loadError: false, errorMsg: '' });
    // 5s 兜底：loading 状态被 setData 吞掉时强制结束，避免一直转圈
    this._loadTimer = setTimeout(() => {
      if (this.data.loading && !this.data.product) {
        console.warn('[goods/detail] loadProduct timeout, force clear loading');
        this.setData({ loading: false, loadError: true, errorMsg: '请求超时，请检查网络或后端' });
      }
    }, 5000);
    api.productDetail(id)
      .then((res) => {
        clearTimeout(this._loadTimer);
        console.log('[goods/detail] productDetail response =>', JSON.stringify(res).slice(0, 500));
        // 兼容后端两层封装：{ code, data: {product} } → res.data.product
        const d = (res && res.data) || res || null;
        const p = (d && (d.data || d)) || null;
        if (p && p.productId) {
          let normalized;
          try {
            normalized = this.normalize(p);
          } catch (e) {
            console.error('[goods/detail] normalize FAIL', e, p);
            this.setData({ loading: false, loadError: true, errorMsg: '数据规范化失败: ' + e.message });
            return;
          }
          this.setData({ product: normalized, loading: false, loadError: false });
        } else {
          // 后端返回 200 但 payload 没有 productId
          this.setData({ loading: false, loadError: true, errorMsg: '后端返回数据缺少 productId' });
        }
      })
      .catch((err) => {
        clearTimeout(this._loadTimer);
        const msg = (err && (err.errMsg || err.msg)) || (err && err.message) || '网络请求失败';
        console.error('[goods/detail] productDetail FAIL', id, err);
        this.setData({ loading: false, loadError: true, errorMsg: msg });
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
  onRetry() { this.loadProduct(this.data.id); },
  onBack() { wx.switchTab({ url: '/pages/home/index', fail: () => wx.navigateBack({ delta: 1 }) }); },
  goDetail(e) { wx.redirectTo({ url: '/pages/goods/detail/index?id=' + e.currentTarget.dataset.id }); },
  goStore() { wx.switchTab({ url: '/pages/home/index' }); },
  goOrderList() { wx.navigateTo({ url: '/pages/order/list/index' }); },
  openShare() { this.setData({ showShare: true }); },
  closeShare() { this.setData({ showShare: false }); },
  closeAuthPhone() { this.setData({ showAuthPhone: false }); },
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
