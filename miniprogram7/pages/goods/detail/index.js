const app = getApp();
const { api, toFullUrl, fixRichText } = require('../../../utils/request.js');

Page({
  data: {
    id: null,
    product: null,
    canBuyNow: false,
    buyBtnLabel: '加载中…',
    imgIdx: 0,
    showShare: false,
    showAuthPhone: false,
    // 单一状态机：loading / loaded / error / empty
    // 任何时刻只有一个为 true，便于 WXML 用单一 wx:if 判断
    state: 'loading',
    errorMsg: '',
    user: { nickName: '好吃嘴', avatarUrl: '/assets/avatar/default.png' },
    // 分享面板：小程序码 dataUrl（空则显示占位文案），以及原价是否该显示
    shareQr: '',
    shareQrTip: '小程序码加载中',
    showSharePriceOld: false
  },
  onLoad(opts) {
    // 防御：app 异常时给个默认 user，避免 onLoad 内任意 getApp() 失败
    const appInst = (typeof getApp === 'function' ? getApp() : null) || {};
    const m = (appInst.globalData && appInst.globalData.merchant) || {}
    this.setData({
      id: opts.id,
      user: this._normalizeUser(appInst.globalData && appInst.globalData.user),
      merchantName: m.merchantName || '当前商家'
    });
    this.loadProduct(opts.id);
  },
  onUserUpdate(user) { this.setData({ user: this._normalizeUser(user) }); },
  /**
   * 头像必须过 toFullUrl：后端存的是 /profile/avatar/xxx.png 这种相对路径，
   * 直接塞给 <image src> 会当成小程序包内路径去找，必然裂图 ——
   * 分享面板里显示的就是默认头像而不是用户自己的。
   * pages/mine/index 早就这么处理了，这里漏了。
   */
  _normalizeUser(u) {
    const src = u || {};
    return Object.assign({}, src, {
      nickName: src.nickName || '好吃嘴',
      avatarUrl: src.avatarUrl ? toFullUrl(src.avatarUrl) : '/assets/avatar/default.png'
    });
  },
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
          // 购买按钮的可点态和文案必须在这里算好塞进 data。
          // 模板原先写 {{canBuy() ? 'enabled' : 'disabled'}} 和 {{buyBtnDisabledText()}} ——
          // WXML 调不到 Page 方法，前者恒得 undefined（按钮永远是 disabled 灰态），
          // 后者恒渲染成空字符串（按钮上一个字都没有）。也就是说所有商品的
          // 购买按钮都是一个没字的灰块，顾客根本不知道能不能买、买多少钱。
          this.setData({
            product: normalized,
            state: 'loaded',
            canBuyNow: this.canBuy(normalized),
            buyBtnLabel: this.buyBtnDisabledText(normalized)
          });
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
      typeName: this.typeText(typeCode),
      faceValue: p.faceValue != null ? String(p.faceValue) : '',
      minConsume: p.minConsume != null ? String(p.minConsume) : '',
      totalTimes: p.totalTimes || 0,
      periodType: p.periodType || '',
      periodCount: p.periodCount || 0,
      totalValue: p.totalValue != null ? String(p.totalValue) : '',
      requireXiaoxin: p.requireXiaoxin || 0,
      // V2.6 P1 限制条件字段
      validityDays: p.validityDays || 0,
      limitPerUser: p.limitPerUser || 0,
      maxPerOrder: p.maxPerOrder || 0,
      maxPersons: p.maxPersons || 0,
      refundPolicy: p.refundPolicy || '',
      notice: p.notice || '',
      otherNotice: p.otherNotice || '',
      bookingRequired: p.bookingRequired || 0,
      saleStartDate: p.saleStartDate || '',
      saleEndDate: p.saleEndDate || '',
      extraFeeDesc: p.extraFeeDesc || '',
      saleStartText: p.saleStartDate ? this._fmtDate(p.saleStartDate) : '',
      saleEndText: p.saleEndDate ? this._fmtDate(p.saleEndDate) : '',
      // 折扣文案（X.X 折）
      discountText: (function(){
        const now = Number(p.price), old = Number(p.marketPrice);
        if (!old || old <= now) return '';
        const d = (now / old * 10).toFixed(1);
        return d + ' 折热销中';
      })(),
      // 适用门店信息
      storeCount: (p.storeIds ? String(p.storeIds).split(',').filter(x=>x).length : (p.storeId ? 1 : 0)),
      storeCountText: (p.storeIds ? String(p.storeIds).split(',').filter(x=>x).length : (p.storeId ? 1 : 0)) + '家',
      storeScopeText: p.storeNames || (p.storeId ? '当前门店适用' : '全部门店适用'),
      subitemGroups: subitemGroups,
      sold: p.sales || p.sold || 0,
      cover: p.cover ? toFullUrl(p.cover) : '/assets/img/RestaurantImg.png',
      images: images.filter((u) => !!u).map((u) => toFullUrl(u)),
      detail: fixRichText(p.detail)
    };
  },
  // 顶部大图原先是单张静态 image，可 hero-page 已经在显示「1/3」这种页码 ——
  // 页码存在但翻不动，用户以为图挂了。改 swiper 后 imgIdx 才真跟得上
  onSwiperChange(e) {
    this.setData({ imgIdx: e.detail.current });
  },
  onRetry() { this.loadProduct(this.data.id); },
  onBack() { wx.switchTab({ url: '/pages/home/index', fail: () => wx.navigateBack({ delta: 1 }) }); },
  goDetail(e) { wx.redirectTo({ url: '/pages/goods/detail/index?id=' + e.currentTarget.dataset.id }); },
  goStore() { wx.switchTab({ url: '/pages/home/index' }); },
  goOrderList() { wx.navigateTo({ url: '/pages/order/list/index' }); },
  openShare() {
    const p = this.data.product || {};
    // 原价只在真的比现价高时才显示。原先写死成 sp-old 也绑 product.price，
    // 于是「¥50 ¥50」两个一样的数字并排、还带删除线，看着像 bug。
    const now = Number(p.price), old = Number(p.marketPrice);
    this.setData({
      showShare: true,
      showSharePriceOld: !!(old && now && old > now)
    });
    this._loadShareQr();
  },
  closeShare() { this.setData({ showShare: false }); },
  /**
   * 拉商品小程序码。原先面板里那个「码」是 CSS 渐变拼的假纹理（.qr-circle
   * 用 radial-gradient + conic-gradient 模拟），扫不出任何东西；海报页则调
   * /api/distributor/qrcode，那个端点要求调用者是推客，普通会员必然 403。
   * 现在走 /api/product/{id}/qrcode，与推客身份无关，人人可用。
   */
  _loadShareQr() {
    if (this.data.shareQr) return;          // 同一个商品只拉一次
    if (this._qrLoading) return;
    const id = this.data.id || (this.data.product && this.data.product.productId);
    if (!id) return;
    this._qrLoading = true;
    api.productQrcode(id)
      .then((res) => {
        const d = (res && (res.data || res)) || {};
        const url = d.dataUrl || d.url || '';
        this.setData({ shareQr: url, shareQrTip: url ? '' : '小程序码暂不可用' });
      })
      .catch((err) => {
        console.warn('[goods/detail] productQrcode FAIL', err);
        // 不弹 toast：分享面板已经打开了，这里失败只降级成占位文案，
        // 用户仍可用「发送给朋友」这条不依赖码的路径
        this.setData({ shareQr: '', shareQrTip: '小程序码暂不可用' });
      })
      .finally(() => { this._qrLoading = false; });
  },
  /**
   * 「收藏」点了没反应的根因：<button open-type="favorite"> 只有在页面
   * 实现了 onAddToFavorites 且**当前小程序版本支持收藏**时才有效，
   * 而开发者工具/未发布版本上这个 open-type 是静默失效的 —— 按钮能点、
   * 什么都不发生，用户以为坏了。这里补一个 bindtap 给出明确反馈。
   * 真机已发布版本上 open-type 生效时，微信会直接弹收藏浮层，
   * bindtap 的 toast 也不影响（两者都会走，浮层盖在上面）。
   */
  onFavTap() {
    wx.showToast({ title: '点击右上角「···」可收藏', icon: 'none', duration: 2000 });
  },
  closeAuthPhone() { this.setData({ showAuthPhone: false }); },
  onBuy() {
    if (!this.canBuy()) {
      wx.showToast({ title: this.limitText() || '当前不可购买', icon: 'none' });
      return;
    }
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
  /**
   * 限制条件展示文案（按优先级）
   *  - 库存售罄 → "已售罄"
   *  - 售卖期外 → "售卖期：xxxx 至 xxxx"
   *  - 否则显示 默认限制
   */
  limitText() {
    const p = this.data.product
    if (!p) return ''
    if (p.stock === 0) return '已售罄'
    if (p.saleStartDate && this._dateInFuture(p.saleStartDate)) {
      return '售卖期：' + this._fmtDate(p.saleStartDate) + ' 起'
    }
    if (p.saleEndDate && this._dateInPast(p.saleEndDate)) {
      return '售卖期已过（' + this._fmtDate(p.saleEndDate) + ' 截止）'
    }
    return '可购买'
  },
  _dateInFuture(s) {
    if (!s) return false
    const t = new Date(String(s).replace(/-/g, '/')).getTime()
    return t > Date.now()
  },
  _dateInPast(s) {
    if (!s) return false
    const t = new Date(String(s).replace(/-/g, '/')).getTime()
    return t < Date.now()
  },
  _fmtDate(s) {
    if (!s) return ''
    const str = String(s)
    return str.length >= 10 ? str.substring(0, 10) : str
  },
  /** 是否允许立即购买 */
  canBuy(prod) {
    const p = prod || this.data.product
    if (!p) return false
    if (p.stock === 0) return false
    if (p.saleStartDate && this._dateInFuture(p.saleStartDate)) return false
    if (p.saleEndDate && this._dateInPast(p.saleEndDate)) return false
    return true
  },
  /** 购买按钮 disabled 文案 */
  buyBtnDisabledText(prod) {
    const p = prod || this.data.product
    if (!p) return '加载中…'
    if (p.stock === 0) return '已售罄'
    if (p.saleStartDate && this._dateInFuture(p.saleStartDate)) return '未到售卖期'
    if (p.saleEndDate && this._dateInPast(p.saleEndDate)) return '已过售卖期'
    return this.buyBtnText(p)
  },
  buyBtnText(prod) {
    const p = prod || this.data.product
    const t = p && p.typeCode
    const price = (p && p.price) || '0.00'
    if (t === 'BILL') return '买单 ¥' + price
    if (t === 'BOOKING') return '立即预约 ¥' + price
    if (t === 'VOUCHER') return '购买代金券 ¥' + price
    if (t === 'TIMECARD') return '购买次卡 ¥' + price
    if (t === 'STORED_CARD') return '充值 ¥' + price
    if (t === 'PERIOD_CARD') return '开通周期卡 ¥' + price
    if (t === 'COMBO') return '购买组合券包 ¥' + price
    return '立即购买 ¥' + price
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
      // 商家名拿不到时就只发商品名，不能写死「洞天团购」——
      // 这是多商户平台，每个商户有自己的品牌名，硬编码等于把别家商品
      // 挂上我们的名字发出去
      title: name + (price ? ' ¥' + price : '') + (m.merchantName ? ' | ' + m.merchantName : ''),
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
      // 商家名拿不到时就只发商品名，不能写死「洞天团购」——
      // 这是多商户平台，每个商户有自己的品牌名，硬编码等于把别家商品
      // 挂上我们的名字发出去
      title: name + (price ? ' ¥' + price : '') + (m.merchantName ? ' | ' + m.merchantName : ''),
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
