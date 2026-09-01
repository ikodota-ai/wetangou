const app = getApp();
const { api } = require('../../utils/request.js');
const { formatMoney } = require('../../utils/util.js');
const voucherUtil = require('../../utils/voucher.js');

// 轮询间隔与上限。
// 只在门店关掉了「买单自动确认」时才会用到 —— 默认门店建单即 status=1，
// 顾客在店员面前输入金额后直接进支付，不弹确认提示、不轮询。
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
        status: v.status,
        faceValue: formatMoney(v.faceValue),
        threshold: formatMoney(v.threshold),
        expireTime: v.expireTime || '',
        expireText: v.expireTime ? String(v.expireTime).slice(0, 10) : '',
        // 券模板的适用门店（0/空=全门店通用）。买单一定发生在某家店，
        // 不带上它，别家店的券会被算成可用，提交才被后端打回
        storeId: v.storeId,
        storeName: v.storeName || ''
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
    // 原先只比门槛，漏了过期判断：member_voucher 的 status 靠定时任务刷，
    // 已过期但任务还没跑到的券 status 仍是 '0'，会被当成可用，
    // 用户选了提交才被后端「代金券不可用」打回
    const sid = this.data.store && this.data.store.storeId;
    const usable = voucherUtil.usableList(this.data.vouchers, base, undefined, sid);
    this.setData({ voucherCount: usable.length });
    // 已选券因金额变化不再满足门槛时自动取消，避免提交被后端拒绝
    const cur = this.data.voucher;
    if (cur && !voucherUtil.isUsable(cur, base, undefined, sid)) {
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
      usable: voucherUtil.isUsable(v, base, undefined, this.data.store && this.data.store.storeId),
      limitText: voucherUtil.storeMatch(v, this.data.store && this.data.store.storeId)
        ? '' : ('仅限' + (v.storeName || '指定门店'))
    }));
    this.setData({ showVoucher: true, voucherList: list });
  },
  closeVoucher() { this.setData({ showVoucher: false }); },
  pickVoucher(e) {
    const id = e.currentTarget.dataset.id;
    const v = this.data.vouchers.find((x) => String(x.id) === String(id));
    if (!v) return;
    const sid = this.data.store && this.data.store.storeId;
    if (!voucherUtil.isUsable(v, this.discountBase(), undefined, sid)) {
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
  // status=1 直接进支付（门店开启自动确认时的常态路径）。
  // 只有门店显式关掉自动确认（bill_auto_confirm='0'）后端才会落 status=0，
  // 这时才需要提示顾客出示给店员并开始轮询。
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
    // 跳支付中间页（订单/买单共用）
    if (!this.data.billId) return wx.showToast({ title: '账单ID缺失', icon: 'none' });
    wx.redirectTo({ url: '/pages/order-pay/index?type=bill&id=' + this.data.billId });
  },
  onPaid() {
    this.setData({ status: '2' });
    wx.showToast({ title: '支付成功', icon: 'success' });
    setTimeout(() => wx.switchTab({ url: '/pages/home/index' }), 1200);
  }
});
