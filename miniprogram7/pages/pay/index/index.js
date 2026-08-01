const app = getApp();
const { api } = require('../../../utils/request.js');
const { formatMoney } = require('../../../utils/util.js');

// 店员确认的轮询间隔与上限：买单需门店确认金额后才能付款
const POLL_INTERVAL = 2000;
const POLL_MAX = 60;

Page({
  data: {
    store: {},
    total: '',
    noDiscount: '',
    realPay: '0.00',
    // 代金券
    vouchers: [],
    voucherList: [],
    voucherCount: 0,
    voucher: null,
    voucherText: '未使用',
    showVoucher: false,
    discount: '0.00',
    // 状态
    billId: null,
    billNo: '',
    status: '',
    waiting: false,
    submitting: false
  },
  onLoad(opts) {
    if (opts.storeId) {
      this.setData({ store: { storeId: opts.storeId } });
      this.loadStore(opts.storeId);
    } else {
      const s = app.globalData.store || (app.globalData.stores && app.globalData.stores[0]);
      if (s && s.storeId) {
        this.applyStore(s);
      } else {
        app.pickNearestStore((st) => this.applyStore(st));
      }
    }
    this.loadVouchers();
  },
  onUnload() {
    this.stopPoll();
  },
  loadStore(storeId) {
    api.storeDetail(storeId).then((res) => {
      const s = (res && (res.data || res)) || null;
      if (s) this.applyStore({ storeId: s.storeId, storeName: s.storeName, address: s.address });
    }).catch(() => {});
  },
  applyStore(s) {
    if (!s) return;
    this.setData({
      store: {
        storeId: s.storeId,
        name: s.storeName || s.name || '',
        address: s.address || ''
      }
    });
  },
  // 我的未使用券，按门槛与「不参与优惠金额」实时筛选
  loadVouchers() {
    if (!app.globalData.user.logged) return;
    api.myVoucher({ status: '0' }).then((res) => {
      const rows = (res && (res.data || res.rows || res)) || [];
      const vouchers = (Array.isArray(rows) ? rows : []).map((v) => ({
        id: v.id,
        faceValue: formatMoney(v.faceValue),
        threshold: formatMoney(v.threshold),
        expireTime: v.expireTime ? String(v.expireTime).slice(0, 10) : ''
      }));
      this.setData({ vouchers });
      this.refreshUsable();
    }).catch(() => {});
  },
  // 参与优惠的金额 = 消费总额 - 不参与优惠金额
  discountBase() {
    const total = parseFloat(this.data.total) || 0;
    const nd = parseFloat(this.data.noDiscount) || 0;
    return Math.max(0, total - nd);
  },
  refreshUsable() {
    const base = this.discountBase();
    const usable = this.data.vouchers.filter((v) => base >= parseFloat(v.threshold));
    this.setData({ voucherCount: usable.length });
    // 已选券因金额变化不再满足门槛时自动取消，避免提交被后端拒绝
    const cur = this.data.voucher;
    if (cur && base < parseFloat(cur.threshold)) {
      this.setData({ voucher: null, voucherText: '未使用' });
      wx.showToast({ title: '金额变化，已取消所选代金券', icon: 'none' });
    }
    this.recalc();
  },
  onTotal(e) {
    this.setData({ total: e.detail.value });
    this.refreshUsable();
  },
  onNoDiscount(e) {
    this.setData({ noDiscount: e.detail.value });
    this.refreshUsable();
  },
  recalc() {
    const total = parseFloat(this.data.total) || 0;
    const v = this.data.voucher;
    let discount = 0;
    if (v) {
      discount = Math.min(parseFloat(v.faceValue) || 0, this.discountBase());
    }
    this.setData({
      discount: formatMoney(discount),
      realPay: formatMoney(Math.max(0, total - discount))
    });
  },
  openVoucher() {
    if (!app.globalData.user.logged) {
      wx.navigateTo({ url: '/pages/login/login' });
      return;
    }
    const base = this.discountBase();
    if (!base) {
      wx.showToast({ title: '请先输入消费总金额', icon: 'none' });
      return;
    }
    const list = this.data.vouchers.map((v) => ({
      ...v,
      usable: base >= parseFloat(v.threshold)
    }));
    this.setData({ showVoucher: true, voucherList: list });
  },
  closeVoucher() { this.setData({ showVoucher: false }); },
  pickVoucher(e) {
    const id = e.currentTarget.dataset.id;
    const v = this.data.vouchers.find((x) => String(x.id) === String(id));
    if (!v) return;
    if (this.discountBase() < parseFloat(v.threshold)) {
      wx.showToast({ title: '未达到使用门槛', icon: 'none' });
      return;
    }
    this.setData({
      voucher: v,
      voucherText: '已选 ¥' + v.faceValue,
      showVoucher: false
    });
    this.recalc();
  },
  clearVoucher() {
    this.setData({ voucher: null, voucherText: '未使用', showVoucher: false });
    this.recalc();
  },
  onPay() {
    if (this.data.submitting || this.data.waiting) return;
    const total = parseFloat(this.data.total) || 0;
    if (!total) return wx.showToast({ title: '请输入消费总金额', icon: 'none' });
    const nd = parseFloat(this.data.noDiscount) || 0;
    if (nd > total) return wx.showToast({ title: '不参与优惠金额不能大于总金额', icon: 'none' });
    if (!this.data.store.storeId) return wx.showToast({ title: '门店信息未加载', icon: 'none' });
    if (!app.globalData.user.logged) {
      wx.navigateTo({ url: '/pages/login/login' });
      return;
    }

    // 已发起过则直接续付，避免重复开单
    if (this.data.billId) {
      this.afterCreated();
      return;
    }

    this.setData({ submitting: true });
    wx.showLoading({ title: '提交中', mask: true });
    api.createBill({
      storeId: this.data.store.storeId,
      amount: total,
      memberVoucherId: this.data.voucher ? this.data.voucher.id : undefined
    }).then((res) => {
      wx.hideLoading();
      const bill = (res && (res.data || res)) || {};
      if (!bill.billId) throw new Error((res && res.msg) || '发起买单失败');
      this.setData({
        billId: bill.billId,
        billNo: bill.billNo,
        status: bill.status,
        discount: formatMoney(bill.discountAmount),
        realPay: formatMoney(bill.payAmount),
        submitting: false
      });
      this.afterCreated();
    }).catch((err) => {
      wx.hideLoading();
      this.setData({ submitting: false });
      wx.showToast({ title: (err && (err.msg || err.message)) || '发起买单失败', icon: 'none' });
    });
  },
  // 买单需店员确认金额，确认后才可付款
  afterCreated() {
    if (this.data.status === '1') {
      this.pay();
      return;
    }
    if (this.data.status === '2') {
      wx.showToast({ title: '该买单已支付', icon: 'none' });
      return;
    }
    this.setData({ waiting: true });
    wx.showModal({
      title: '请门店确认金额',
      content: '买单号 ' + this.data.billNo + '\n请出示给店员确认，确认后将自动进入支付。',
      showCancel: false,
      confirmText: '知道了'
    });
    this.startPoll();
  },
  startPoll() {
    this.stopPoll();
    this.pollCount = 0;
    this.timer = setInterval(() => {
      this.pollCount += 1;
      if (this.pollCount > POLL_MAX) {
        this.stopPoll();
        this.setData({ waiting: false });
        wx.showToast({ title: '等待确认超时，可稍后在门店重试', icon: 'none' });
        return;
      }
      api.billDetail(this.data.billId).then((res) => {
        const b = (res && (res.data || res)) || {};
        if (!b.status) return;
        this.setData({
          status: b.status,
          discount: formatMoney(b.discountAmount),
          realPay: formatMoney(b.payAmount)
        });
        if (b.status === '1') {
          this.stopPoll();
          this.setData({ waiting: false });
          this.pay();
        } else if (b.status === '2') {
          this.stopPoll();
          this.setData({ waiting: false });
          this.onPaid();
        }
      }).catch(() => {});
    }, POLL_INTERVAL);
  },
  stopPoll() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  },
  pay() {
    wx.showLoading({ title: '发起支付', mask: true });
    api.prepayBill(this.data.billId).then((res) => {
      wx.hideLoading();
      if (res && res.mock) {
        this.onPaid();
        return;
      }
      const p = (res && (res.data || res)) || {};
      if (!p.paySign) {
        wx.showToast({ title: '暂不可支付，请稍后重试', icon: 'none' });
        return;
      }
      wx.requestPayment({
        timeStamp: String(p.timeStamp),
        nonceStr: p.nonceStr,
        package: p.package,
        signType: p.signType || 'RSA',
        paySign: p.paySign,
        success: () => this.onPaid(),
        fail: () => wx.showToast({ title: '已取消支付', icon: 'none' })
      });
    }).catch((err) => {
      wx.hideLoading();
      wx.showToast({ title: (err && err.msg) || '支付失败', icon: 'none' });
    });
  },
  onPaid() {
    this.setData({ status: '2' });
    wx.showToast({ title: '支付成功', icon: 'success' });
    setTimeout(() => wx.switchTab({ url: '/pages/mine/index/index' }), 1200);
  }
});
