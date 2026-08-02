const app = getApp();
const { api, toFullUrl, fixRichText } = require('../../../utils/request.js');

Page({
  data: {
    id: null,
    product: null,
    imgIdx: 0,
    showShare: false,
    showAuthPhone: false,
    // 单一状态机：loading / loaded / error / empty
    // 任何时刻只有一个为 true，便于 WXML 用单一 wx:if 判断
    state: 'loading',
    errorMsg: '',
    user: { nickName: '好吃嘴', avatarUrl: '/assets/avatar/default.png' }
  },
  onLoad(opts) {
    // 防御：app 异常时给个默认 user，避免 onLoad 内任意 getApp() 失败
    const appInst = (typeof getApp === 'function' ? getApp() : null) || {};
    this.setData({
      id: opts.id,
      user: (appInst.globalData && appInst.globalData.user) || { nickName: '好吃嘴', avatarUrl: '/assets/avatar/default.png' }
    });
    this.loadProduct(opts.id);
  },
  onUserUpdate(user) { this.setData({ user }); },
  // 完全走后端，不做 mock 兜底；接口报错直接把错暴露给用户，便于排查
  loadProduct(id) {
    console.log('[goods/detail] loadProduct start, id=', id);
    if (!id) {
      this.setData({ state: 'error', errorMsg: '商品ID缺失' });
      return;
    }
    this.setData({ state: 'loading', errorMsg: '' });
    // 5s 兜底：避免 setData 被吞掉时一直转圈
    this._loadTimer = setTimeout(() => {
      if (this.data.state === 'loading') {
        console.warn('[goods/detail] loadProduct timeout, force set error');
        this.setData({ state: 'error', errorMsg: '请求超时，请检查网络或后端' });
      }
    }, 5000);
    api.productDetail(id)
      .then((res) => {
        clearTimeout(this._loadTimer);
        console.log('[goods/detail] productDetail response =>', JSON.stringify(res).slice(0, 500));
        const d = (res && res.data) || res || null;
        const p = (d && (d.data || d)) || null;
        if (p && p.productId) {
          let normalized;
          try {
            normalized = this.normalize(p);
          } catch (e) {
            console.error('[goods/detail] normalize FAIL', e, p);
            this.setData({ state: 'error', errorMsg: '数据规范化失败: ' + e.message });
            return;
          }
          this.setData({ product: normalized, state: 'loaded' });
        } else if (p && p.code && p.code !== 200) {
          // 后端返回非 200 的业务码
          this.setData({ state: 'error', errorMsg: p.msg || '后端返回业务错误' });
        } else {
          // payload 没有 productId
          this.setData({ state: 'empty', errorMsg: '商品已下架' });
        }
      })
      .catch((err) => {
        clearTimeout(this._loadTimer);
        const msg = (err && (err.errMsg || err.msg)) || (err && err.message) || '网络请求失败';
        console.error('[goods/detail] productDetail FAIL', id, err);
        this.setData({ state: 'error', errorMsg: msg });
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
