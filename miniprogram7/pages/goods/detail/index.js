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
    const m = (appInst.globalData && appInst.globalData.merchant) || {}
    this.setData({
      id: opts.id,
      user: (appInst.globalData && appInst.globalData.user) || { nickName: '好吃嘴', avatarUrl: '/assets/avatar/default.png' },
      merchantName: m.merchantName || '当前商家'
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
        const groups = d && d.subitemGroups ? d.subitemGroups : (p && p.subitemGroups) || []
        if (p && p.productId) {
          let normalized;
          try {
            normalized = this.normalize(p, groups);
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
  normalize(p, groups) {
    const images = p.images
      ? (Array.isArray(p.images) ? p.images : String(p.images).split(','))
      : (p.cover ? [p.cover] : []);
    const typeCode = p.typeCode || (p.productType === '1' ? 'BILL' : p.productType === '2' ? 'BOOKING' : 'GROUPON');
    const subitemGroups = Array.isArray(groups) ? groups.map(g => ({
      groupId: g.groupId,
      groupName: g.groupName,
      pickRule: g.pickRule || 'ALL',
      sort: g.sort || 0,
      subitems: Array.isArray(g.subitems) ? g.subitems.map(s => ({
        subitemId: s.subitemId,
        subitemName: s.subitemName,
        quantity: s.quantity || 1,
        price: s.price != null ? String(s.price) : '0.00'
      })) : []
    })) : [];
    return {
      ...p,
      name: p.productName || p.name,
      price: p.price != null ? String(p.price) : '0.00',
      typeCode: typeCode,
      faceValue: p.faceValue != null ? String(p.faceValue) : '',
      minConsume: p.minConsume != null ? String(p.minConsume) : '',
      totalTimes: p.totalTimes || 0,
      periodType: p.periodType || '',
      periodCount: p.periodCount || 0,
      totalValue: p.totalValue != null ? String(p.totalValue) : '',
      requireXiaoxin: p.requireXiaoxin || 0,
      subitemGroups: subitemGroups,
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
  typeText(code) {
    return ({
      GROUPON: '团购套餐', VOUCHER: '代金券', TIMECARD: '次卡',
      STORED_CARD: '储值卡', PERIOD_CARD: '周期卡', HUIXIANG_CARD: '惠享卡',
      COMBO: '组合券包', BILL: '到店买单', BOOKING: '预约服务',
      PRESALE: '预售券', PICKUP_VOUCHER: '提货券'
    })[code] || (code || '团购')
  },
  buyBtnText() {
    const t = this.data.product && this.data.product.typeCode
    if (t === 'BILL') return '买单 ¥' + (this.data.product.price || '0.00')
    if (t === 'BOOKING') return '立即预约 ¥' + (this.data.product.price || '0.00')
    if (t === 'VOUCHER') return '购买代金券 ¥' + (this.data.product.price || '0.00')
    if (t === 'TIMECARD') return '购买次卡 ¥' + (this.data.product.price || '0.00')
    if (t === 'STORED_CARD') return '充值 ¥' + (this.data.product.price || '0.00')
    if (t === 'PERIOD_CARD') return '开通周期卡 ¥' + (this.data.product.price || '0.00')
    if (t === 'COMBO') return '购买组合券包 ¥' + (this.data.product.price || '0.00')
    return '立即购买 ¥' + (this.data.product.price || '0.00')
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
  },
  // ====== 分享 / 收藏 / 保存图片 ======
  /**
   * 微信胶囊菜单「转发给朋友」与弹窗中<button open-type="share">都会触发此方法
   * 走自己拼的 path（带 productId），让对方点进来直接定位到该商品详情
   */
  onShareAppMessage() {
    const p = this.data.product;
    const id = (p && (p.productId || p.id)) || this.data.id || '';
    const m = (getApp().globalData && getApp().globalData.merchant) || {};
    const name = (p && (p.name || p.productName)) || '好物';
    const price = (p && p.price) || '';
    const rawImg = (p && (p.images && p.images[0] || p.cover)) || '';
    const shareImg = rawImg ? toFullUrl(rawImg) : '';
    return {
      title: name + (price ? ' ¥' + price : '') + ' | ' + (m.merchantName || '洞天团购'),
      path: '/pages/goods/detail/index?id=' + id,
      imageUrl: shareImg
    };
  },
  /**
   * 微信胶囊菜单「分享到朋友圈」
   * 分享到朋友圈时 imageUrl 必填，否则会触发警告
   */
  onShareTimeline() {
    const p = this.data.product;
    const m = (getApp().globalData && getApp().globalData.merchant) || {};
    const name = (p && (p.name || p.productName)) || '好物';
    const price = (p && p.price) || '';
    const rawImg = (p && (p.images && p.images[0] || p.cover)) || '';
    const shareImg = rawImg ? toFullUrl(rawImg) : '';
    return {
      title: name + (price ? ' ¥' + price : '') + ' | ' + (m.merchantName || '洞天团购'),
      query: 'id=' + ((p && (p.productId || p.id)) || this.data.id || ''),
      imageUrl: shareImg
    };
  },
  /**
   * 微信基础库 2.10.0+ 起的「收藏」按钮（弹窗中<button open-type="favorite">触发）
   * 静默成功，无需做额外处理；保留钩子便于以后打点
   */
  onAddToFavorites() {
    const p = this.data.product;
    const rawImg = (p && (p.images && p.images[0] || p.cover)) || '';
    return {
      title: (p && (p.name || p.productName)) || '好物',
      imageUrl: rawImg ? toFullUrl(rawImg) : '',
      query: 'id=' + ((p && (p.productId || p.id)) || this.data.id || '')
    };
  },
  /**
   * 保存图片：跳到海报页（pages/goods/share/index）让用户在那里点保存按钮
   * 之所以跳页而不是在弹窗里直接画海报：弹窗层 canvas 在很多机型上 z-index/层级有问题
   * 海报页有专门的 canvas 绘制 + 下载 + 保存相册完整流程
   */
  onSavePoster() {
    const id = (this.data.product && (this.data.product.productId || this.data.product.id)) || this.data.id;
    if (!id) {
      wx.showToast({ title: '商品未加载', icon: 'none' });
      return;
    }
    this.setData({ showShare: false });
    wx.navigateTo({ url: '/pages/goods/share/index?id=' + id });
  }
});
