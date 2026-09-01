const app = getApp();
const { api, toFullUrl } = require('../../../utils/request.js');
const { formatMoney } = require('../../../utils/util.js');
const voucherUtil = require('../../../utils/voucher.js');

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
    // 代金券：后端 placeOrder 一直收 memberVoucherId 并做抵扣，
    // 但本页原先既没有选券入口也没往 createOrder 传这个参数，
    // 所以「领了券不能抵扣」在商品下单（含到店自取）这条路上一直是断的。
    vouchers: [],
    voucherList: [],
    voucherCount: 0,
    voucher: null,
    voucherText: '未使用',
    showVoucher: false,
    discount: '0.00',
    payAmount: '0.00',
    submitting: false
  },
  onLoad(opts) {
    this.setData({ id: opts.id });
    this._refreshUserContact();
    this.loadProduct(opts.id);
    this.loadVouchers();
  },

  // 每次进入/回到本页都重新拉一次会员资料，确保手机号/昵称最新
  // 解决：首次进入时未授权；授权后从资料页/弹窗返回时 phone 是空
  onShow() {
    this._refreshUserContact();
    // 从登录页/领券中心返回时重新拉券：未登录时 loadVouchers 直接 return，
    // 只在 onLoad 拉一次的话刚领的券要杀掉进程才看得到
    this.loadVouchers();
  },

  // 监听 app.notifyUserUpdate：被其他页（资料页/详情页）授权手机号后即时刷新
  onUserUpdate(u) {
    if (u && u.phone) {
      this.setData({
        name: u.nickName || this.data.name,
        phone: u.phone
      });
    }
  },

  _refreshUserContact() {
    const appInst = (typeof getApp === 'function' ? getApp() : null) || {};
    const u = (appInst.globalData && appInst.globalData.user) || {};
    // 1) 先用缓存值（最快展示）
    if (u.phone) {
      this.setData({ name: u.nickName || this.data.name || '', phone: u.phone });
    }
    // 2) 已登录则主动拉一次 profile 拿明文（解决 bootUser 还没回、或别处刚授权落库后未同步）
    if (u && u.logged) {
      api.getUserInfo().then((r) => {
        // request() 已解一层 data，这里 r 就是 vo 本身
        const m = r && (r.phone ? r : (r.data || r));
        if (m && m.phone) {
          this.setData({
            name: m.nickName || m.nickname || this.data.name || '',
            phone: m.phone
          });
          appInst.globalData.user.phone = m.phone;
          appInst.globalData.user.nickName = appInst.globalData.user.nickName || m.nickName || m.nickname;
        }
      }).catch(() => {});
    }
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
  // 本单归属门店：商品详情返回的 storeId 就是下单落库那个（后端按它校验券）
  _storeId() {
    return (this.data.product && this.data.product.storeId) || null;
  },
  recalc() {
    const p = this.data.product;
    if (!p) return;
    const total = formatMoney((parseFloat(p.price) || 0) * this.data.qty);
    this.setData({ total });
    this.refreshUsable(total);
  },

  // 我的未使用券。列表整体缓存在 vouchers，是否可用按当前订单金额实时算，
  // 份数一变就要重算，所以不在这里做筛选。
  loadVouchers() {
    if (!app.globalData.user.logged) return;
    api.myVoucher({ status: '0' }).then((res) => {
      const rows = (res && (res.data || res.rows || res)) || [];
      const vouchers = (Array.isArray(rows) ? rows : []).map((v) => ({
        id: v.id,
        status: v.status,
        faceValue: formatMoney(v.faceValue),
        threshold: formatMoney(v.threshold),
        expireTime: v.expireTime || '',
        expireText: v.expireTime ? String(v.expireTime).slice(0, 10) : '',
        // 券模板的适用门店（0/空=全门店通用）。不带上它，跨店券会被算成可用，
        // 用户选了提交才被后端「该代金券仅限 xx 使用」打回
        storeId: v.storeId,
        storeName: v.storeName || ''
      }));
      this.setData({ vouchers });
      this.refreshUsable();
    }).catch(() => {});
  },

  // 订单金额变化后刷新「N 张可用」，并把已选但不再满足门槛的券自动摘掉，
  // 否则提交时会被后端「未达到代金券使用门槛」拒掉，用户不知道为什么
  refreshUsable(totalArg) {
    const total = parseFloat(totalArg != null ? totalArg : this.data.total) || 0;
    const sid = this._storeId();
    const usable = voucherUtil.usableList(this.data.vouchers, total, undefined, sid);
    this.setData({ voucherCount: usable.length });

    const cur = this.data.voucher;
    if (cur && !voucherUtil.isUsable(cur, total, undefined, sid)) {
      this.setData({ voucher: null, voucherText: '未使用' });
      wx.showToast({ title: '份数变化，已取消所选代金券', icon: 'none' });
    }
    this.recalcPay(total);
  },

  recalcPay(totalArg) {
    const total = parseFloat(totalArg != null ? totalArg : this.data.total) || 0;
    const v = this.data.voucher;
    this.setData({
      discount: formatMoney(voucherUtil.discountOf(v, total)),
      payAmount: voucherUtil.payAmountOf(total, v)
    });
  },

  openVoucher() {
    if (!app.globalData.user.logged) {
      wx.navigateTo({ url: '/pages/login/login' });
      return;
    }
    const total = parseFloat(this.data.total) || 0;
    const sid = this._storeId();
    // 不可用的券也列出来并置灰，让用户知道差多少门槛 / 限哪家店，
    // 而不是列表空着让人以为没券
    const list = this.data.vouchers.map((v) => ({
      ...v,
      usable: voucherUtil.isUsable(v, total, undefined, sid),
      limitText: voucherUtil.storeMatch(v, sid) ? '' : ('仅限' + (v.storeName || '指定门店'))
    }));
    this.setData({ showVoucher: true, voucherList: list });
  },
  closeVoucher() { this.setData({ showVoucher: false }); },
  pickVoucher(e) {
    const id = e.currentTarget.dataset.id;
    const v = this.data.vouchers.find((x) => String(x.id) === String(id));
    if (!v) return;
    const total = parseFloat(this.data.total) || 0;
    const sid = this._storeId();
    if (!voucherUtil.isUsable(v, total, undefined, sid)) {
      const why = voucherUtil.storeMatch(v, sid)
        ? '该券暂不可用'
        : ('该券仅限' + (v.storeName || '指定门店') + '使用');
      wx.showToast({ title: why, icon: 'none' });
      return;
    }
    this.setData({
      voucher: v,
      voucherText: '已选 ¥' + v.faceValue,
      showVoucher: false
    });
    this.recalcPay(total);
  },
  clearVoucher() {
    this.setData({ voucher: null, voucherText: '未使用', showVoucher: false });
    this.recalcPay();
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
      distributorId: app.globalData.shareDistributorId || undefined,
      // 前端算的抵扣只用于展示，后端 placeOrder 会重新校验归属/门槛/封顶，
      // 所以这里只需把选中的券 id 带过去
      memberVoucherId: this.data.voucher ? this.data.voucher.id : undefined
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
