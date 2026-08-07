const app = getApp();
const { api, toFullUrl } = require('../../../utils/request.js');
const { formatMoney } = require('../../../utils/util.js');

Page({
  data: {
    id: null,
    product: null,
    store: {},
    qty: 1,
    pickup: true,
    name: '',
    phone: '',
    total: '0.00',
    submitting: false
  },
  onLoad(opts) {
    const appInst = (typeof getApp === 'function' ? getApp() : null) || {};
    const u = (appInst.globalData && appInst.globalData.user) || {};
    this.setData({
      id: opts.id,
      name: u.nickName || '',
      phone: u.phone || ''
    });
    this.loadProduct(opts.id);
  },
  // 商品信息以后端为准：价格、库存都要真实，避免用本地数据下单后金额不符
  loadProduct(id) {
    if (!id) {
      wx.showToast({ title: '商品ID缺失', icon: 'none' });
      return;
    }
    api.productDetail(id).then((res) => {
      // 兼容后端两层封装：{ code, data: {product} } → res.data.product
      const d = (res && res.data) || res || null;
      const p = (d && (d.data || d)) || null;
      console.log('[order/submit] productDetail =>', JSON.stringify({ id, hasProduct: !!(p && p.productId) }));
      if (!p || !p.productId) {
        wx.showToast({ title: '商品不存在或已下架', icon: 'none' });
        return;
      }
      const product = {
        productId: p.productId,
        name: p.productName || p.name,
        price: p.price != null ? formatMoney(p.price) : '0.00',
        cover: p.cover ? toFullUrl(p.cover) : '/assets/img/RestaurantImg.png',
        stock: p.stock,
        storeId: p.storeId
      };
      this.setData({ product });
      this.loadStore(p.storeId);
      this.recalc();
    }).catch((err) => {
      const msg = (err && (err.errMsg || err.msg)) || (err && err.message) || '商品加载失败';
      console.error('[order/submit] productDetail FAIL', id, err);
      wx.showToast({ title: msg, icon: 'none' });
    });
  },
  loadStore(storeId) {
    if (!storeId) return;
    api.storeDetail(storeId).then((res) => {
      const s = (res && (res.data || res)) || null;
      if (s) this.setData({ store: { name: s.storeName || s.name || '' } });
    }).catch(() => {});
  },
  recalc() {
    const p = this.data.product;
    if (!p) return;
    this.setData({ total: formatMoney((parseFloat(p.price) || 0) * this.data.qty) });
  },
  incQty() {
    const p = this.data.product;
    const next = this.data.qty + 1;
    if (p && p.stock != null && next > p.stock) {
      wx.showToast({ title: '库存不足', icon: 'none' });
      return;
    }
    this.setData({ qty: next });
    this.recalc();
  },
  decQty() {
    if (this.data.qty > 1) {
      this.setData({ qty: this.data.qty - 1 });
      this.recalc();
    }
  },
  togglePickup() { this.setData({ pickup: !this.data.pickup }); },
  onName(e) { this.setData({ name: e.detail.value }); },
  onPhone(e) { this.setData({ phone: e.detail.value }); },
  onSubmit() {
    if (this.data.submitting) return;
    if (!this.data.product) return wx.showToast({ title: '商品信息未加载', icon: 'none' });
    if (!this.data.name) return wx.showToast({ title: '请输入姓名', icon: 'none' });
    if (!/^1\d{10}$/.test(this.data.phone)) return wx.showToast({ title: '请输入正确的手机号', icon: 'none' });
    if (!app.globalData.user.logged) {
      wx.navigateTo({ url: '/pages/login/login' });
      return;
    }

    this.setData({ submitting: true });
    wx.showLoading({ title: '提交中', mask: true });
    api.createOrder({
      productId: this.data.product.productId,
      num: this.data.qty,
      distributorId: app.globalData.shareDistributorId || undefined
    }).then((res) => {
      const order = (res && (res.data || res)) || {};
      if (!order.orderId) {
        throw new Error(res && res.msg ? res.msg : '下单失败');
      }
      // 创建订单成功 → 跳支付中间页
      wx.redirectTo({ url: '/pages/order-pay/index?type=order&id=' + order.orderId });
    }).catch((err) => {
      wx.hideLoading();
      this.setData({ submitting: false });
      wx.showToast({ title: (err && (err.msg || err.message)) || '下单失败', icon: 'none' });
    });
  },

  onPaid(orderId) {
    this.setData({ submitting: false });
    wx.showToast({ title: '支付成功', icon: 'success' });
    setTimeout(() => {
      wx.redirectTo({ url: '/pages/order/list/index?type=unused&orderId=' + orderId });
    }, 800);
  }
});
